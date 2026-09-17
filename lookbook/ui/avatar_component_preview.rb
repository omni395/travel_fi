# lookbook/ui/avatar_component_preview.rb
# frozen_string_literal: true

# @logical_path ui
# @component Ui::AvatarComponent
class Ui::AvatarComponentPreview < Lookbook::Preview
  # @param size select [sm, md, lg, xl] "Размер"
  # @param name text "Имя пользователя"
  # @param has_avatar toggle "Загружен аватар"
  def default(size: "md", name: "Алексей Смирнов", has_avatar: true)
    user = MockUser.new(
      name: name,
      avatar_url: has_avatar ? "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150" : nil
    )

    render Ui::AvatarComponent.new(user: user, size: size.to_sym)
  end

  def all_sizes
    render_with_template
  end

  def with_initials
    user = MockUser.new(name: "Дмитрий Иванов", avatar_url: nil)
    render Ui::AvatarComponent.new(user: user, size: :lg)
  end

  private

  class MockUser
    attr_reader :id, :name, :mock_avatar_url

    def initialize(id: 1, name: "Пользователь", avatar_url: nil)
      @id = id
      @name = name
      @mock_avatar_url = avatar_url
    end

    def avatar
      MockAttachment.new(mock_avatar_url)
    end
  end

  class MockAttachment
    attr_reader :url

    def initialize(url)
      @url = url
    end

    def attached?
      url.present?
    end
  end
end
