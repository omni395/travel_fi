### 🔄 Поток данных (Database-Triggered Architecture)

Stimulus (Браузер: клик/ввод)
    ↓
Stimulus вызывает `this.stimulate("XxxReflex#action", params)` (RPC вызов через WebSocket)
    ↓
Reflex Class (app/reflexes/):
  ├─ Находит current_user через Connection
  ├─ morph :nothing (отмена стандартного морфинга всей страницы)
  ├─ deep_symbolize_keys(params) (строковые ключи из JS → символьные)
  └─ Вызывает Service слой (логики в рефлексе НЕТ)
    ↓
Service Layer (app/services/):
  ├─ Pundit: проверка прав доступа
  └─ Model.save! / update! (внутри транзакции)
    ↓
Database (PostgreSQL + PaperTrail):
  ├─ Данные зафиксированы в БД
  └─ PaperTrail создает запись Version (Single Source of Truth)
    ↓
VersionObserverJob (Background Process - Triggered by PaperTrail):
  ├─ Парсит version.item_type → ветка handle_<model>_update
  └─ Вызывает XxxBroadcaster.call
    ↓
Broadcaster (app/broadcasters/):
  ├─ Рендерит зоны (helpers.render)
  └─ cable_ready["admin_feed"].inner_html(selector:, html:) / cable_ready["pois_map"] / cable_ready["admin_#{id}"] / cable_ready["user_#{id}"] → .broadcast
    ↓
ActionCable (SolidCable): Доставляет команды в адресные стримы
    (UserChannel: user_#{id} личный + pois_map общий карты;
     AdminChannel: admin_#{id} личный + admin_feed общий админки)
    ↓
DOM обновляется (Инициатор — мгновенно/redirect, остальные — через broadcast без перезагрузки)

**Важно**: Модели НЕ содержат логики рассылок. Весь жизненный цикл изменений после сохранения в БД управляется через `VersionObserverJob`.

**Строгие правила слоёв (эталон):**
- Controller: только доступ (Pundit) + рендер страницы + данные вкладок + pagy. Без логики.
- Reflex: мост UI→Service. `morph :nothing` + authorize + делегирование. НЕ рендерить DOM после сохранения.
- Service: вся бизнес-логика. `save!`/`update!` в транзакции.
- Model: только данные. Без логики рассылок.
- Broadcaster: рендер зон + `inner_html` + broadcast. НЕ `morph`, НЕ `update_all`.
- VersionObserverJob: маршрутизация по `item_type` → `XxxBroadcaster.call`.
- ViewComponent: только презентация (sidecar 7 файлов, 4 локали).

**Практические правила (проверено на практике, обязательны):**
- **Reflex**: `morph :nothing` + Service; НЕ рендерить/морфить DOM селекторами в методах, меняющих состояние (обновление — только через Broadcaster).
- **Broadcaster**: только `inner_html` (НЕ `morph` — падает на `undefined.dispatchEvent` из-за `parent.children[idx]`).
- **Селекторы-цели** (`[data-...]`) — на обёртках в шаблоне страницы, а не на корне компонента (иначе вложенность при `inner_html`).
- **Нормализация**: `deep_symbolize_keys(params)` в Reflex перед Service (строковые ключи из JS).
- **Зарезервированные ключи StimulusReflex** (`id` и др.) — только через неймспейс (`field_id`) или `{ params: {...} }`.
- **Аудит**: `update!`/`save!` (версии → Broadcast); `update_all` запрещён для данных с аудитом.
- **Клиент**: применяй CableReady-операции по одной, пропуская отсутствующие селекторы.
- **Рендер вложенных ViewComponent в Broadcaster**: из фонового job — ТОЛЬКО `<%= render %>` / `helpers.render` (view_context). Запрещён вложенный `ApplicationController.render` внутри компонента, рендерящегося из SolidQueue worker — падает, зона не отправляется (симптом: fields/POIs обновляются, audit — нет).
- **Broadcast из worker (bin/jobs)**: инициализируй ActionCable PubSub до `SolidQueue::Cli.start` — `ActionCable.server.config.cable = { "adapter" => "solid_cable" }` (СТРОКОВЫЙ ключ! символьный `:adapter` → дефолт "redis" → `Redis::CannotConnectError`), затем `ActionCable.server.pubsub`.
- **pagy() в Broadcaster**: в SolidQueue worker нет `request` → `NameError: request`, зона с пагинацией не отправляется. Добавь mock: `def request; @request ||= ActionDispatch::Request.new({}); end`.
- **Чекбоксы (Rails check_box)**: генерирует hidden(value=0)+checkbox с одним `name`. В JS выбирай `input[name='...'][type='checkbox']`, иначе всегда читается hidden (false) → в БД не сохраняется true.
- **Таймауты system-тестов — ТОЛЬКО 60с**: Selenium headful при длинных прогонах грузит страницы медленно; меньшие таймауты дают флаки «элемент не появился» (data-admin-users-list, #user-profile, data-admin-user-wallet и т.д.). Дефолт `wait_for_selector` — 60с (spec/support/system_helpers.rb). НЕ снижать и НЕ добавлять мелкие таймауты (30/35/20) в новых тестах.
- **Route helpers в scope "(:locale)"**: маршрут `get ":id"` внутри `scope "(:locale)"` имеет ДВА динамических сегмента — позиционный объект (`user_path(user)`) мапится в `:locale` и падает `UrlGenerationError: missing required keys: [:id]`. Всегда передавай keyword: `user_path(id: user)`, `edit_user_path(id: user)`, `admin_user_path(id: user)`.
- **System-тесты: ОБЯЗАТЕЛЬНЫЙ precompile перед каждым прогоном**: system-тесты берут JS/CSS ассеты из `public/assets` (precompile), а НЕ из `app/assets/builds` (esbuild вне тестов пишет только в builds). После любого изменения фронтенда (ViewComponent JS-контроллер, CSS, шаблон) перед прогоном system-тестов обязательно выполнять `RAILS_ENV=test bin/rails assets:precompile`. Запускать system-тесты ТОЛЬКО через `bundle exec rspec <путь>`. Иначе браузер получает устаревший бандл (старый контроллер/метод) и тест падает «на пустом месте» (например, новый метод `selectStatus` не вызван, hidden не обновлён) — это НЕ баг приложения, а незапущенный precompile.