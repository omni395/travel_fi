# frozen_string_literal: true

require 'rails_helper'

#
# Poi::FormComponent — единичный (unit) спек рендера формы POI.
#
# Покрытие бага 2:
#   1. В edit-режиме выбранная категория отображается в дропдауне
#      (НЕ placeholder «Выберите категорию»).
#   2. В edit-режиме динамические поля выбранной категории (PoiCategoryField)
#      рендерятся сразу в #poi-form-fields (без доп. рефлекса load_category_fields).
#
RSpec.describe Poi::FormComponent, type: :helper do
  let!(:user) { create(:user) }
  let!(:category) { create(:poi_category) }
  let!(:field) { create(:poi_category_field, poi_category: category, field_type: 'string') }

  # Рендер компонента вне браузера — как в broadcaster-контексте
  def render_form(poi)
    ApplicationController.render(
      described_class.new(poi: poi, current_user: user, categories: [category]),
      layout: false
    )
  end

  it 'edit-режим: категория отображается в дропдауне, а не placeholder (баг 2)' do
    poi = create(:poi, user: user, poi_category: category,
                coordinates: PoiService.parse_coordinates(51.5079, -0.0877), status: 'approved')

    html = render_form(poi)

    # Внутри span categoryName — имя выбранной категории
    expect(html).to include(CGI.escapeHTML(category.localized_name))
  end

  it 'edit-режим: динамические поля категории рендерятся сразу (баг 2)' do
    poi = create(:poi, user: user, poi_category: category,
                coordinates: PoiService.parse_coordinates(51.5079, -0.0877), status: 'approved')

    html = render_form(poi)

    # Поле отрендерено внутри #poi-form-fields
    expect(html).to include("poi[metadata][#{field.field_key}]")
  end

  it 'create-режим (poi=nil): динамические поля категории НЕ рендерятся (баг 2 участок)' do
    html = render_form(nil)

    expect(html).not_to include("poi[metadata][#{field.field_key}]")
  end
end
