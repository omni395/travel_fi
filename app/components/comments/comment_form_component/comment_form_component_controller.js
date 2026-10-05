import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Comments::CommentFormComponent — контроллер формы комментария.
 *
 * Действия:
 *   submit — создание/ответ (create_comment) или редактирование (update_comment)
 *
 * Атрибуты:
 *   data-commentable-type / data-commentable-id — владелец
 *   data-parent-id (опц.) — родитель (не пустой = ответ)
 *   data-comment-id (опц.) — редактируемый комментарий (не пустой = edit-режим)
 */
export default class extends ApplicationController {
  static targets = ['body']

  /**
   * Отправляет форму через StimulusReflex. Неймспейс-ключи — чтобы не
   * конфликтовать с зарезервированным ключом id (догма StimulusReflex).
   * В edit-режиме (data-comment-id) вызывает update_comment с comment_id.
   * @param {Event} event — событие отправки
   */
  submit(event) {
    event.preventDefault()
    const body = this.bodyTarget.value.trim()
    if (!body) return

    const commentId = this.element.dataset.commentId
    if (commentId) {
      this.stimulate('PoiReflex#update_comment', {
        comment_id: commentId,
        comment_body: body
      }).then(() => {
        // Очищаем поле только при успешном ответе (записи не откатываются).
        this.bodyTarget.value = ''
      }).catch(() => {
        // При сбое (morph :nothing + тост) оставляем ввод для исправления.
      })
      return
    }

    // Координаты юзера с карты (data-user-lat/lng на .poi-map) передаём ЯВНО
    // параметром: session не персистится между WebSocket-рефлексами (StimulusReflex
    // + SolidCable, окно изолировано), поэтому полагаться на server-side session
    // в create_comment нельзя — следующий рефлекс читал бы пустую сессию и
    // check_proximity! блокировал бы обычного юзера с «нет геолокации».
    const mapEl = document.querySelector('.poi-map[data-user-lat]')
    const params = {
      comment_body: body,
      comment_commentable_id: this.element.dataset.commentableId,
      comment_parent_id: this.element.dataset.parentId
    }
    if (mapEl) {
      params.comment_lat = parseFloat(mapEl.dataset.userLat)
      params.comment_lng = parseFloat(mapEl.dataset.userLng)
    }

    this.stimulate('PoiReflex#create_comment', params).then(() => {
      // Очищаем поле только при успешном ответе.
      this.bodyTarget.value = ''
    }).catch(() => {
      // При сбое (morph :nothing + тост) оставляем ввод для исправления.
    })
  }
}
