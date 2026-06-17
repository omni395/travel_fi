// AdminChannel - клиентская подписка на канал административной панели
// Получает обновления статистики, списка пользователей и активностей
import consumer from './consumer'

const adminChannel = consumer.subscriptions.create('AdminChannel', {
  connected() {
    console.log('[AdminChannel] Connected')
  },

  disconnected() {
    console.log('[AdminChannel] Disconnected')
  },

  rejected() {
    console.log('[AdminChannel] Rejected - user is not an admin')
  },

  received(data) {
    console.log('[AdminChannel] Received:', data)
  }
})

export default adminChannel
