import ApplicationController from '../../../../javascript/controllers/application_controller'

/**
 * Admin::PoiCategories::TableComponent — контроллер таблицы категорий POI
 * Отвечает за навигацию по страницам, переход к деталям
 */
export default class extends ApplicationController {
  /**
   * Переход на страницу деталей категории при клике на строку
   */
  visitCategory(event) {
    const row = event.currentTarget;
    const categoryId = row.dataset.adminPoiCategoryId;
    window.location.href = `/admin-panel/poi_categories/${categoryId}`;
  }

  /**
   * Переход на указанную страницу пагинации
   */
  goToPage(event) {
    event.preventDefault();
    const page = event.currentTarget.dataset.page;
    this.stimulate('Admin::PoiCategoriesReflex#filter', { page: page });
  }
}
