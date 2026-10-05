# frozen_string_literal: true

#
# Comments::CommentContentComponent preview — презентация контента комментария
# (шапка/тело/действия) без обёртки и детей (см. CommentComponent).
#
class Comments::CommentContentComponentPreview < Lookbook::Preview
  #
  # Дефолтный сценарий: обычный комментарий активного пользователя.
  #
  def default
    comment = PoiComment.new(
      body: 'A great place to visit at sunset!',
      user: user_stub,
      poi: poi_stub,
      created_at: Time.current,
      updated_at: Time.current
    )
    render Comments::CommentContentComponent.new(comment: comment, current_user: user_stub)
  end

  #
  # Ответ с пометкой @предка (reply_target_name): флоттенед ответ.
  #
  def reply
    root = PoiComment.new(
      id: 1,
      body: 'Root comment',
      user: user_stub,
      poi: poi_stub,
      created_at: Time.current,
      updated_at: Time.current
    )
    reply = PoiComment.new(
      id: 2,
      body: 'Replying to a root from a fallback branch',
      user: user_stub,
      poi: poi_stub,
      parent: root,
      root_id: 1,
      parent_id: 1,
      created_at: Time.current,
      updated_at: Time.current
    )
    render Comments::CommentContentComponent.new(comment: reply, current_user: user_stub)
  end

  private

  #
  # Стаб пользователя для превью (без БД).
  #
  def user_stub
    User.new(name: 'Anna Traveler', status: :active).tap { |u| u.id = 1 }
  end

  #
  # Стаб POI для превью (без БД).
  #
  def poi_stub
    Poi.new.tap { |p| p.id = 1 }
  end
end
