module ApplicationHelper
  #
  # Рендерит пагинацию Pagy (v43+) с использованием NumericHelpers#series_nav
  # Расширяет объект Pagy модулем NumericHelpers и вызывает series_nav
  #
  # @param pagy [Pagy] объект пагинации
  # @param kwargs [Hash] дополнительные опции для series_nav
  # @return [String] HTML пагинации
  #
  def pagy_series_nav(pagy, **kwargs)
    pagy.extend(Pagy::NumericHelpers)
    pagy.series_nav(**kwargs)
  end

  #
  # Возвращает inline critical CSS для текущей страницы
  # Кэшируется в SolidCache для каждого controller#action
  #
  # Для заполнения кэша нужен Rake-таск с headless Chrome/Puppeteer,
  # который генерирует above-the-fold CSS для каждой страницы.
  # Пока — заглушка, возвращает пустой тег <style>.
  #
  # @return [ActiveSupport::SafeBuffer] inline <style> тег
  #
  def critical_css
    key = "critical_css/#{controller_name}/#{action_name}"
    css = Rails.cache.fetch(key, expires_in: 1.day) do
      "" # TODO: добавить генерацию через Puppeteer/Playwright
    end
    content_tag(:style, css.html_safe) if css.present?
  end
end
