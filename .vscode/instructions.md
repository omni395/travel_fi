# Travel Fi - Инструкции для агента

## 🎯 Архитектурные принципы (Строгие правила)

### Фронэнд
Используются исключительно веб компоненты. НИКАКИХ партиалов.
Используются исключительно TailwindCSS+Flowbite классы
Для иконок используем иконки MDI в формате svg с обязательным коментрием названия класса иконки.

### 1️⃣ WebSocket-First подход (ВСЕГДА)

**Правило**: Любое взаимодействие браузера с сервером должно идти через WebSocket, НЕ через классические HTTP запросы.

**Когда создаешь новый функционал**:
- ✅ Используй **StimulusReflex** для действий пользователя
- ❌ Не создавай обычные контроллеры с JSON ответами
- ❌ Не отправляй данные в теле ответа HTTP
- ✅ Все обновления DOM идут через **CableReady команды** в WebSocket

**Пример неправильно**:
```ruby
def update
  @item.update(params)
  render json: @item  # ❌ НЕПРАВИЛЬНО - вернул данные в теле
end
```

**Пример правильно**:
```ruby
# app/reflexes/item_reflex.rb
class ItemReflex < ApplicationReflex
  def update_item
    @item = Item.find(params[:id])
    authorize_with_pundit!(@item, :update?)
    ItemUpdateService.call(item: @item, params: params)
    # Model.after_commit сработает → Broadcaster → CableReady
  end
end
```

---

### 2️⃣ DATABASE as Single Source of Truth (ВСЕГДА)

**Правило**: Все данные, включая состояние кэша и аудит, должны быть в PostgreSQL. Нет синхронизации между несколькими источниками.

**Что это означает**:
- ✅ Paper Trail логирует ВСЕ изменения в таблицу версий
- ✅ SolidCache хранит результаты в БД (не в памяти)
- ✅ SolidQueue хранит задачи в БД (не в Redis)
- ✅ После `Model.save` сразу идет `after_commit` хук

**При добавлении нового функционала**:
- Создай Migration для новых таблиц
- Добавь `has_paper_trail` если это таблица с аудитом
- Убедись что `after_commit` корректно вызывает Broadcaster

---

### 3️⃣ Обязательный поток данных (Reflex → Service → Broadcaster)

**Правило**: СТРОГИЙ порядок обработки события:

```
1. Браузер → Stimulus слушает событие
2. Stimulus → вызывает this.stimulusReflex("methodName")
3. Reflex (app/reflexes/):
   - Получает current_user через Connection
   - Вызывает authorize_with_pundit!()  ← ОБЯЗАТЕЛЬНО
   - Делегирует Service Object
4. Service (app/services/):
   - Выполняет бизнес-логику
   - Вызывает Model.save / Model.update / Model.create
5. Model.after_commit:
   - Вызывает соответствующий Broadcaster
6. Broadcaster (app/broadcasters/):
   - Определяет получателей (фильтрация по ролям)
   - Генерирует CableReady команды
   - Создает Noticed уведомления
7. CableReady → ActionCable → WebSocket → браузеры → DOM морфинг
```

**Это означает**:
- ✅ Никогда не пиши логику в Reflex методах (это только入口)
- ✅ Логика ВСЕГДА в Service слое
- ✅ Никогда не отправляй команды CableReady из Reflex
- ✅ Broadcaster определяет ЧТО и КОМУ отправлять

**Пример**:
```ruby
# ❌ НЕПРАВИЛЬНО - логика в Reflex
class TripReflex < ApplicationReflex
  def book_trip
    trip = Trip.find(params[:id])
    trip.status = 'booked'
    trip.save  # Вся логика тут, нет сервиса
  end
end

# ✅ ПРАВИЛЬНО - делегируем Service
class TripReflex < ApplicationReflex
  def book_trip
    trip = Trip.find(params[:id])
    authorize_with_pundit!(trip, :book?)
    TripBookingService.call(trip: trip, user: current_user)
    # Model.after_commit → Broadcaster → CableReady
  end
end

# app/services/trip_booking_service.rb
class TripBookingService
  def self.call(trip:, user:)
    new(trip, user).execute
  end
  
  def execute
    trip.update(status: 'booked', booked_by: current_user)
    # after_commit сработает, вызовет TripBroadcaster
  end
end

# app/broadcasters/trip_broadcaster.rb
class TripBroadcaster
  def self.call(trip)
    new(trip).broadcast
  end
  
  def broadcast
    # Отправляем обновление подписанным пользователям
    cable_ready.morph(
      selector: "[data-trip-id='#{trip.id}']",
      html: TripComponent.new(trip).render_as_inline
    ).broadcast_to(users_watching_trip)
  end
end
```

---

### 4️⃣ Авторизация через Pundit + Rolify (ОБЯЗАТЕЛЬНО в Reflex)

**Правило**: ВСЕ Reflex методы должны вызывать `authorize_with_pundit!(resource, :action?)` перед любыми операциями.

**Что это значит**:
- ✅ Вызови `authorize_with_pundit!` в НАЧАЛЕ каждого Reflex метода
- ❌ Никогда не доверяй `params` - проверь права перед использованием
- ✅ Используй Rolify для управления ролями (`user.add_role :admin`)
- ✅ Используй Pundit polícy файлы для определения прав

**Пример**:
```ruby
# app/reflexes/user_reflex.rb
class UserReflex < ApplicationReflex
  def grant_role
    user = User.find(params[:user_id])
    authorize_with_pundit!(user, :grant_role?)  # ← ПЕРВОЙ строкой!
    UserRoleService.call(user: user, role: params[:role])
  end
end

# app/policies/user_policy.rb
class UserPolicy < ApplicationPolicy
  def grant_role?
    admin? || moderator?
  end
end
```

---

### 5️⃣ Асинхронные операции через SolidQueue (Никогда не блокируй WebSocket)

**Правило**: Долгие операции (отправка Email, платежи, обработка видео) должны быть в SolidQueue Job, НЕ в Reflex или Service синхронно.

**Когда использовать SolidQueue**:
- ✅ Отправка Email (Noticed каналы с delivery_method: :async)
- ✅ Обработка платежей DeFi (долгие API вызовы)
- ✅ Генерирование отчётов (долгие вычисления)
- ❌ Локальные операции в БД (это быстро, делай синхронно)

**Пример**:
```ruby
# app/services/payment_service.rb
class PaymentService
  def execute
    transaction = payment_model.save
    
    # Отправляем долгую операцию в фон
    PaymentProcessingJob.perform_later(transaction.id)
    
    # Браузер СРАЗУ получит обновление через Broadcaster
  end
end

# app/jobs/payment_processing_job.rb
class PaymentProcessingJob < ApplicationJob
  queue_as :default
  
  def perform(transaction_id)
    transaction = Transaction.find(transaction_id)
    # Долгая обработка платежа...
    transaction.update(status: 'completed')
    # Model.after_commit → Broadcaster → браузер узнает о результате
  end
end
```

---

### 6️⃣ Rails Way - структура файлов и соглашения

**Правило**: Строго следуй Rails соглашениям по структуре и именованию.

**Структура файлов**:
```
app/
  reflexes/        ← WebSocket входные точки (класс + метод = действие)
    application_reflex.rb
    item_reflex.rb  ← ItemReflex#update_item
  services/        ← Бизнес-логика (идемпотентные операции)
    item_update_service.rb  ← ItemUpdateService.call()
  broadcasters/    ← Выход данных (определяет ЧТО и КОМУ)
    item_broadcaster.rb     ← ItemBroadcaster.call(item)
  models/          ← Модели с callbacks
    item.rb        ← has_paper_trail; after_commit
  policies/        ← Pundit авторизация
    item_policy.rb ← ItemPolicy#update?
  views/
    components/    ← ViewComponent для фрагментов
      item_component.rb
```

**Соглашения по именованию**:
- ✅ Service классы: `{Model}CreateService`, `{Model}UpdateService`, `{Model}DestroyService`
- ✅ Reflex методы: `verb_noun` (update_item, delete_trip, book_accommodation)
- ✅ Broadcaster методы: обычно один `call` метод, срабатывает из after_commit
- ✅ Миграции: `rails generate migration AddFieldToTable field:type`
- ✅ Моделі: `rails generate model Item name:string trip:references`

**Пример создания нового функционала**:
```bash
# 1. Создай миграцию
rails generate migration CreateTripReviews trip:references user:references rating:integer

# 2. Создай модель с валидациями и callbacks
rails generate model TripReview

# 3. Добавь Service для логики
touch app/services/trip_review_create_service.rb

# 4. Добавь Broadcaster для выхода
touch app/broadcasters/trip_review_broadcaster.rb

# 5. Добавь Reflex для входа
touch app/reflexes/trip_review_reflex.rb

# 6. Добавь Policy для авторизации
touch app/policies/trip_review_policy.rb

# 7. Создай компонент для отображения
rails generate component TripReview
```

---

## 📋 Общие правила

### Комментарии и документация
- Пиши комментарии на **РУССКОМ** языке (как в README)
- Объясняй ЧТО и ПОЧЕМУ, не повторяй КАКОЙ код
- Для сложной логики напиши комментарий перед методом

### Ошибки и исключения
- ✅ Используй `authorize_with_pundit!` (выбросит исключение если нет прав)
- ✅ Используй валидации в моделях (`validates :name, presence: true`)
- ✅ Логируй ошибки через Rails.logger
- ✅ Используй rescue блоки только для ожидаемых исключений

### Code Review
- Если вижу код, который нарушает эти правила → указываю и предлагаю исправление
- Всегда объясняю ПОЧЕМУ нужно следовать паттерну (отсылаюсь к README архитектуре)

---

## 🛡️ Обработка ошибок (Error Handling)

**Правило**: Используй исключения в Service для мгновенной остановки, а `after_commit` в модели гарантирует целостность данных.

**Как работает**:
1. Service выбрасывает исключение если что-то не так
2. Reflex перехватывает исключение (StimulusReflex обрабатывает автоматически)
3. Браузер не морфится (ничего не обновляется)
4. Пользователь видит ошибку через Stimulus error обработчик

**Пример**:
```ruby
# app/services/payment_service.rb
class PaymentService
  def execute
    raise PaymentError, "Insufficient funds" if user.balance < amount
    raise PaymentError, "Invalid payment method" unless payment_method.valid?
    
    # Если все ОК, сохраняем (после save → after_commit → Broadcaster)
    payment.save!
  end
end

# app/reflexes/payment_reflex.rb
class PaymentReflex < ApplicationReflex
  def process
    authorize_with_pundit!(payment, :process?)
    PaymentService.call(payment: payment, user: current_user)
    # Если исключение - Reflex его поймает и отправит браузеру
  end
end
```

**В JavaScript** (обработка ошибки на клиенте):
```javascript
// app/javascript/controllers/payment_controller.js
export default class extends Controller {
  processPayment() {
    this.stimulusReflex('process', this.element)
      .then(() => console.log('OK'))
      .catch(error => {
        // Показать ошибку пользователю
        this.showError(error.message)
      })
  }
}
```

---

## 🔐 Авторизация - отдельные методы на действие

**Правило**: В Policy писать отдельный метод для каждого действия (не параметры).

**Хорошо**:
```ruby
# app/policies/user_policy.rb
class UserPolicy < ApplicationPolicy
  def edit?        # ← отдельный метод
    owner? || admin?
  end
  
  def delete?      # ← отдельный метод
    admin?
  end
  
  def ban?         # ← отдельный метод
    moderator?
  end
end

# В Reflex:
class UserReflex < ApplicationReflex
  def edit_user
    user = User.find(params[:id])
    authorize_with_pundit!(user, :edit?)  # ← ясно, какое действие
    UserUpdateService.call(user: user, params: params)
  end
  
  def ban_user
    user = User.find(params[:id])
    authorize_with_pundit!(user, :ban?)   # ← проверяет отдельный метод
    UserBanService.call(user: user)
  end
end
```

**Плохо**:
```ruby
# ❌ НЕПРАВИЛЬНО - один метод с параметром
def manage?(action)
  case action
  when :edit then owner? || admin?
  when :delete then admin?
  when :ban then moderator?
  end
end

authorize_with_pundit!(user, :manage?, action: :ban)  # ❌ не явно
```

---

### Когда можно отступить от WebSocket-first?
Только по **ПРЯМОМУ запросу пользователя**:
- ✅ Экспорт файлов (CSV, PDF) - используй обычный контроллер с `send_file`
- ✅ Простые API для внешних сервисов - отдельный API контроллер
- ✅ Вебхуки от платежных систем - обычный контроллер с `skip_authentication`

**Но**: Даже в этих случаях сообщи браузерам об обновлении через WebSocket broadcast.

### Структура Reflex метода
```ruby
def action_name
  # 1. Найди ресурс
  @resource = Resource.find(params[:id])
  
  # 2. Проверь права
  authorize_with_pundit!(@resource, :action_name?)
  
  # 3. Делегируй Service
  ResourceService.call(resource: @resource, params: params)
  
  # Model.after_commit сработает → Broadcaster → CableReady
end
```

### Структура Service класса
```ruby
class ResourceService
  def self.call(**args)
    new(**args).execute
  end
  
  def execute
    # Валидация
    # Бизнес-логика
    # Model.save / update / create
    # после commit сработает Broadcaster
  end
end
```

### Структура Model с callback на Broadcaster
```ruby
class Resource < ApplicationRecord
  has_paper_trail  # ← ОБЯЗАТЕЛЬНО для аудита
  
  after_commit :broadcast_updates
  
  private
  
  def broadcast_updates
    ResourceBroadcaster.call(self)
  end
end
```

### Структура Broadcaster класса
```ruby
class ResourceBroadcaster
  def self.call(resource)
    new(resource).broadcast
  end
  
  def broadcast
    # Определи получателей
    recipients = determine_recipients
    
    # Один большой morph для целого компонента (простой и надежный)
    cable_ready.morph(
      selector: "[data-resource-id='#{@resource.id}']",
      html: ResourceComponent.new(@resource).render_as_inline
    ).broadcast_to(recipients)
    
    # Создай Noticed уведомления если нужно
    ResourceNotification.with(resource: @resource).deliver_later(recipients)
  end
  
  private
  
  def initialize(resource)
    @resource = resource
  end
  
  def determine_recipients
    # Фильтрация по ролям, настройкам и т.д.
    # Например: все администраторы и владелец ресурса
    admin_users + [@resource.user]
  end
  
  def admin_users
    User.with_any_role(:admin, :moderator)
  end
end
```

---

## 💡 Примеры промптов для тестирования инструкций

### Пример 1: Правильное использование инструкций
**Промпт**:
```
Добавь функцию "Отметить как избранное" для модели Trip. 
Пользователь кликает на кнопку, статус сохраняется в БД, 
и все администраторы видят обновление в реальном времени.
```

**Ожидаемый результат**:
- ✅ Создана TripReflex#mark_favorite
- ✅ Создана TripMarkFavoriteService с логикой
- ✅ Модель Trip имеет after_commit → TripBroadcaster
- ✅ Broadcaster определяет получателей (админов)
- ✅ Используется морфинг для обновления DOM
- ✅ Есть authorize_with_pundit! в Reflex

### Пример 2: Нарушение инструкций
**Промпт**:
```
Добавь API endpoint для изменения статуса заказа.
```

**Ожидаемый результат** (отклонение):
- ❌ Агент НЕ создаст обычный REST controller
- ✅ Агент спросит: "Это для фронтенда (Reflex) или для внешних систем?"
- ✅ Если для фронтенда - предложит Reflex вариант
- ✅ Если для внешних API - спросит про вебхук обработку

### Пример 3: Асинхронные операции
**Промпт**:
```
Добавь отправку Email уведомления когда пользователь бронирует тур.
```

**Ожидаемый результат**:
- ✅ Email добавлен в Noticed с delivery_method: :async
- ✅ SolidQueue задача в фоне
- ✅ Брузер видит обновление сразу (не ждет Email)
- ✅ Email отправляется параллельно

---

## 🎯 Рекомендуемые расширения инструкций

Для создания более специфичных правил предложу следующие customizations:

1. **Testing strategy** (`instructions-testing.md`)
   - Как писать тесты для Service слоя
   - Как мокировать Broadcaster в тестах
   - Как тестировать авторизацию в Policy

2. **Frontend patterns** (`instructions-stimulus.md`)
   - Как структурировать Stimulus контроллеры
   - Как обрабатывать ошибки от Reflex
   - Как показывать loading и optimistic updates

3. **DeFi integration** (`instructions-defi.md`)
   - Как интегрировать Web3 операции
   - Как обрабатывать транзакции через viem
   - Как гарантировать идемпотентность платежей

4. **Performance & Optimization** (`instructions-performance.md`)
   - Когда использовать SolidCache
   - Как оптимизировать Broadcaster фильтрацию
   - Когда морфить часть, а не весь компонент

5. **Notification system** (`instructions-notifications.md`)
   - Когда создавать Noticed уведомления
   - Как использовать разные каналы (Email, Push, SMS, In-app)
   - Как обрабатывать preferences пользователя

---

## 📝 Версия инструкций

- **v1.0** - Базовые архитектурные правила (2024-04-23)
- Следующие версии: будут обновляться при добавлении новых паттернов

---

- [ ] Весь новый код в Reflex → Service → Broadcaster
- [ ] ВСЕ Reflex методы вызывают `authorize_with_pundit!`
- [ ] Используется Paper Trail для аудита
- [ ] Долгие операции в SolidQueue, не в синхронном коде
- [ ] CableReady команды отправляются из Broadcaster, не из Reflex
- [ ] Тесты покрывают Service логику
- [ ] Комментарии на русском
- [ ] Нет обычных HTTP контроллеров для действий (кроме исключений)
