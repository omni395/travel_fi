// AdminChannel - клиентская подписка на канал административной панели
// Получает обновления статистики, списка пользователей и активностей
import consumer from './consumer'
import CableReady from 'cable_ready'

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

    // Применяем CableReady-операции (морфинг, тосты и т.д.) от серверных бродкастеров
    // ПО ОДНОЙ: сбой или отсутствие селектора одной операции не должен обрывать
    // применение остальных операций пака.
    if (data && data.cableReady && Array.isArray(data.operations)) {
      data.operations.forEach(op => {
        try {
          // Пропускаем морфы на отсутствующие в текущем DOM селекторы
          if (op.selector && !document.querySelector(op.selector)) {
            console.warn('[AdminChannel] skip morph (selector not found):', op.selector)
            return
          }
          CableReady.perform([op])
        } catch (e) {
          console.error('[AdminChannel] CableReady operation failed:', op, e)
        }
      })
    }
  }
})

export default adminChannel
