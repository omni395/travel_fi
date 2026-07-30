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
      login_url = new_user_session_path(return_to: request.original_url)
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

    comments = PoiComment.where(poi_id: poi.id).includes(:user).recent
    html = ApplicationController.render(Poi::DetailComponent.new(
      poi: poi,
      current_user: current_user,
      comments: comments,
      user_lat: session[:user_lat],
      user_lng: session[:user_lng]
    ))

    cable_ready.inner_html(selector: "#poi-detail-modal-body", html: html)
    cable_ready.add_css_class(selector: "#poi-form-content", name: "hidden")
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
    Current.user_lat = session[:user_lat]
    Current.user_lng = session[:user_lng]

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

    # Фильтры приходят из клиента (map_component_controller читает из DOM)
    category_ids = Array(params[:category_ids]).map(&:to_i).select(&:positive?)
    query = params[:query].to_s.strip.presence
    Rails.logger.info("[POI REFLEX] load_pois_in_bounds — params: category_ids=#{category_ids.inspect}, query=#{query.inspect}")

    scope = Poi.approved.within_bounds(
      params[:sw_lat], params[:sw_lng],
      params[:ne_lat], params[:ne_lng]
    )

    if category_ids.present?
      scope = scope.where(poi_category_id: category_ids)
    end

    if query.present?
      q = "%#{Poi.sanitize_sql_like(query)}%"
      scope = scope.where(
        "EXISTS (SELECT 1 FROM jsonb_each_text(pois.name) WHERE value ILIKE :q) OR EXISTS (SELECT 1 FROM jsonb_each_text(pois.description) WHERE value ILIKE :q)",
        q: q
      )
    end

    # Все POI в bounds — для маркеров карты (без лимита, OL кластеризация)
    pois_map = scope.includes(:poi_category)
                   .order(nearest_first_sql)
                   .to_a
    total = pois_map.size

    # Первая страница для списка сайдбара (с пагинацией PER_PAGE=25)
    pois_list = pois_map.first(PER_PAGE)

    # 1. Список для сайдбара
    list_html = ApplicationController.render(
      Poi::ListItemComponent.with_collection(pois_list), layout: false
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
    #    ВСЕ точки в bounds — кластеризация на клиенте
    features_html = pois_map.map { |poi|
      lat = poi.latitude
      lng = poi.longitude
      name = poi.localized_name.to_s.gsub('"', '"').gsub("'", "'")
      icon = poi.poi_category&.icon || "mdi-map-marker"
      category = poi.poi_category&.localized_name.to_s.gsub('"', '"')
      category_id = poi.poi_category_id
      address = [ poi.address, poi.city ].compact.join(", ").gsub('"', '"')
      rating = poi.rating&.to_f || 0
      %(<div data-poi-id="#{poi.id}"
             data-poi-lat="#{lat}"
             data-poi-lng="#{lng}"
             data-poi-name="#{name}"
             data-poi-icon="#{icon}"
             data-poi-category="#{category}"
             data-poi-category-id="#{category_id}"
             data-poi-rating="#{rating}"
             data-poi-address="#{address}"
             data-poi-user-id="#{poi.user_id}"></div>)
    }.join("\n")
    cable_ready.inner_html(selector: "#poi-map-features", html: features_html)

    cable_ready.broadcast
    morph :nothing

    Rails.logger.info("PoiReflex: Loaded #{pois_map.length}/#{total} POIs in bounds (all for map, #{pois_list.length} in sidebar)")
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
    pois = scope.includes(:poi_category)
               .order(nearest_first_sql)
               .offset(offset)
               .limit(PER_PAGE)

    return unless pois.any?

    # Вставляем новые POI ПЕРЕД контейнером кнопки "Load more"
    # (кнопка остаётся внизу списка)
    cable_ready.insert_adjacent_html(
      selector: "#poi-load-more",
      position: "beforebegin",
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
  # Фильтрует POI по категориям через Ransack + границы карты
  # Вызывается из poi--filters-component при изменении чекбокса категории
  #
  # @param params [Hash] { category_ids: Array<Integer> }
  #   category_ids: пустой массив = показать все категории (сброс)
  #
  # Когда вызывается, bounds берутся из текущей сессии/состояния карты
  # (карта не двигалась, поэтому bounds актуальны из предыдущего load_pois_in_bounds).
  #
  def filter_by_categories(params = {})
    category_ids = Array(params[:category_ids]).map(&:to_i).select(&:positive?)

    # bounds передаются из poi--filters-component (читает data-атрибуты с карты)
    scope = Poi.approved.within_bounds(
      params[:sw_lat], params[:sw_lng],
      params[:ne_lat], params[:ne_lng]
    )

    if category_ids.any?
      # Ransack: множественный фильтр по категориям (IN-запрос)
      result = scope.ransack(poi_category_id_in: category_ids).result
    else
      result = scope
    end

    pois = result.includes(:poi_category)
                .order(nearest_first_sql)
                .to_a
    total = pois.size

    # Рендер списка для сайдбара (первая страница)
    pois_list = pois.first(PER_PAGE)
    list_html = ApplicationController.render(
      Poi::ListItemComponent.with_collection(pois_list), layout: false
    )
    more_html = render_load_more(total, PER_PAGE, bounds)
    cable_ready.inner_html(
      selector: "#poi-list",
      html: list_html + more_html.html_safe
    )

    # Рендер маркеров для карты
    features_html = pois.map { |poi|
      lat = poi.latitude
      lng = poi.longitude
      name = poi.localized_name.to_s.gsub('"', '"').gsub("'", "'")
      icon = poi.poi_category&.icon || "mdi-map-marker"
      category = poi.poi_category&.localized_name.to_s.gsub('"', '"')
      category_id = poi.poi_category_id
      address = [ poi.address, poi.city ].compact.join(", ").gsub('"', '"')
      rating = poi.rating&.to_f || 0
      %(<div data-poi-id="#{poi.id}"
             data-poi-lat="#{lat}"
             data-poi-lng="#{lng}"
             data-poi-name="#{name}"
             data-poi-icon="#{icon}"
             data-poi-category="#{category}"
             data-poi-category-id="#{category_id}"
             data-poi-rating="#{rating}"
             data-poi-address="#{address}"
             data-poi-user-id="#{poi.user_id}"></div>)
    }.join("\n")
    cable_ready.inner_html(selector: "#poi-map-features", html: features_html)

    cable_ready.broadcast
    morph :nothing

    Rails.logger.info("PoiReflex: Filtered #{pois.length}/#{total} POIs by categories #{category_ids.inspect}")
  end

  #
  # Apply filters — сохраняет фильтры в сессии и перезагружает POI
  # Вызывается из poi--filters-component при клике на Apply
  #
  # @param params [Hash] { query: String, category_ids: Array<Integer>, sw_lat:, sw_lng:, ne_lat:, ne_lng: }
  #
  def apply_filters(params = {})
    query = params[:query].to_s.strip.presence
    category_ids = Array(params[:category_ids]).map(&:to_i).select(&:positive?)
    Rails.logger.info("[POI REFLEX] apply_filters — category_ids=#{category_ids.inspect}, query=#{query.inspect}")

    scope = Poi.approved.within_bounds(
      params[:sw_lat], params[:sw_lng],
      params[:ne_lat], params[:ne_lng]
    )

    if category_ids.present?
      scope = scope.where(poi_category_id: category_ids)
    end

    if query.present?
      q = "%#{Poi.sanitize_sql_like(query)}%"
      scope = scope.where(
        "EXISTS (SELECT 1 FROM jsonb_each_text(pois.name) WHERE value ILIKE :q) OR EXISTS (SELECT 1 FROM jsonb_each_text(pois.description) WHERE value ILIKE :q)",
        q: q
      )
    end

    pois = scope.includes(:poi_category)
                .order(nearest_first_sql)
                .to_a
    total = pois.size

    # Рендер списка для сайдбара
    pois_list = pois.first(PER_PAGE)
    list_html = ApplicationController.render(
      Poi::ListItemComponent.with_collection(pois_list), layout: false
    )
    more_html = render_load_more(total, PER_PAGE, params)
    cable_ready.inner_html(
      selector: "#poi-list",
      html: list_html + more_html.html_safe
    )

    # Рендер маркеров для карты
    features_html = pois.map { |poi|
      lat = poi.latitude
      lng = poi.longitude
      name = poi.localized_name.to_s.gsub('"', '"').gsub("'", "'")
      icon = poi.poi_category&.icon || "mdi-map-marker"
      category = poi.poi_category&.localized_name.to_s.gsub('"', '"')
      category_id = poi.poi_category_id
      address = [ poi.address, poi.city ].compact.join(", ").gsub('"', '"')
      rating = poi.rating&.to_f || 0
      %(<div data-poi-id="#{poi.id}"
             data-poi-lat="#{lat}"
             data-poi-lng="#{lng}"
             data-poi-name="#{name}"
             data-poi-icon="#{icon}"
             data-poi-category="#{category}"
             data-poi-category-id="#{category_id}"
             data-poi-rating="#{rating}"
             data-poi-address="#{address}"
             data-poi-user-id="#{poi.user_id}"></div>)
    }.join("\n")
    cable_ready.inner_html(selector: "#poi-map-features", html: features_html)

    cable_ready.broadcast
    morph :nothing

    Rails.logger.info("PoiReflex: Applied filters (query=#{query.inspect}, category_ids=#{category_ids.inspect}), got #{pois.length}/#{total} POIs")
  end

  #
  # Reset filters — очищает фильтры в сессии и перезагружает все POI в bounds
  # Вызывается из poi--filters-component при клике на Reset
  #
  # @param params [Hash] { sw_lat:, sw_lng:, ne_lat:, ne_lng: }
  #
  def reset_filters(params = {})
    Rails.logger.info("[POI REFLEX] reset_filters — params: #{params.inspect}")

    scope = Poi.approved.within_bounds(
      params[:sw_lat], params[:sw_lng],
      params[:ne_lat], params[:ne_lng]
    )

    pois = scope.includes(:poi_category)
                .order(nearest_first_sql)
                .to_a
    total = pois.size

    # Рендер списка
    pois_list = pois.first(PER_PAGE)
    list_html = ApplicationController.render(
      Poi::ListItemComponent.with_collection(pois_list), layout: false
    )
    more_html = render_load_more(total, PER_PAGE, params)
    cable_ready.inner_html(
      selector: "#poi-list",
      html: list_html + more_html.html_safe
    )

    # Рендер маркеров
    features_html = pois.map { |poi|
      lat = poi.latitude
      lng = poi.longitude
      name = poi.localized_name.to_s.gsub('"', '"').gsub("'", "'")
      icon = poi.poi_category&.icon || "mdi-map-marker"
      category = poi.poi_category&.localized_name.to_s.gsub('"', '"')
      category_id = poi.poi_category_id
      address = [ poi.address, poi.city ].compact.join(", ").gsub('"', '"')
      rating = poi.rating&.to_f || 0
      %(<div data-poi-id="#{poi.id}"
             data-poi-lat="#{lat}"
             data-poi-lng="#{lng}"
             data-poi-name="#{name}"
             data-poi-icon="#{icon}"
             data-poi-category="#{category}"
             data-poi-category-id="#{category_id}"
             data-poi-rating="#{rating}"
             data-poi-address="#{address}"
             data-poi-user-id="#{poi.user_id}"></div>)
    }.join("\n")
    cable_ready.inner_html(selector: "#poi-map-features", html: features_html)

    cable_ready.broadcast
    morph :nothing

    Rails.logger.info("PoiReflex: Reset filters, showing all #{pois.length}/#{total} POIs in bounds")
  end

  private

  # SQL-фрагмент для сортировки POI по расстоянию от пользователя
  # Если координаты не установлены — fallback на свежие (created_at DESC)
  #
  # @return [String] SQL ORDER BY
  #
  def nearest_first_sql
    lat = session[:user_lat]
    lng = session[:user_lng]
    return "pois.created_at DESC" if lat.nil? || lng.nil?

    Poi.sanitize_sql_array([
      "ST_Distance(pois.coordinates::geography, ST_MakePoint(?, ?)::geography) ASC",
      lng.to_f, lat.to_f
    ])
  end

  public

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

    # Рендерим форму редактирования через Poi::FormComponent
    html = ApplicationController.render(Poi::FormComponent.new(
      poi: poi,
      current_user: current_user,
      categories: PoiCategory.active.by_position,
      user_lat: session[:user_lat],
      user_lng: session[:user_lng]
    ))

    cable_ready.inner_html(selector: "#poi-detail-modal-body", html: html)
    cable_ready.remove_css_class(selector: "[data-poi--detail-component-target='overlay']", name: "hidden")
    cable_ready.broadcast
    morph :nothing

    Rails.logger.info("PoiReflex: Edit form for POI #{poi.id} (#{poi.localized_name})")
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("PoiReflex: POI not found for edit - #{e.message}")
  rescue Pundit::NotAuthorizedError
    Rails.logger.warn("PoiReflex: Not authorized to edit POI #{poi_id}")
  end

  #
  # Создаёт комментарий к POI
  # Вызывается из poi--detail-component#submitComment
  #
  # @param params [Hash] { poi_id: Integer, body: String }
  #
  def create_comment(params = {})
    poi = Poi.find(params[:poi_id])

    # Устанавливаем координаты пользователя для proximity check в политике
    Current.user_lat = session[:user_lat]
    Current.user_lng = session[:user_lng]

    authorize_with_pundit!(PoiComment.new(poi: poi, user: current_user), :create?)

    comment = PoiService.create_comment(
      poi: poi,
      user: current_user,
      body: params[:body]
    )

    # Рендерим обновлённый список комментариев
    comments = PoiComment.where(poi_id: poi.id).includes(:user).recent
    detail_html = ApplicationController.render(Poi::DetailComponent.new(
      poi: poi,
      current_user: current_user,
      comments: comments,
      user_lat: session[:user_lat],
      user_lng: session[:user_lng]
    ))

    cable_ready.inner_html(selector: "#poi-detail-modal-body", html: detail_html)
    cable_ready.broadcast
    morph :nothing

    Rails.logger.info("PoiReflex: Created comment ##{comment.id} for POI #{poi.id}")
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("PoiReflex: POI not found for comment - #{e.message}")
  rescue Pundit::NotAuthorizedError
    Rails.logger.warn("PoiReflex: Not authorized to comment on POI #{params[:poi_id]}")
  rescue PoiService::CreateError => e
    Rails.logger.error("PoiReflex: Comment creation failed - #{e.message}")
  end

  #
  # Reverse geocoding через Nominatim (ReverseGeocodingService)
  # Вызывается из poi--form-component#_reverseGeocode
  # Заполняет поля city/country/address в форме через CableReady
  #
  # @param params [Hash] { lat: Float, lng: Float }
  #
  def reverse_geocode(params = {})
    lat = params[:lat].to_f
    lng = params[:lng].to_f

    if lat == 0.0 || lng == 0.0
      morph :nothing
      return
    end

    result = ReverseGeocodingService.reverse_geocode(lat: lat, lng: lng)

    unless result
      morph :nothing
      return
    end

    # Заполняем поля через CableReady
    if result[:country].present?
      cable_ready.set_attribute(
        selector: "[name='poi[country]']",
        name: "value",
        value: result[:country]
      )
    end

    if result[:city].present?
      cable_ready.set_attribute(
        selector: "[name='poi[city]']",
        name: "value",
        value: result[:city]
      )
    end

    if result[:address].present?
      cable_ready.set_attribute(
        selector: "[name='poi[address]']",
        name: "value",
        value: result[:address]
      )
    end

    if result[:zip_code].present?
      cable_ready.set_attribute(
        selector: "[name='poi[zip_code]']",
        name: "value",
        value: result[:zip_code]
      )
    end

    cable_ready.broadcast
    morph :nothing

    Rails.logger.info "PoiReflex: reverse_geocode(#{lat}, #{lng}) -> #{result.inspect}"
  rescue StandardError => e
    Rails.logger.warn "PoiReflex: reverse_geocode error: #{e.message}"
    morph :nothing
  end
end
