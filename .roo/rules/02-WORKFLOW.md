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