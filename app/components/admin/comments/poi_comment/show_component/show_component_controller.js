import ApplicationController from '../../../../javascript/controllers/application_controller'

/**
 * Admin::Comments::PoiComment::ShowComponent — контроллер детальной страницы
 * комментария в админке.
 *
 * Действия:
 *   hide    — скрыть комментарий (Admin::CommentsReflex#hide)
 *   unhide  — показать (Admin::CommentsReflex#unhide)
 *   destroy — удалить (Admin::CommentsReflex#destroy)
 */
export default class extends ApplicationController {
  /**
   * Скрыть комментарий.
   * @param {Event} event — событие клика
   */
  hide(event) {
    event.preventDefault()
    this.stimulate('Admin::CommentsReflex#hide', { comment_id: this.element.dataset.commentId })
  }

  /**
   * Показать ранее скрытый комментарий.
   * @param {Event} event — событие клика
   */
  unhide(event) {
    event.preventDefault()
    this.stimulate('Admin::CommentsReflex#unhide', { comment_id: this.element.dataset.commentId })
  }

  /**
   * Удалить комментарий.
   * @param {Event} event — событие клика
   */
  destroy(event) {
    event.preventDefault()
    this.stimulate('Admin::CommentsReflex#destroy', { comment_id: this.element.dataset.commentId })
  }
}
