# frozen_string_literal: true

#
# Comments::CommentFormComponent — форма создания/редактирования комментария.
#
# Универсальная форма:
#   - режим create (корневой/ответ): parent=nil → корневой, parent!=nil → ответ;
#   - режим edit (переиспользуется только как статическая заглушка — реальное
#     редактирование точечно заменяет текст через PoiReflex#editComment).
#
# Отправляет через Stimulus → PoiReflex (create_comment / update_comment).
# Проксимити (100м) проверяется на сервере (PoiCommentPolicy); инпут без
# autocomplete (Herb) и с неймспейс-ключами (не зарезервированный id).
#
# @param commentable [Poi] владелец комментария
# @param current_user [User, nil] текущий пользователь
# @param parent [PoiComment, nil] родитель (nil = корневой комментарий)
# @param user_lat [Float, nil] широта юзера (session)
# @param user_lng [Float, nil] долгота юзера
#
class Comments::CommentFormComponent < ApplicationComponent
  attr_reader :commentable, :current_user, :parent, :user_lat, :user_lng

  def initialize(commentable:, current_user: nil, parent: nil, user_lat: nil, user_lng: nil, editing: false)
    @commentable = commentable
    @current_user = current_user
    @parent = parent
    @user_lat = user_lat
    @user_lng = user_lng
    @editing = editing
  end

  private

  #
  # Режим редактирования (заглушка: рут едit-формы не используется напрямую).
  #
  # @return [Boolean]
  #
  def editing
    @editing
  end

  #
  # Имя контроллера компонента.
  #
  # @return [String]
  #
  def controller_name
    "comments--comment-form-component"
  end

  #
  # Placeholder формы (отличает корневой от ответа).
  #
  # @return [String]
  #
  def placeholder
    parent ? t(".reply_placeholder") : t(".placeholder")
  end

  #
  # Текст кнопки отправки.
  #
  # @return [String]
  #
  def submit_label
    parent ? (editing ? t(".save") : t(".reply_submit")) : t(".submit")
  end

  #
  # Заголовок кнопки ответа (пометка @предка в форме).
  #
  # @return [String, nil]
  #
  def reply_to_label
    return nil unless parent

    t(".replying_to", name: parent.user&.name || t(".deleted_user"))
  end
end
