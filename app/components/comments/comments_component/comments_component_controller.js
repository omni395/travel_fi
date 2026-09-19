import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Comments::CommentsComponent — контроллер обёртки-дерева комментариев.
 *
 * Действия:
 *   sortNew  — переключить сортировку комментариев на «Новые» (PoiReflex#sortComments)
 *   sortBest — переключить сортировку комментариев на «Лучшие» (PoiReflex#sortComments)
 *
 * Атрибуты:
 *   data-commentable-type / data-commentable-id — владелец комментариев
 *   data-sort — текущая сортировка (new/best)
 */
export default class extends ApplicationController {
  static values = {
    sort: String
  }

  /**
   * Переключает сортировку комментариев через Reflex (без перерендера формы).
   * @param {Event} event — событие клика
   */
  sortNew(event) {
    this.setSort(event, 'new')
  }

  /**
   * Переключает сортировку комментариев через Reflex (без перерендера формы).
   * @param {Event} event — событие клика
   */
  sortBest(event) {
    this.setSort(event, 'best')
  }

  /**
   * Общая логика переключения сортировки: вызывает PoiReflex#sortComments.
   * @param {Event} event — событие клика
   * @param {string} sort — 'new' или 'best'
   */
  setSort(event, sort) {
    event.preventDefault()
    this.sortValue = sort
    this.stimulate('PoiReflex#sortComments', {
      comments_sort: sort,
      comments_commentable_type: this.element.dataset.commentableType,
      comments_commentable_id: this.element.dataset.commentableId
    })
  }
}
