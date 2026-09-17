# frozen_string_literal: true

return unless Rails.env.development?

# Конфигурацию ViewComponent безопаснее менять напрямую через config
Rails.application.config.view_component.preview_paths ||= []
Rails.application.config.view_component.preview_paths << Rails.root.join("lookbook")

# НАСТРОЙКА ПУТЕЙ ДЛЯ ГЕМА LOOKBOOK:
# Говорим движку Lookbook искать файлы превью и кастомных страниц в корневой папке
Rails.application.config.lookbook.preview_paths = [ Rails.root.join("lookbook") ]
Rails.application.config.lookbook.page_paths = [ Rails.root.join("lookbook") ]

Rails.application.reloader.to_prepare do
  # 2. Пути для шаблонов ActionView
  ActiveSupport.on_load(:action_controller_base) do
    append_view_path Rails.root.join("lookbook")
  end

  # 3. Мок Pundit policy для ActionView
  ActiveSupport.on_load(:action_view) do
    include Module.new {
      def policy(*_args)
        Class.new {
          def method_missing(*_args); true; end
          def respond_to_missing?(*_args); true; end
        }.new
      end
    }
  end
end
