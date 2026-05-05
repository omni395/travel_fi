import { Controller } from '@hotwired/stimulus'

//
// AdminUsersController - контроллер для управления пользователями
//
// Отвечает за:
// - Поиск и фильтрацию пользователей
// - Выбор пользователя для детального просмотра
// - Режим редактирования
// - Обновление полей пользователя
// - Изменение статуса пользователя
// - Добавление/удаление ролей
// - Удаление пользователя
//
export default class extends Controller {
  connect() {
    console.log("AdminUsersController connected");
  }

  disconnect() {
    console.log("AdminUsersController disconnected");
  }

  //
  // Выполняет поиск пользователей через StimulusReflex
  //
  search(event) {
    const query = event.target.value;
    this.stimulate('Admin::UsersReflex#search', { query: query });
  }

  //
  // Фильтрует пользователей по статусу через StimulusReflex
  //
  filterByStatus(event) {
    const status = event.target.value;
    this.stimulate('Admin::UsersReflex#filter_by_status', { status: status });
  }

  //
  // Сбрасывает фильтры через StimulusReflex
  //
  resetFilters() {
    this.stimulate('Admin::UsersReflex#reset_filters');
  }

  //
  // Выбирает пользователя для детального просмотра через StimulusReflex
  //
  selectUser(event) {
    event.preventDefault();
    const userId = event.currentTarget.dataset.userId;
    this.stimulate('Admin::UsersReflex#select_user_detail', { user_id: userId });
  }

  //
  // Запускает режим редактирования через StimulusReflex
  //
  startEdit(event) {
    event.preventDefault();
    const userId = event.currentTarget.dataset.userId;
    this.stimulate('Admin::UsersReflex#start_edit_mode', { user_id: userId });
  }

  //
  // Отменяет режим редактирования через StimulusReflex
  //
  cancelEdit(event) {
    event.preventDefault();
    const userId = document.getElementById('user-detail').dataset.userId;
    this.stimulate('Admin::UsersReflex#select_user_detail', { user_id: userId });
  }

  //
  // Обновляет поле пользователя через StimulusReflex
  //
  updateField(event) {
    const field = event.currentTarget.dataset.field;
    const value = event.currentTarget.value;
    const userDetail = document.getElementById('user-detail');
    const userId = userDetail.dataset.userId;

    this.stimulate('Admin::UsersReflex#update_field',
      { user_id: userId, field: field, value: value });
  }

  //
  // Изменяет статус пользователя через StimulusReflex
  //
  updateStatus(event) {
    event.preventDefault();
    const status = event.currentTarget.dataset.status;
    const userDetail = document.getElementById('user-detail');
    const userId = userDetail.dataset.userId;

    this.stimulate('Admin::UsersReflex#update_status',
      { user_id: userId, status: status });
  }

  //
  // Добавляет роль пользователю через StimulusReflex
  //
  addRole(event) {
    event.preventDefault();
    const roleId = event.currentTarget.dataset.roleId;
    const userDetail = document.getElementById('user-detail');
    const userId = userDetail.dataset.userId;

    this.stimulate('Admin::UsersReflex#add_role',
      { user_id: userId, role_id: roleId });
  }

  //
  // Удаляет роль у пользователя через StimulusReflex
  //
  removeRole(event) {
    event.preventDefault();
    const roleId = event.currentTarget.dataset.roleId;
    const userDetail = document.getElementById('user-detail');
    const userId = userDetail.dataset.userId;

    this.stimulate('Admin::UsersReflex#remove_role',
      { user_id: userId, role_id: roleId });
  }

  //
  // Удаляет пользователя через StimulusReflex
  //
  destroyUser(event) {
    event.preventDefault();
    if (!confirm(I18n.t('admin.users.confirm_destroy'))) {
      return;
    }

    const userDetail = document.getElementById('user-detail');
    const userId = userDetail.dataset.userId;

    this.stimulate('Admin::UsersReflex#destroy',
      { user_id: userId });
  }

  //
  // Сохраняет изменения пользователя через StimulusReflex
  //
  save(event) {
    event.preventDefault();
    // Изменения сохраняются автоматически при изменении полей
    const userId = document.getElementById('user-detail').dataset.userId;
    this.stimulate('Admin::UsersReflex#select_user_detail', { user_id: userId });
  }
}
