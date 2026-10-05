import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Comments::CommentComponent — контроллер записи комментария.
 *
 * Действия:
 *   toggleReply    — раскрыть/скрыть форму ответа
 *   toggleEdit     — раскрыть/скрыть форму редактирования
 *   openDeleteDialog     — открыть диалог подтверждения удаления (staff)
 *   onDeleteConfirmed   — подтверждено удаление: скрыть комментарий + открыть диалог пенализации
 *   onSuspendConfirmed  — подтверждена пенализация: удалить + suspend автора (PoiReflex#destroy_comment suspend:true)
 *   expandReplies — развернуть свёрнутую ветку (PoiReflex#expandReplies)
 *
 * Атрибуты:
 *   data-comment-id        — id комментария
 *   data-comment-author-id — id автора комментария
 *   data-comment-replyable — "true" если можно отвечать (корневой комментарий)
 *
 * Принцип (общий): общий стрим (pois_map) раздаёт контент ОДНИМ нодом без
 * персональных кнопок; персональные элементы (кнопки автора/admin/mod) рисует
 * клиент по данным сущности (author-id) и текущему пользователю (<body>).
 * Личный стрим user_<id> — ТОЛЬКО уведомления/награды, НЕ контент.
 */
export default class extends ApplicationController {
  static targets = ['replyForm', 'editForm', 'replies', 'replyButton', 'authorActions', 'staffActions', 'deleteDialog', 'suspendDialog']

  /**
   * Раскрывает персональные кнопки по правам текущего пользователя.
   * Вызывается при connect() — и для SSR-нод, и для live-нод из общего стрима.
   */
  /**
   * При монтировании ноды (в т.ч. повторного inner_html из бродкаста) —
   * раскрывает персональные кнопки по правам текущего пользователя
   * (authorActions / staffActions / replyButton) и подписывается на событие
   * poi:comment-updated — для повторного сканирования прав после live-правки.
   */
  connect() {
    super.connect()
    this.refreshPermissions()
    this.element.addEventListener('poi:comment-updated', this.refreshPermissions)
  }

  /**
   * Отписка от события при удалении ноды — предотвращает утечку слушателя.
   */
  disconnect() {
    this.element.removeEventListener('poi:comment-updated', this.refreshPermissions)
    super.disconnect()
  }

  /**
   * Раскрывает персональные кнопки по правам текущего пользователя.
   * Вынесено из connect(), чтобы вызывать повторно после inner_html правки
   * (бродкастер шлёт poi:comment-updated) — иначе заново вставленные кнопки
   * остаются скрытыми. Контекст this — стрелочная функция-метод класса.
   */
  refreshPermissions = () => {
    const currentUserId = document.body.dataset.currentUserId
    const role = document.body.dataset.userRole || ''
    const authorId = this.element.dataset.commentAuthorId
    const isStaff = role === 'admin' || role === 'moderator'
    const isAuthor = currentUserId && authorId && currentUserId === authorId

    // Изменить — автору или staff.
    if ((isAuthor || isStaff) && this.hasAuthorActionsTarget) {
      this.authorActionsTarget.classList.remove('hidden')
    }

    // Удалить/пенализация — только staff (admin/moderator).
    if (isStaff && this.hasStaffActionsTarget) {
      this.staffActionsTarget.classList.remove('hidden')
    }

    // Ответить — залогиненному пользователю (кроме автора; либо staff),
    // только для корневого комментария (data-comment-replyable="true").
    // Не показываем, если пользователь уже ответил на этот комментарий
    // (data-comment-i-replied="true") — анти-флуд (UI-подсказка; бэкенд-рубеж
    // в CommentService + валидации PoiComment).
    const replyable = this.element.dataset.commentReplyable === 'true'
    const iReplied = this.element.dataset.commentIReplied === 'true'
    if (currentUserId && replyable && !iReplied && (!isAuthor || isStaff) && this.hasReplyButtonTarget) {
      this.replyButtonTarget.classList.remove('hidden')
    }
  }

  /**
   * Переключает видимость формы ответа.
   */
  toggleReply() {
    if (this.hasReplyFormTarget) {
      this.replyFormTarget.classList.toggle('hidden')
    }
  }

  /**
   * Переключает видимость формы редактирования (hidden toggle).
   */
  toggleEdit() {
    if (this.hasEditFormTarget) {
      this.editFormTarget.classList.toggle('hidden')
    }
  }

  /**
   * Открывает диалог подтверждения удаления (Ui::ConfirmDialogComponent).
   * Вызывается кликом на кнопку «Удалить» (staff) — без confirm_url диалог
   * работает в режиме подтверждения перед кастомным Reflex-действием.
   */
  openDeleteDialog(event) {
    event.preventDefault()
    this._openDialog('deleteDialog')
  }

  /**
   * Обрабатывает подтверждение из диалога удаления: скрывает комментарий
   * (hide, ветка сохраняется) через PoiReflex#destroy_comment и открывает
   * второй диалог — автопенализация автора (suspend на 3 дня).
   */
  onDeleteConfirmed() {
    this.stimulate('PoiReflex#destroy_comment', {
      comment_id: this.element.dataset.commentId,
      suspend: false
    })
    this._openDialog('suspendDialog')
  }

  /**
   * Обрабатывает подтверждение из диалога пенализации: скрывает комментарий
   * и переводит автора в :suspended на 3 дня (авто-разблокировка джобом).
   */
  onSuspendConfirmed() {
    this.stimulate('PoiReflex#destroy_comment', {
      comment_id: this.element.dataset.commentId,
      suspend: true
    })
  }

  /**
   * Показывает Ui::ConfirmDialogComponent по имени target.
   * @param {string} targetName — имя target ('deleteDialog' | 'suspendDialog')
   */
  _openDialog(targetName) {
    const scope = this[`${targetName}Target`]
    if (!scope) return
    const dialog = scope.querySelector("[data-controller='ui--confirm-dialog-component']")
    if (dialog) {
      dialog.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
    }
  }

  /**
   * Разворачивает свёрнутую ветку через Reflex (догружает детей).
   */
  expandReplies() {
    this.stimulate('PoiReflex#expand_replies', {
      comment_id: this.element.dataset.commentId
    })
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
