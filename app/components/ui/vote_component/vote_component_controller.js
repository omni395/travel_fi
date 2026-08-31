import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Ui::VoteComponent Controller
 * Иконка: mdi-thumb-up-outline (апрув) / mdi-thumb-down-outline (дизлайк)
 *
 * Управляет голосованием сообщества (Community Moderation) по схеме:
 *   - первый клик на кнопку    → create (новый голос +1/-1)
 *   - повторный клик на ту же  → ConfirmDialog «забрать голос?» → destroy
 *   - клик на противоположную  → ConfirmDialog «изменить голос?» → change
 *
 * Live-обновление счётчика/бейджа — через VoteBroadcaster
 * (inner_html [data-vote-zone=...]), поэтому здесь НЕ перерисовываем вручную.
 *
 * Проксимити/авторство уже проверены на бэке (VotePolicy + check_proximity!).
 */
export default class extends ApplicationController {
  static targets = ["removeDialog", "changeDialog"]

  /**
   * Голосует «Апрув» (+1).
   * @param {Event} event - событие click на кнопке апрува
   */
  castUp(event) {
    this._handleVote(1)
  }

  /**
   * Голосует «Дизлайк» (-1).
   * @param {Event} event - событие click на кнопке дизлайка
   */
  castDown(event) {
    this._handleVote(-1)
  }

  /**
   * Подтверждение «забрать голос» — удаляет голос (destroy).
   * @param {Event} event - событие confirmDialogConfirmed
   */
  onRemoveConfirmed(event) {
    this._cast("destroy", this._currentVoteValue)
  }

  /**
   * Подтверждение «изменить голос» — удаляет старый + создаёт новый (change).
   * @param {Event} event - событие confirmDialogConfirmed
   */
  onChangeConfirmed(event) {
    this._cast("change", this._pendingValue)
  }

  /**
   * Разрешает действие по текущему голосу юзера:
   *   - нет голоса          → create
   *   - клик на ту же кнопку → показать removeDialog
   *   - клик на противоположную → показать changeDialog
   *
   * @param {Number} desiredValue - +1 (апрув) / -1 (дизлайк)
   */
  _handleVote(desiredValue) {
    const current = this._currentVoteValue

    if (current === 0) {
      this._cast("create", desiredValue)
      return
    }

    if (current === desiredValue) {
      this._openDialog("removeDialog")
      return
    }

    // Противоположный голос: запоминаем желаемое значение и спрашиваем смену.
    this._pendingValue = desiredValue
    this._openDialog("changeDialog")
  }

  /**
   * Отправляет действие через StimulusReflex (RPC over WebSocket).
   * Значения votable_type/votable_id берутся из data-атрибутов контроллера.
   *
   * @param {String} voteAction - "create" | "destroy" | "change"
   * @param {Number} voteValue - +1 / -1
   */
  _cast(voteAction, voteValue) {
    const votableType = this.element.getAttribute("data-vote-component-votable-type-value")
    const votableId = this.element.getAttribute("data-vote-component-votable-id-value")

    if (!votableType || !votableId || !voteValue) return

    this.stimulate("VoteReflex#cast", {
      votable_type: votableType,
      votable_id: Number(votableId),
      vote_value: Number(voteValue),
      vote_action: voteAction
    })

    // Локальное (оптимистичное) обновление персонального состояния.
    // Счётчики уже обновит VoteBroadcaster (общий стрим), но активное состояние
    // и выбранный голос (data-current-vote) — персональные — broadcast не трогает
    // (только числа). Инициатор видит смену на лету.
    this._applyLocalState(voteAction, voteValue)
  }

  /**
   * Переключает персональное состояние голосования после отправки действия:
   *   - create:  выбранный голос = voteValue
   *   - destroy: выбранный голос = нет
   *   - change:  выбранный голос = voteValue
   * Обновляет data-current-vote (корень) и классы is-active на кнопках.
   *
   * @param {String} voteAction - "create" | "destroy" | "change"
   * @param {Number} voteValue - +1 / -1
   */
  _applyLocalState(voteAction, voteValue) {
    let nextVote = 0
    if (voteAction === "create" || voteAction === "change") {
      nextVote = voteValue
    }

    this.element.setAttribute("data-vote-component-current-vote-value", String(nextVote))

    const upBtn = this.element.querySelector('[data-action="ui--vote-component#castUp"]')
    const downBtn = this.element.querySelector('[data-action="ui--vote-component#castDown"]')
    if (upBtn) upBtn.classList.toggle("is-active", nextVote === 1)
    if (downBtn) downBtn.classList.toggle("is-active--down", nextVote === -1)
  }

  /**
   * Текущий голос юзера за сущность (1 / -1 / 0). Читается с data-атрибута корня.
   *
   * @return {Number}
   */
  get _currentVoteValue() {
    const raw = this.element.getAttribute("data-vote-component-current-vote-value")
    const value = Number(raw)
    return [1, -1].includes(value) ? value : 0
  }

  /**
   * Открывает диалог подтверждения (снимает hidden с ConfirmDialog).
   * ConfirmDialog без confirm_url работает в режиме подтверждения перед
   * кастомным действием — после клика «Да» он диспатчит confirmDialogConfirmed.
   *
   * @param {String} targetName - имя Stimulus-target ("removeDialog" | "changeDialog")
   */
  _openDialog(targetName) {
    const wrapper = this[`${targetName}Target`]
    if (!wrapper) return

    const dialog = wrapper.querySelector("[data-controller='ui--confirm-dialog-component']")
    if (!dialog) return

    dialog.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }
}
