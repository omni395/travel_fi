### 🔄 Поток данных (Database-Triggered Architecture)

Stimulus (Браузер: клик/ввод)
    ↓
Stimulus вызывает `this.stimulusReflex("methodName")`
    ↓
WebSocket отправляет Reflex действие (RPC вызов)
    ↓
Reflex Class (app/reflexes/):
  ├─ Находит current_user через Connection
  ├─ morph :nothing (отмена стандартного морфинга всей страницы)
  └─ Вызывает Service слой
    ↓
Service Layer (app/services/):
  ├─ Pundit: проверка прав доступа
  └─ Model.save (внутри транзакции)
    ↓
Database (PostgreSQL + PaperTrail):
  ├─ Данные зафиксированы в БД
  └─ PaperTrail создает запись Version (Single Source of Truth)
    ↓
VersionObserverJob (Background Process - Triggered by PaperTrail):
  ├─ Извлекает изменения из version.object_changes
  ├─ Фильтрация получателей (Роль, Контекст, Настройки)
  └─ Вызывает Broadcaster
    ↓
Broadcaster (app/broadcasters/):
  ├─ CableReady: Генерирует точечные команды для прошедших фильтр юзеров
  └─ Noticed: Отправляет внешние уведомления (Email/Push)
    ↓
ActionCable: Доставляет команды в индивидуальные каналы User:ID:Stream
    ↓
DOM обновляется (Инициатор — мгновенно, остальные — согласно правам и контексту)

**Важно**: Модели НЕ содержат логики рассылок. Весь жизненный цикл изменений после сохранения в БД управляется через `VersionObserverJob`.

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