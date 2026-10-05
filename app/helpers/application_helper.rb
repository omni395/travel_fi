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
  # Возвращает inline critical CSS в <head>.
  #
  # Стили спиннера обязаны быть здесь: application.css грузится асинхронно,
  # и без инлайна оверлей до его прихода не имеет позиционирования, а логотип
  # вываливается в натуральный размер. Критичные правила гарантируют: оверлей
  # сразу перекрывает весь экран непрозрачным фоном, логотип не расползается.
  #
  # В будущем — Rake-таск с headless Chrome/Puppeteer для генерации
  # above-the-fold CSS по страницам. Пока — статические критичные правила.
  #
  # @return [ActiveSupport::SafeBuffer] inline <style> тег
  #
  def critical_css
    css = <<~CSS
      [data-controller="ui--spinner-component"] {
        position: fixed;
        inset: 0;
        z-index: 9999;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        gap: 24px;
        background: #ffffff;
      }
      [data-controller="ui--spinner-component"] .spinner-box {
        position: relative;
        width: 96px;
        height: 96px;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      [data-controller="ui--spinner-component"] .spinner-logo {
        z-index: 10;
        width: 80px;
        height: 80px;
        border-radius: 9999px;
        overflow: hidden;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 8px;
        background: #ffffff;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
      }
      [data-controller="ui--spinner-component"] .spinner-logo img {
        width: 100%;
        height: 100%;
        object-fit: contain;
        display: block;
      }
    CSS
    content_tag(:style, css)
  end
end
