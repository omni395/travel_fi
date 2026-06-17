import ApplicationController from '../../../../javascript/controllers/application_controller'

//
// Admin::Users::TableComponent — контроллер таблицы пользователей
// Иконка: mdi-table-account
//
// Отвечает за:
//   - Поиск и фильтрацию пользователей (AND — query + status одновременно)
//   - Сортировку пользователей
//   - Навигацию по страницам
//   - Переход в профиль пользователя
//
export default class extends ApplicationController {
  static targets = ["rows"];

  connect() {
    super.connect();
  }

  //
  // Фильтрует пользователей по запросу и/или статусу (AND)
  // Отправляет оба поля при любом изменении
  //
  filter(event) {
    const query = document.getElementById('search-input')?.value || '';
    const status = document.getElementById('status-select')?.value || '';
    this.stimulate('Admin::UsersReflex#filter', { query: query, status: status });
  }

  //
  // Сбрасывает фильтры через StimulusReflex
  //
  resetFilters() {
    this.stimulate('Admin::UsersReflex#reset_filters');
  }

  //
  // Сортирует пользователей по указанной колонке
  // Переключает направление сортировки при повторном клике
  //
  sort(event) {
    const column = event.currentTarget.dataset.sortColumn;
    const query = document.getElementById('search-input')?.value || '';
    const status = document.getElementById('status-select')?.value || '';
    this.stimulate('Admin::UsersReflex#sort', { column: column, query: query, status: status });
  }

  //
  // Переходит на указанную страницу пагинации
  // Вызывается при клике на кнопки пагинации
  //
  goToPage(event) {
    event.preventDefault();
    const page = event.currentTarget.dataset.page;
    const query = document.getElementById('search-input')?.value || '';
    const status = document.getElementById('status-select')?.value || '';
    this.stimulate('Admin::UsersReflex#filter', { query: query, status: status, page: page });
  }

  //
  // Колбэк после рефлекса — очищает поля формы при сбросе фильтров
  //
  afterReflex(element, reflex, noop, reflexId) {
    if (reflex === 'Admin::UsersReflex#reset_filters') {
      const searchInput = document.getElementById('search-input');
      const statusSelect = document.getElementById('status-select');
      if (searchInput) searchInput.value = '';
      if (statusSelect) statusSelect.value = '';
    }
  }

  //
  // Переходит на страницу профиля пользователя при клике на строку таблицы
  //
  /**
   * Переходит на страницу профиля пользователя при клике на строку таблицы
   */
  visitProfile(event) {
    const row = event.currentTarget;
    const userId = row.dataset.adminUserId;
    window.location.href = `/admin-panel/users/${userId}`;
  }

  /**
   * Удаляет пользователя через StimulusReflex
   * Вызывается из ShowComponent (кнопка Delete)
   */
  destroyUser(event) {
    const userId = event.currentTarget.dataset.userId;
    if (!userId) return;
    this.stimulate('Admin::UsersReflex#destroy', { user_id: userId });
  }
}
