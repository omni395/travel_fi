# frozen_string_literal: true

#
# Ui::TooltipComponent - универсальный тултип для карты
#
# Используется как Overlay в OpenLayers для отображения краткой информации
# о точке при наведении. Содержимое заполняется через JavaScript
# (feature.get("poiName")) без серверного запроса.
#
# Контроллер: не требуется (управляется через DOM-элемент из map_component_controller.js)
#
class Ui::TooltipComponent < ApplicationComponent
end
