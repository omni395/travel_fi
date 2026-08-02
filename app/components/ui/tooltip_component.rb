# frozen_string_literal: true

#
# Ui::TooltipComponent - тултип-попап (мини-карточка) при наведении на маркер карты
#
# Используется как Overlay в OpenLayers для отображения краткой информации о точке.
# Двухколоночная мини-карточка: фото слева на всю высоту + текст справа построчно
# (категория / название / рейтинг / адрес).
# Содержимое заполняется через JavaScript из feature properties (map_component_controller.js)
# без серверного запроса. Фото берётся из data-poi-photo (PhotoService.cover_photo_url),
# fallback — no-image.png.
#
# Контроллер: не требуется (управляется через DOM-элемент из map_component_controller.js)
#
class Ui::TooltipComponent < ApplicationComponent
end
