# frozen_string_literal: true

require "open3"

#
# OsmPbfParser — стриминговый читатель бинарного файла OpenStreetMap (.osm.pbf)
#
# Реализация НЕ тянет сторонний Ruby-гем (ffi-osmium отсутствует в Gemfile.lock).
# Используется автообнаружение зрелого внешнего CLI-инструмента и построчное
# чтение (Open3) — файл не загружается в память целиком, что критично для
# региональных выгрузок в десятки ГБ.
#
# Приоритет инструментов:
#   1. osmium   (osmium-tool)   — `osmium cat --output-format=opl`
#   2. osmconvert               — `osmconvert --out-opl`
#   3. ogr2ogr  (GDAL)          — `ogr2ogr -f GeoJSON /vsistdout/`
#
# Формат вывода — OPL (Osmium osmium cat --output-format=opl):
#   n<id> v<ver> d<delta> c<changeset> t<tags_csv> x<lon> y<lat>
#   Теги в t= через запятую "key=value", специальные символы экранируются как "_".
#   Relation: "r<id> ..." / Way: "w<id> ..." — пропускаются (POI — только точки).
#
# @example
#   OsmPbfParser.new("/tmp/region.osm.pbf").each_record { |rec| ... }
#
class OsmPbfParser
  # Инструменты и команды их вызова (выбор по наличию в PATH)
  TOOLS = [
    { key: :osmium,     command: ->(path) { %w[osmium cat --output-format=opl --overwrite -o -] + [ path ] } },
    { key: :osmconvert, command: ->(path) { [ "osmconvert", path, "--out-opl", "-" ] } },
    { key: :ogr2ogr,    command: ->(path) { [ "ogr2ogr", "-f", "GeoJSON", "/vsistdout/", path ] } }
  ].freeze

  # Ошибка: ни один инструмент не установлен
  class ToolNotFoundError < StandardError; end

  # Ошибка: CLI завершился с ошибкой
  class ReadError < StandardError; end

  #
  # @param file_path [String] абсолютный путь к .osm.pbf файлу
  # @param tool [Symbol, nil] принудительный инструмент (:osmium/:osmconvert/:ogr2ogr)
  #
  def initialize(file_path, tool: nil)
    @file_path = file_path
    @tool_key = tool
  end

  #
  # Возвращает выбранный инструмент (автообнаружение по PATH)
  #
  # @return [Hash] { key:, command: }
  # @raise [ToolNotFoundError] если ни один инструмент не найден
  #
  def tool
    return @tool if defined?(@tool)

    @tool = TOOLS.find { |t| tool_available?(t[:key]) } ||
            raise(ToolNotFoundError, missing_tool_message)
  end

  #
  # Итерирует записи OSM (.pbf), отдавая хэши { id:, lat:, lon:, tags: }
  #
  # @yield [Hash] запись точки { id: Integer, lat: Float, lon: Float, tags: Hash }
  # @return [void]
  # @raise [ReadError] при ненулевом коде выхода CLI
  #
  def each_record
    Open3.popen3(*tool[:command].call(@file_path)) do |stdin, stdout, stderr, wait_thr|
      stdin.close

      case tool[:key]
      when :ogr2ogr
        each_record_from_geojson(stdout)
      else
        each_record_from_opl(stdout)
      end

      error = stderr.read
      status = wait_thr.value
      raise ReadError, "OSM CLI failed (#{status}): #{error.presence}" unless status.success?
    end
  rescue Errno::ENOENT => e
    raise ToolNotFoundError, missing_tool_message
  end

  private

  #
  # Парсит OPL-строку в запись { id:, lat:, lon:, tags: }
  # Формат: "n123 ... tkey=value,key2=value2 x10.0 y50.0"
  #
  # @param line [String] строка OPL
  # @return [Hash, nil] запись или nil если не точка/нет тегов
  #
  def parse_opl_line(line)
    line = line.strip
    return nil unless line.start_with?("n")

    id_match = line.match(/\An(\d+)/)
    return nil unless id_match

    tags = parse_opl_tags(line)
    return nil if tags.empty?

    lat = parse_opl_float(line, "y")
    lon = parse_opl_float(line, "x")
    return nil unless lat && lon

    { id: id_match[1].to_i, lat: lat, lon: lon, tags: tags }
  end

  #
  # Извлекает теги из OPL-строки: "tkey=abc,key2=x_y z" (экранирование "_")
  #
  # @param line [String] OPL-строка
  # @return [Hash{String=>String}]
  #
  def parse_opl_tags(line)
    # Осторожный регулярный поиск: "t" затем теги до разделителя " x" (lon) или " y" (lat).
    tags_str = line[/\st(.+?)(?:\s+x|-?\d+)\s+/, 1]
    return {} unless tags_str

    tags_str.split(",").each_with_object({}) do |pair, acc|
      k, v = pair.split("=", 2)
      next unless k.present?

      acc[unescape_opl(k)] = v ? unescape_opl(v) : ""
    end
  end

  #
  # Убирает экранирование OPL ("_" перед спецсимволом)
  #
  # @param str [String]
  # @return [String]
  #
  def unescape_opl(str)
    str.gsub(/_([,=])/, '\1')
  end

  #
  # Извлекает число с плавающей точкой по ключу ("x"/"y") из OPL
  #
  # @param line [String] OPL-строка
  # @param key [String] "x" (lon) или "y" (lat)
  # @return [Float, nil]
  #
  def parse_opl_float(line, key)
    val = line[/\s#{key}(-?\d+\.?\d*) /, 1] || line[/\s#{key}(-?\d+\.?\d*)\z/, 1]
    val&.to_f
  end

  #
  # Обрабатывает OPL-поток
  #
  def each_record_from_opl(io)
    io.each_line do |line|
      rec = parse_opl_line(line)
      yield rec if rec
    end
  end

  #
  # Обрабатывает GeoJSON-поток (ogr2ogr) построчно
  #
  def each_record_from_geojson(io)
    io.each_line do |line|
      json = parse_geojson_feature(line)
      yield json if json
    end
  end

  #
  # Парсит одну Feature-строку GeoJSON (эмитится ogr2ogr построчно)
  #
  def parse_geojson_feature(line)
    line = line.strip
    return nil unless line.start_with?("{")

    feat = JSON.parse(line)
    return nil unless feat["type"] == "Feature"

    coords = feat.dig("geometry", "coordinates")
    return nil if coords.nil?

    tags = feat["properties"] || {}
    return nil if tags.empty?

    {
      id: feat["id"].to_i || tags["osm_id"].to_i,
      lat: coords[1],
      lon: coords[0],
      tags: tags
    }
  rescue JSON::ParserError
    nil
  end

  #
  # Доступен ли инструмент в PATH
  #
  def tool_available?(key)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
      bin = File.join(dir, key.to_s)
      File.file?(bin) && File.executable?(bin)
    end
  end

  #
  # Сообщение об отсутствии инструмента с инструкцией установки
  #
  def missing_tool_message
    <<~MSG.squish
      OsmPbfParser: не найден ни один инструмент чтения .osm.pbf
      (osmium / osmconvert / ogr2ogr). Установите один из них:
      macOS: `brew install osmium-tool`; Ubuntu: `sudo apt-get install osmium-tool`.
    MSG
  end
end
