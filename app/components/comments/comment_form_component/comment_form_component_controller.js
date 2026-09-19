import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Comments::CommentFormComponent — контроллер формы комментария.
 *
 * Действия:
 *   submit — отправляет создание/ответ комментария через PoiReflex#createComment
 *
 * Атрибуты:
 *   data-commentable-type / data-commentable-id — владелец
 *   data-parent-id (опц.) — родитель (не пустой = ответ)
 */
export default class extends ApplicationController {
  static targets = ['body']

  /**
   * Отправляет форму через StimulusReflex. Неймспейс-ключи — чтобы не
   * конфликтовать с зарезервированным ключом id (догма StimulusReflex).
   * @param {Event} event — событие отправки
   */
  submit(event) {
    event.preventDefault()
    const body = this.bodyTarget.value.trim()
    if (!body) return

    const params = {
      comment_body: body,
      comment_commentable_id: this.element.dataset.commentableId,
      comment_parent_id: this.element.dataset.parentId
    }

    this.stimulate('PoiReflex#createComment', params).then(() => {
      this.bodyTarget.value = ''
    })
  }
}
