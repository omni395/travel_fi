import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Comments::CommentComponent — контроллер записи комментария.
 *
 * Действия:
 *   toggleReply   — раскрыть/скрыть форму ответа
 *   toggleEdit    — раскрыть/скрыть форму редактирования
 *   destroy       — удалить комментарий (автор/admin) через PoiReflex#destroyComment
 *   expandReplies — развернуть свёрнутую ветку (PoiReflex#expandReplies)
 *
 * Атрибуты:
 *   data-comment-id — id комментария
 */
export default class extends ApplicationController {
  static targets = ['replyForm', 'editForm', 'replies']

  /**
   * Переключает видимость формы ответа.
   */
  toggleReply() {
    this.toggleTarget('replyForm')
  }

  /**
   * Переключает видимость формы редактирования.
   */
  toggleEdit() {
    this.toggleTarget('editForm')
  }

  /**
   * Удаляет комментарий через Reflex. Всегда запрашивает подтверждение.
   */
  destroy() {
    if (!window.confirm(this.i18n('confirm_delete'))) return

    this.stimulate('PoiReflex#destroyComment', {
      comment_id: this.element.dataset.commentId
    })
  }

  /**
   * Разворачивает свёрнутую ветку через Reflex (догружает детей).
   */
  expandReplies() {
    this.stimulate('PoiReflex#expandReplies', {
      comment_id: this.element.dataset.commentId
    })
  }

  /**
   * Переключает target-элемент (hidden).
   * @param {string} name — имя target
   */
  toggleTarget(name) {
    const target = this.hasTarget(name) ? this.targets.find(name) : null
    if (target) target.classList.toggle('hidden')
  }

  /**
   * Локализованный текст из значка подтверждения (sidecar YAML этого компонента).
   * @param {string} key — ключ перевода
   * @returns {string}
   */
  i18n(key) {
    return window.I18n ? window.I18n.t(`comments.comment_component.${key}`) : key
  }
}
