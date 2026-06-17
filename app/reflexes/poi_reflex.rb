# frozen_string_literal: true

#
# PoiReflex - Reflex для взаимодействия с POI через WebSocket
#
# Ответственность:
# 1. Показ детальной информации о POI в сайдбаре
# 2. Сохранение геолокации пользователя в сессии
# 3. Загрузка POI по границам карты (только видимые)
# 4. Показ детальной информации о POI в модалке
# 5. Уведомления об ошибках геолокации
#
# NOTE: НЕ включает CableReady::Broadcaster — StimulusReflex 3.5+ сам предоставляет cable_ready.
# См. https://docs.stimulusreflex.com/guide/cableready
#
class PoiReflex < ApplicationReflex
  #
  # Показывает детальную информацию о POI в сайдбаре
  # Вызывается при клике на маркер карты или элемент списка
  #
  # @param poi_id [Integer] ID POI
  #
  def show_detail(poi_id)
    poi = Poi.includes(:poi_category, :user).find(poi_id)
    authorize_with_pundit!(poi, :show?)

    cable_ready.morph(
      selector: "#poi-detail",
      html: ApplicationController.render(Poi::DetailComponent.new(poi: poi))
    )
    cable_ready.set_attribute(selector: "#poi-list", name: "class", value: "hidden")
    cable_ready.remove_attribute(selector: "#poi-detail-wrapper", name: "class")
    morph :nothing

    Rails.logger.info("PoiReflex: Showed detail for POI #{poi.id} (#{poi.localized_name})")
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("PoiReflex: POI not found - #{e.message}")
  rescue Pundit::NotAuthorizedError
    Rails.logger.warn("PoiReflex: Not authorized to view POI #{poi_id}")
  end

  #
  # Показывает детальную информацию о POI в модалке
  # Вызывается при клике на маркер карты (через poi:show-detail событие)
  #
  # Использует Poi::DetailComponent как контейнер (оверлей + центрированная карточка)
  #
  # @param poi_id [Integer] ID POI
  #
  def show_detail_modal(poi_id)
    # Гости — показываем ConfirmDialog с предложением войти
    unless current_user
      login_url = Rails.application.routes.url_helpers.new_user_session_path(return_to: request.original_url)
      dialog = ApplicationController.render(Ui::ConfirmDialogComponent.new(
        title: I18n.t("pois.auth_required_title"),
        message: I18n.t("pois.auth_required_message"),
        confirm_text: I18n.t("ui.confirm_dialog_component.confirm"),
        cancel_text: I18n.t("ui.confirm_dialog_component.cancel"),
        confirm_variant: :primary,
        confirm_url: login_url,
        confirm_method: :get
      ), layout: false)
      # Вставляем диалог и показываем (убираем hidden с контейнера и с самого компонента)
      cable_ready.inner_html(selector: "#poi-auth-dialog", html: dialog)
      cable_ready.remove_css_class(selector: "#poi-auth-dialog", name: "hidden")
      cable_ready.remove_css_class(
        selector: "#poi-auth-dialog [data-controller='ui--confirm-dialog-component']",
        name: "hidden"
      )
      cable_ready.broadcast
      morph :nothing
      return
    end

    poi = Poi.includes(:poi_category, :user).find(poi_id)
    authorize_with_pundit!(poi, :show?)

    html = ApplicationController.render(Poi::DetailComponent.new(poi: poi, current_user: current_user))

    cable_ready.inner_html(selector: "#poi-detail-modal-body", html: html)
    cable_ready.add_css_class(selector: "#poi-form-content", name: "hidden")
    cable_ready.remove_css_class(selector: "#poi-detail-modal-content", name: "hidden")
    cable_ready.remove_css_class(selector: "[data-poi--detail-component-target='overlay']", name: "hidden")
    cable_ready.broadcast
    morph :nothing

    Rails.logger.info("PoiReflex: Showed detail modal for POI #{poi.id} (#{poi.localized_name})")
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("PoiReflex: POI not found for modal - #{e.message}")
  rescue Pundit::NotAuthorizedError
    Rails.logger.warn("PoiReflex: Not authorized to view POI #{poi_id} in modal")
  end

  #
  # Сохраняет координаты пользователя в сессии
  # Вызывается из pois_controller.js после успешной геолокации
  #
  # @param params [Hash] { lat: Float, lng: Float }
  #
  def set_location(params = {})
    session[:user_lat] = params[:lat].to_f
    session[:user_lng] = params[:lng].to_f

    morph :nothing

    Rails.logger.info("PoiReflex: User location set to #{session[:user_lat]}, #{session[:user_lng]}")
  end

  PER_PAGE = 25

  #
  # Загружает первую страницу POI в пределах видимых границ карты
  # Вызывается из pois_controller.js при каждом moveend
  #
  # Рендерит список элементов + секцию "Load more" (если есть ещё POI)
  #
  # @param params [Hash] { sw_lat:, sw_lng:, ne_lat:, ne_lng: }
  #
  def load_pois_in_bounds(params = {})
    # NOTE: Не используем prevent_refresh! — эта операция вызывается до authorisation check
    # и вызывает undefined method ошибку в данной версии StimulusReflex.
    # Вместо этого: cable_ready.morph + inner_html + broadcast, morph :nothing в конце.

    scope = Poi.approved.within_bounds(
      params[:sw_lat], params[:sw_lng],
      params[:ne_lat], params[:ne_lng]
    )
    total = scope.count
    pois = scope.includes(:poi_category).recent.limit(PER_PAGE)

    # 1. Список для сайдбара
    list_html = ApplicationController.render(
      Poi::ListItemComponent.with_collection(pois), layout: false
    )
    more_html = render_load_more(total, PER_PAGE, params)
    cable_ready.inner_html(
      selector: "#poi-list",
      html: list_html + more_html.html_safe
    )

    # 2. Данные для маркеров карты (скрытый контейнер #poi-map-features)
    #    Рендерит элементы с data-poi-id/data-poi-lat/data-poi-lng
    #    + расширенные данные для тултипа при ховере
    #    Карта читает их через _loadPois() независимо от сайдбара
    features_html = pois.map { |poi|
      lat = poi.latitude
      lng = poi.longitude
      name = poi.localized_name.to_s.gsub('"', '"').gsub("'", "'")
      icon = poi.poi_category&.icon || "mdi-map-marker"
      category = poi.poi_category&.localized_name.to_s.gsub('"', '"')
      address = [ poi.address, poi.city ].compact.join(", ").gsub('"', '"')
      rating = poi.rating&.to_f || 0
      %(<div data-poi-id="#{poi.id}"
             data-poi-lat="#{lat}"
             data-poi-lng="#{lng}"
             data-poi-name="#{name}"
             data-poi-icon="#{icon}"
             data-poi-category="#{category}"
             data-poi-rating="#{rating}"
             data-poi-address="#{address}"></div>)
    }.join("\n")
    cable_ready.inner_html(selector: "#poi-map-features", html: features_html)

    cable_ready.broadcast
    morph :nothing

    Rails.logger.info("PoiReflex: Loaded #{pois.length}/#{total} POIs in bounds (first page)")
  end

  #
  # Загружает следующую страницу POI (offset-based) и добавляет в конец списка
  # Вызывается из sidebar_component_controller.js при клике "Load more"
  #
  # @param params [Hash] { sw_lat:, sw_lng:, ne_lat:, ne_lng:, offset: Integer }
  #
  def load_more_pois(params = {})
    scope = Poi.approved.within_bounds(
      params[:sw_lat], params[:sw_lng],
      params[:ne_lat], params[:ne_lng]
    )
    total = scope.count
    offset = params[:offset].to_i
    pois = scope.includes(:poi_category).recent.offset(offset).limit(PER_PAGE)

    return unless pois.any?

    cable_ready.insert_adjacent_html(
      selector: "#poi-list",
      position: "beforeend",
      html: ApplicationController.render(
        Poi::ListItemComponent.with_collection(pois), layout: false
      )
    )

    # Обновляем/удаляем секцию load-more
    more_html = render_load_more(total, offset + pois.length, params)
    cable_ready.inner_html(
      selector: "#poi-load-more",
      html: more_html.html_safe
    )
    cable_ready.broadcast
    morph :nothing

    Rails.logger.info("PoiReflex: Loaded #{pois.length} more POIs (offset #{offset}/#{total})")
  end

  #
  # Рендерит секцию "Load more" для списка POI
  # Если все POI загружены — возвращает пустой div (скрывает кнопку)
  #
  # @param total [Integer] общее количество POI в bounds
  # @param loaded [Integer] сколько уже загружено
  # @param params [Hash] границы карты { sw_lat:, sw_lng:, ne_lat:, ne_lng: }
  # @return [String] HTML секции
  #
  def render_load_more(total, loaded, params)
    remaining = total - loaded
    return "<div id=\"poi-load-more\"></div>" if remaining <= 0

    sw_lat = params[:sw_lat]
    sw_lng = params[:sw_lng]
    ne_lat = params[:ne_lat]
    ne_lng = params[:ne_lng]

    <<~HTML
      <div id="poi-load-more" class="px-4 py-3 border-t border-gray-100">
        <button type="button"
                data-action="click->ui--sidebar-component#loadMore"
                data-sw-lat="#{sw_lat}" data-sw-lng="#{sw_lng}"
                data-ne-lat="#{ne_lat}" data-ne-lng="#{ne_lng}"
                data-offset="#{loaded}"
                class="w-full px-3 py-2 text-sm font-medium text-emerald-600 bg-emerald-50
                       rounded-md hover:bg-emerald-100 transition-colors">
          <i class="mdi mdi-chevron-double-down mr-1"></i>
          #{I18n.t("pois.load_more", count: remaining)}
        </button>
      </div>
    HTML
  end

  #
  # Показывает тост об ошибке геолокации через ToastBroadcaster
  # Только для залогиненных пользователей (у них есть ActionCable канал).
  # Для гостей тост приходит через flash.now в PoisController#index.
  #
  # Вызывается из pois_controller.js при ошибке GPS (onError)
  # Отправляет через UserChannel, доступен всем окнам пользователя.
  # morph :nothing — отмена полного перерендера страницы, только тост.
  #
  def show_geolocation_toast
    morph :nothing
    return unless current_user

    ToastBroadcaster.call(
      user_id: current_user.id,
      message: I18n.t("pois.no_location_toast"),
      type: :warning,
      auto_dismiss: 8000
    )
  end

  #
  # Открывает форму редактирования POI с проверкой расстояния
  # Вызывается из detail_component_controller.js (кнопка Edit)
  #
  # Если пользователь вне 50м от точки — показывает ConfirmDialog с предупреждением
  # Для админов/модераторов проверка пропускается
  #
  # @param poi_id [Integer] ID POI
  #
  def edit_poi(poi_id)
    poi = Poi.includes(:poi_category, :user).find(poi_id)
    authorize_with_pundit!(poi, :update?)

    # Проверка расстояния (антифрод/спам)
    return unless check_proximity!(poi)

    # Рендерим форму редактирования
    html = ApplicationController.render(Poi::DetailComponent.new(
      poi: poi,
      current_user: current_user,
      categories: PoiCategory.active.by_position,
      user_lat: session[:user_lat],
      user_lng: session[:user_lng]
    ))

    cable_ready.inner_html(selector: "#poi-detail-modal-body", html: html)
    cable_ready.add_css_class(selector: "#poi-detail-modal-content", name: "hidden")
    cable_ready.remove_css_class(selector: "#poi-form-content", name: "hidden")
    cable_ready.remove_css_class(selector: "[data-poi--detail-component-target='overlay']", name: "hidden")
    cable_ready.broadcast
    morph :nothing

    Rails.logger.info("PoiReflex: Edit form for POI #{poi.id} (#{poi.localized_name})")
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("PoiReflex: POI not found for edit - #{e.message}")
  rescue Pundit::NotAuthorizedError
    Rails.logger.warn("PoiReflex: Not authorized to edit POI #{poi_id}")
  end
end
