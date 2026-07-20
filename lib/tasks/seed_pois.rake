# frozen_string_literal: true

#
# Rake task для наполнения базы тестовыми POI из OpenStreetMap
#
# Делает 1 запрос на категорию+город (UNION всех тегов категории).
# Дедупликация по osm_id.
#
# Запуск:
#   rails seed:pois
#
namespace :seed do
  CITIES = {
    "London"      => { bbox: [ 51.3, -0.5, 51.7, 0.3 ],           country: "United Kingdom" },
    "Paris"       => { bbox: [ 48.8, 2.2, 48.9, 2.5 ],             country: "France" },
    "Berlin"      => { bbox: [ 52.3, 13.2, 52.7, 13.6 ],           country: "Germany" },
    "Tokyo"       => { bbox: [ 35.6, 139.6, 35.8, 139.9 ],         country: "Japan" },
    "New York"    => { bbox: [ 40.6, -74.1, 40.8, -73.9 ],         country: "USA" },
    "Bangkok"     => { bbox: [ 13.7, 100.4, 13.8, 100.6 ],         country: "Thailand" },
    "Dubai"       => { bbox: [ 25.2, 55.2, 25.3, 55.4 ],           country: "UAE" },
    "Sydney"      => { bbox: [ -33.9, 151.1, -33.8, 151.3 ],       country: "Australia" },
    "Singapore"   => { bbox: [ 1.2, 103.6, 1.5, 104.0 ],           country: "Singapore" },
    "Istanbul"    => { bbox: [ 41.0, 28.9, 41.1, 29.1 ],           country: "Turkey" }
  }.freeze

  CATEGORY_MAPPING = {
    "toilets"           => { tags: %w[amenity=toilets] },
    "showers"           => { tags: %w[amenity=shower] },
    "water"             => { tags: %w[amenity=drinking_water amenity=water_point] },
    "pharmacies"        => { tags: %w[amenity=pharmacy shop=chemist] },
    "atms"              => { tags: %w[amenity=atm] },
    "banks"             => { tags: %w[amenity=bank] },
    "currency_exchange" => { tags: %w[amenity=bureau_de_change] },
    "sim_esim"          => { tags: %w[shop=mobile_phone shop=telecommunication] },
    "charging_phone"    => { tags: %w[amenity=device_charging_station] },
    "charging_car"      => { tags: %w[amenity=charging_station] },
    "luggage_storage"   => { tags: %w[amenity=luggage_storage amenity=locker] },
    "laundry"           => { tags: %w[shop=laundry amenity=laundry] },
    "parking"           => { tags: %w[amenity=parking] },
    "tourist_info"      => { tags: %w[tourism=information] },
    "post_office"       => { tags: %w[amenity=post_office] },
    "playgrounds"       => { tags: %w[leisure=playground] }
  }.freeze

  OVERPASS_INSTANCES = [
    "https://overpass.openstreetmap.fr/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass-api.de/api/interpreter",
    "https://overpass-turbo.eu/api/interpreter"
  ].freeze

  desc "Наполняет БД тестовыми POI из OSM (один запрос на категорию+город)"
  task pois: :environment do
    seed_user = User.find_by(email: "seed-bot@example.com")
    abort("seed-bot@example.com не найден. Запусти `rails db:seed`") unless seed_user

    puts "=== Seed POI из OSM ==="
    puts "Города: #{CITIES.keys.join(", ")}"

    total_created = 0
    total_skipped = 0

    CATEGORY_MAPPING.each do |slug, mapping|
      category = PoiCategory.find_by(slug: slug)
      unless category
        puts "\n  ⚠ Категория '#{slug}' не найдена"
        next
      end

      CITIES.each do |city_name, city_data|
        pois = fetch_osm_pois(mapping[:tags], city_data[:bbox])
        next if pois.empty?

        puts "\n--- #{category.localized_name} / #{city_name}: #{pois.size} точек ---"

        pois.each do |elem|
          created = create_poi_from_osm(elem, category, seed_user, city_name, city_data[:country])
          if created
            total_created += 1
          else
            total_skipped += 1
          end
        end
      end
    end

    puts "\n=== Готово! Создано: #{total_created}, Пропущено (дубликаты): #{total_skipped} ==="
  end

  private

  def fetch_osm_pois(tags, bbox)
    south, west, north, east = bbox

    # UNION всех тегов категории в одном запросе
    union = tags.map { |t|
      k, v = t.split("=")
      "node[\"#{k}\"=\"#{v}\"](#{south},#{west},#{north},#{east});"
    }.join("\n       ")

    query = <<~OVERPASS
      [out:json][timeout:60];
      (
        #{union}
      );
      out body center;
    OVERPASS

    OVERPASS_INSTANCES.each do |url|
      begin
        uri = URI(url)
        http = Net::HTTP.new(uri.hostname, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 10
        http.read_timeout = 30
        req = Net::HTTP::Post.new(uri)
        req.set_form_data({ "data" => query })
        req["User-Agent"] = "TravelFi/1.0 (seed-tool; seed-bot@travel-fi.local)"
        response = http.request(req)

        unless response.is_a?(Net::HTTPOK)
          puts "  ⚠ #{url.split('/')[2]}: HTTP #{response.code}"
          next
        end

        data = JSON.parse(response.body)
        elements = (data["elements"] || [])
                   .select { |e| e["type"] == "node" && e["tags"] }
                   .reject { |e| e["tags"]["name"].to_s.match?(/^\d+$/) }

        puts "  ✓ #{url.split('/')[2]}: #{elements.size} точек"
        return elements
      rescue StandardError => e
        puts "  ⚠ #{url.split('/')[2]}: #{e.message}"
      end
    end

    []
  end

  def create_poi_from_osm(elem, category, user, city_name, country)
    osm_id = elem["id"]
    tags = elem["tags"] || {}
    lat = elem["lat"]
    lon = elem["lon"]

    return false if lat.nil? || lon.nil?
    return false if Poi.exists?(osm_id: osm_id)

    name = tags["name"] || tags["operator"] || guess_name_for(tags)
    # Оборачиваем name в JSONB хэш { locale => "..." }
    # Используем I18n.locale чтобы сохранить язык, на котором получено название из OSM
    name_hash = { I18n.locale.to_s => name }
    street = [ tags["addr:street"], tags["addr:housenumber"] ].compact.join(" ")

    PoiService.create(params: {
      poi_category_id: category.id,
      name: name_hash,
      osm_id: osm_id,
      latitude: lat,
      longitude: lon,
      address: street.presence,
      city: tags["addr:city"].presence || city_name,
      country: country,
      zip_code: tags["addr:postcode"].presence,
      phone: tags["phone"].presence,
      website: tags["website"].presence,
      wheelchair_accessible: tags["wheelchair"] == "yes",
      price_info: tags["fee"].presence,
      opening_hours: tags["opening_hours"] ? { osm: tags["opening_hours"] } : nil,
      status: :approved,
      metadata: tags.except(*%w[name operator phone website wheelchair opening_hours fee
                                addr:street addr:housenumber addr:city addr:postcode])
                   .compact_blank
    }, current_user: user)
    true
  rescue ActiveRecord::RecordInvalid
    false
  rescue StandardError => e
    puts "  ⚠ create: #{e.message.truncate(100)}"
    false
  end

  def guess_name_for(tags)
    tag = tags["shop"] && "shop=#{tags["shop"]}" ||
          tags["amenity"] && "amenity=#{tags["amenity"]}" ||
          tags["tourism"] && "tourism=#{tags["tourism"]}" ||
          tags["leisure"] && "leisure=#{tags["leisure"]}"

    {
      "amenity=toilets" => "Public Toilet",
      "amenity=shower" => "Shower",
      "amenity=drinking_water" => "Drinking Water",
      "amenity=water_point" => "Water Point",
      "amenity=pharmacy" => "Pharmacy",
      "amenity=atm" => "ATM",
      "amenity=bank" => "Bank",
      "amenity=bureau_de_change" => "Currency Exchange",
      "amenity=luggage_storage" => "Luggage Storage",
      "amenity=locker" => "Locker",
      "amenity=device_charging_station" => "Device Charging Station",
      "amenity=charging_station" => "Charging Station",
      "amenity=laundry" => "Laundry",
      "amenity=parking" => "Parking",
      "amenity=post_office" => "Post Office",
      "shop=mobile_phone" => "Mobile Phone Shop",
      "shop=telecommunication" => "Telecom Shop",
      "shop=laundry" => "Laundry",
      "shop=chemist" => "Chemist",
      "tourism=information" => "Information Point",
      "leisure=playground" => "Playground"
    }[tag] || "Point of Interest"
  end
end
