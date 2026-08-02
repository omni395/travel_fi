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
  #
  # Для генерации нужен Rake-таск с headless Chrome/Puppeteer,
  # который генерирует above-the-fold CSS для каждой страницы.
  # Пока — заглушка, возвращает пустой тег <style>.
  #
  # @return [ActiveSupport::SafeBuffer, nil] inline <style> тег или nil
  #
  def critical_css
    css = "" # TODO: добавить генерацию через Puppeteer/Playwright
    content_tag(:style, css.html_safe) if css.present?
  end
end
