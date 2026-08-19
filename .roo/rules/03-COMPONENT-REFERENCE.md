# Travel Fi — Полный справочник архитектуры компонентов

## 1. Структура ViewComponent (Sidecar)

### Файловая структура

Для компонента `Admin::Users::User::EditComponent`:

```
app/components/admin/users/user/
├── edit_component.rb                              # Ruby-класс
└── edit_component/                                 # Sidecar папка
    ├── edit_component.html.erb                     # Шаблон
    ├── edit_component_controller.js                # Stimulus-контроллер
    ├── edit_component.css                          # Стили (опционально)
    ├── edit_component.en.yml                       # Локализация
    ├── edit_component.ru.yml                       # Локализация
    ├── edit_component.es.yml                       # Локализация
    └── edit_component.zh.yml                       # Локализация
```

**Ключевые правила:**
- Имя файла Ruby = snake_case имени класса: `UserCardComponent` → `user_card_component.rb`
- Имя sidecar папки = snake_case без `_component`: `user_card_component/`
- Имена файлов внутри = полное snake_case: `user_card_component.html.erb`
- Никогда не использовать `module`-обёртки в названии класса
- Наследовать от `ApplicationComponent`, не от `ViewComponent::Base`
- Запрещены partials. Только ViewComponents.
- **СТРОГО: Каждый компонент ОБЯЗАН иметь полный sidecar** — Ruby-класс, шаблон, JS-контроллер, CSS, YAML (4 локали). Даже если JS/CSS пустые — файлы должны существовать. Partial sidecar запрещён.

### Ruby-класс

```ruby
# frozen_string_literal: true

#
# Admin::Users::User::EditComponent — описание компонента
#
# @param user [User] описание параметра
#
class Admin::Users::User::EditComponent < ApplicationComponent
  def initialize(user:)
    @user = user
  end

  private

  attr_reader :user
end
```

### Шаблон

```erb
<%# Admin::Users::User::EditComponent — краткое описание %>
<%# Иконка: mdi-pencil (обязательно MDI-комментарий) %>
<%= render Ui::CardComponent.new do |card| %>
  <% card.with_body do %>
    <div data-controller="admin--users--user--edit-component">
      ...
    </div>
  <% end %>
<% end %>
```

**Правила:**
- Корневой элемент обёртки всегда с `data-controller="kebab-case-name"`
- Использовать `Ui::CardComponent` для карточек
- Использовать `Ui::BtnComponent` для кнопок
- Использовать `Ui::DropdownComponent` для дропдаунов (не `<select>`)
- Использовать `Ui::TabsComponent` для табов

### Stimulus-контроллер

```js
import ApplicationController from '../../../../../javascript/controllers/application_controller'

/**
 * Admin::Users::User::EditComponent — описание
 *
 * Действия:
 *   handleSubmit — отправляет форму через StimulusReflex
 */
export default class extends ApplicationController {
  static targets = ["targetName"]

  handleSubmit(event) {
    event.preventDefault()
    // ...
    this.stimulate("Admin::UsersReflex#update", params) // НЕ stimulusReflex!
  }
}
```

**Критически важно:**
- Всегда наследовать от `ApplicationController`, который делает `StimulusReflex.register(this)`
- Использовать `this.stimulate()`, НЕ `this.stimulusReflex()` (старое API)
- Если контроллер не использует Reflex — наследовать от `Controller` из `@hotwired/stimulus`

---

## 2. Регистрация контроллера

### Автоматическая генерация

Скрипт `scripts/discover_components.js` генерирует:

1. `app/javascript/controllers/_generated/_index.js` — обычная загрузка
2. `app/javascript/controllers/_components_lazy.js` — ленивая загрузка (code-split)

### Сгенерированный stub

```js
// app/javascript/controllers/_generated/admin_poi_categories_poi_category_edit_component_edit_component_controller.js
import Controller from '../../../components/admin/poi_categories/poi_category/edit_component/edit_component_controller.js'
import { application } from '../application'
application.register('admin--poi-categories--poi-category--edit-component', Controller)
```

### Регистрация в _index.js

```js
import './admin_poi_categories_poi_category_edit_component_edit_component_controller.js'
```

### data-controller имя

Формат: `snake-case-путь-от-app-components`. Примеры:
- `app/components/ui/btn_component.rb` → `ui--btn-component`
- `app/components/admin/users/user/edit_component.rb` → `admin--users--user--edit-component`

---

## 3. Database-Triggered Workflow (строгая цепочка)

```
Stimulus (браузер: клик/ввод)
    ↓  this.stimulate("Reflex#method", params)
Reflex Class (app/reflexes/)
    ├── morph :nothing (отмена полного перерендера)
    └── Service Layer
        ↓
Service Layer (app/services/)
    ├── Pundit: authorize
    └── Model.save (внутри транзакции)
        ↓
PaperTrail → VersionObserverJob → Broadcaster → CableReady → ActionCable
```

**Правила:**
- Логика ТОЛЬКО в Service layer. Никакой логики в моделях или контроллерах.
- Reflex всегда вызывает `morph :nothing` (или `morph "#selector"`), никогда `prevent_refresh!`
- Service использует `Model.save!` внутри транзакции
- `ApplicationReflex` включает `Rails.application.routes.url_helpers` — route helpers доступны в любом Reflex
- Для `cable_ready.redirect_to(url: ...)` всегда использовать именованные маршруты (`admin_poi_path(id: poi)`)
- **Канальная модель (2 канала, адресные стримы):** `UserChannel` → `user_#{id}` (личный) + `pois_map` (общий карты); `AdminChannel` → `admin_#{id}` (личный) + `admin_feed` (общий админки). Бродкастеры адресуют по имени стрима. Noticed (`stream: :user_stream` → `user_#{id}`) продолжает работать.

---

## 4. UI-компоненты (обязательные к использованию)

| Компонент | Назначение | Вместо |
|-----------|-----------|--------|
| `Ui::CardComponent` | Карточки с header/body/footer | div.bg-white.shadow |
| `Ui::BtnComponent` | Все кнопки | button/button_tag |
| `Ui::DropdownComponent` | Выпадающие меню | select/option |
| `Ui::TabsComponent` | Вкладки | manual tab JS |
| `Ui::BadgeComponent` | Бейджи/статусы | span.badge |
| `Ui::AvatarComponent` | Аватары | img |
| `Ui::TooltipComponent` | Подсказки (карта) | title attr |
| `Ui::BreadcrumbsComponent` | Хлебные крошки | manual breadcrumbs |
| `Ui::PaginationComponent` | Пагинация | will_paginate |
| `Ui::ConfirmDialogComponent` | Диалоги подтверждения | confirm() |
| `Ui::ToastComponent` | Уведомления | flash messages |

---

## 5. Стиль и цвета

- **Палитра:** только зелено-голубые оттенки Tailwind CSS
  - `emerald-500`, `emerald-600` — основные (кнопки, иконки)
  - `teal-600`, `teal-700` — навбар, акценты
  - `sky-600` — градиенты
- **Иконки:** Только MDI (Material Design Icons) с комментарием класса
- **Кастомные стили запрещены** — только TailwindCSS классы
- **Комментарий к иконке:** `<%# Иконка: mdi-pencil %>`

---

## 6. Локализация (I18n)

- 4 локали: `en`, `ru`, `es`, `zh`
- Тексты в sidecar YAML компонента (относительные ключи: `t(".key")`)
- **Запрещено** добавлять ключи в `config/locales/*.yml` для текстов внутри компонента

Структура YAML:
```yaml
en:
  admin:
    users:
      user:
        edit_component:
          title: "Edit User"
          save: "Save"
```

---

## 7. Основные ошибки (запомнить!)

| ❌ Неправильно | ✅ Правильно |
|---------------|-------------|
| `this.stimulusReflex("Reflex#method")` | `this.stimulate("Reflex#method")` |
| `<select>` для выбора | `Ui::DropdownComponent` |
| Button без `Ui::BtnComponent` | `render Ui::BtnComponent.new` |
| `div.bg-white.shadow.rounded-lg` | `Ui::CardComponent` |
| `module UI; class X; end; end` | `class Ui::X < ApplicationComponent` |
| `ViewComponent::Base` | `ApplicationComponent` |
| `prevent_refresh!` | `morph :nothing` |
| partials | ViewComponents |
| `button_tag`, `link_to` без btn-ui | `Ui::BtnComponent` |
| Логика в модели | Service слой |
