import ApplicationController from '../../../../javascript/controllers/application_controller'

// Admin::Pois::TableComponent — контроллер таблицы POI
// Отвечает за навигацию по страницам, переход к деталям
export default class extends ApplicationController {
  //
  // Переход на страницу деталей POI при клике на строку
  //
  visitPoi(event) {
    const row = event.currentTarget;
    const poiId = row.dataset.adminPoiId;
    window.location.href = `/admin-panel/pois/${poiId}`;
  }

  //
  // Переход на указанную страницу пагинации
  // Вызывается из Ui::PaginationComponent
  //
  goToPage(event) {
    event.preventDefault();
    const page = event.currentTarget.dataset.page;
    this.stimulate('Admin::PoisReflex#filter', { page: page });
  }
}
