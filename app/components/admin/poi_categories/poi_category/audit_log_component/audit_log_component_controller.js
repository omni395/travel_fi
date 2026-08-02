import ApplicationController from '../../../../../javascript/controllers/application_controller'

/**
 * Admin::PoiCategories::PoiCategory::AuditLogComponent — контроллер ленты аудита
 *
 * Values:
 *   auditCategoryId — id (slug) категории для пагинации аудита
 *
 * Actions:
 *   goToPage — переключить страницу пагинации аудита через Reflex
 */
export default class extends ApplicationController {
  static values = { auditCategoryId: String }

  /**
   * Переключает страницу пагинации ленты аудита (вкладка Audit Log)
   */
  goToPage(event) {
    const page = event.currentTarget.dataset.page
    if (page && this.auditCategoryIdValue) {
      this.stimulate("Admin::PoiCategoriesReflex#audit_page", { category_id: this.auditCategoryIdValue, audit_page: page })
    }
  }
}
