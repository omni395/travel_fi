import ApplicationController from '../../../../javascript/controllers/application_controller'

/**
 * Admin::Comments::TableComponent — контроллер таблицы модерации комментариев.
 *
 * Несёт только контейнерные обязанности (обновление строк через
 * Admin::CommentsReflex RowComponent и бродкастер). Интеракция скрытия/показа
 * реализована в RowComponent/компоненте PoiComment::Show.
 */
export default class extends ApplicationController {}
