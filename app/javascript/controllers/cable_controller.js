import { Controller } from '@hotwired/stimulus'
import consumer from '../channels/consumer'
import CableReady from 'cable_ready'

// Глобальный объект для отслеживания активных подписок
const activeSubscriptions = new Map()

export default class extends Controller {
  connect() {
    console.log('[CABLE_CONTROLLER] connect() called for UserChannel')

    // Проверяем, есть ли уже подписка
    if (!activeSubscriptions.has('UserChannel')) {
      console.log('[CABLE_CONTROLLER] ✅ No subscription found, creating new one for UserChannel')
      this.createSubscription()
    } else {
      console.log('[CABLE_CONTROLLER] ⚠️  Subscription for UserChannel already exists, skipping')
    }
  }

  disconnect() {
    // Не удаляем подписку при отключении контроллера
    // Подписка должна жить пока страница открыта
    console.log('[CABLE_CONTROLLER] disconnect() called - keeping subscription active')
  }

  createSubscription() {
    const consumerInstance = consumer

    console.log('[CABLE_CONTROLLER] 📤 Creating subscription for UserChannel')

    const subscription = consumerInstance.subscriptions.create({ channel: 'UserChannel' }, {
      connected() {
        console.log('[CABLE_SUBSCRIPTION] ✅ UserChannel: Connected')
      },

      disconnected() {
        console.log('[CABLE_SUBSCRIPTION] ❌ UserChannel: Disconnected')
        activeSubscriptions.delete('UserChannel')
      },

      received(data) {
        console.log('[CABLE_SUBSCRIPTION] 📨 UserChannel: Received', data)

        // Применяем CableReady-операции (тосты, морфинг и т.д.)
        if (data && data.cableReady) {
          CableReady.perform(data.operations)
        }
      },

      rejected() {
        console.log('[CABLE_SUBSCRIPTION] 🚫 UserChannel: Rejected by server')
        activeSubscriptions.delete('UserChannel')
      }
    })

    activeSubscriptions.set('UserChannel', subscription)
    console.log('[CABLE_CONTROLLER] ✅ Subscription created and stored in Map for UserChannel')
  }
}
