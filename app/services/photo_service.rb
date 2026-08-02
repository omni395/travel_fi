# frozen_string_literal: true

#
# PhotoService — ЕДИНЫЙ универсальный сервис для всех фотографий приложения.
#
# Бывший ImageTransformService. Обобщён: обрабатывает и прикрепляет картинки
# для любых моделей (аватары User, галерея фото POI, что угодно ещё).
#
# Ответственность:
# 1. Низкоуровневая трансформация файла: webp, resize, итеративное сжатие (process)
# 2. Прикрепление галереи (has_many_attached :photos): attach_photos / remove_photo
# 3. Утилиты: cover-фото, URL (thumb/medium), fallback no-image.png
#
# Вызывающие сервисы (UserService, PoiService) делегируют ВСЕ операции с фото
# этому сервису. Никакой отдельной модели-специфичной логики в других сервисах.
#
class PhotoService
  include Rails.application.routes.url_helpers

  DEFAULT_MAX_SIZE = 300 * 1024 # 300 KB - увеличено для лучшего качества
  DEFAULT_AVATAR_DIMENSION = 512
  MIN_QUALITY = 60 # Минимальное качество 60 (было 30) - чтобы не портить изображение
  QUALITY_STEP = 5 # Меньший шаг (было 10) для более плавного снижения качества

  # Варианты ресайза для ActiveStorage (resize_to_limit сохраняет пропорции)
  THUMB = { resize_to_limit: [ 200, 200 ] }.freeze   # для тултипа карты
  MEDIUM = { resize_to_limit: [ 800, 800 ] }.freeze  # для детальной карточки/галереи

  # Лимиты обработки загружаемых файлов галереи
  PHOTO_MAX_DIMENSION = 1200
  PHOTO_MAX_SIZE = 500.kilobytes

  #
  # Нормализует и сжимает изображение.
  #
  # @param io_or_path [IO, String, Tempfile, File] входное изображение
  # @param filename [String, nil] имя файла (для определения расширения)
  # @param max_size [Integer] максимальный размер файла в байтах
  # @param max_dimension [Integer] максимальное измерение (ширина/высота)
  # @param format [String] целевой формат (webp по умолчанию)
  # @return [Tempfile, File] обработанный файл (или оригинал при отсутствии процессора)
  #
  def self.process(io_or_path, filename: nil, max_size: DEFAULT_MAX_SIZE, max_dimension: DEFAULT_AVATAR_DIMENSION, format: "webp")
    # Normalize input to a file-like object on disk (Tempfile)
    temp = normalize_input(io_or_path, filename)
    begin
      if defined?(ImageProcessing::MiniMagick)
        transform_with_minimagick(temp.path, filename: filename, max_size: max_size, max_dimension: max_dimension, format: format)
      elsif defined?(ImageProcessing::Vips)
        transform_with_vips(temp.path, filename: filename, max_size: max_size, max_dimension: max_dimension, format: format)
      else
        # No processors available — return the original file (caller can decide policy)
        temp
      end
    ensure
      # original temp is returned or closed by transformers; if a new tempfile is returned
      # we ensure original is closed to avoid leaks
      temp.close unless temp.closed?
    end
  end

  #
  # Обрабатывает и прикрепляет один или несколько файлов в галерею записи
  # (ожидает ассоциацию has_many_attached :photos).
  #
  # @param record [ApplicationRecord] запись с has_many_attached :photos
  # @param files [Array<ActionDispatch::Http::UploadedFile>, ActionDispatch::Http::UploadedFile] файлы фото
  # @param audit_touch [Boolean] вызвать record.touch для фиксации в PaperTrail (если трекается)
  # @return [Boolean] true если прикреплено хотя бы одно фото
  #
  def self.attach_photos(record:, files:, audit_touch: false)
    Array(files).each do |file|
      next if file.blank?

      filename = "photo_#{record.class.name.underscore}_#{record.id}_#{SecureRandom.hex(4)}.webp"
      processed = process(
        file,
        filename: filename,
        max_size: PHOTO_MAX_SIZE,
        max_dimension: PHOTO_MAX_DIMENSION,
        format: "webp"
      )

      ActiveRecord::Base.transaction do
        record.photos.attach(io: processed, filename: filename, content_type: "image/webp")
        record.touch if audit_touch
      end
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("PhotoService: attach_photos failed: #{e.message}")
    false
  end

  #
  # Удаляет одно фото из галереи записи (purge_later — асинхронно через SolidQueue).
  #
  # @param record [ApplicationRecord] запись с has_many_attached :photos
  # @param signed_id [String, Integer] id или signed_id удаляемого attachment
  # @param audit_touch [Boolean] вызвать record.touch для фиксации в PaperTrail
  # @return [Boolean] true если фото найдено и удалено
  #
  def self.remove_photo(record:, signed_id:, audit_touch: false)
    attachment = record.photos.find_by(id: signed_id) || ActiveStorage::Attachment.find_by(id: signed_id)
    return false unless attachment

    ActiveRecord::Base.transaction do
      attachment.purge_later
      record.touch if audit_touch
    end

    true
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn("PhotoService: remove_photo failed — photo not found: #{e.message}")
    false
  end

  #
  # Возвращает cover-фото записи (первый attachment в галерее :photos)
  #
  # @param record [ApplicationRecord] запись с has_many_attached :photos
  # @return [ActiveStorage::Attachment, nil]
  #
  def self.cover_photo(record)
    record.photos.first
  end

  #
  # Возвращает URL cover-фото записи для заданного варианта (относительный путь).
  # Если фото нет — nil (fallback на no-image.png решает шаблон/JS).
  #
  # @param record [ApplicationRecord] запись с has_many_attached :photos
  # @param variant [Hash] опции ресайза (THUMB/MEDIUM)
  # @return [String, nil] URL изображения или nil
  #
  def self.cover_photo_url(record, variant: THUMB)
    cover = cover_photo(record)
    return nil unless cover

    if cover.image? && variant
      Rails.application.routes.url_helpers.rails_representation_path(cover.variant(variant), only_path: true)
    else
      Rails.application.routes.url_helpers.rails_blob_path(cover, only_path: true)
    end
  rescue StandardError => e
    Rails.logger.warn("PhotoService: cover_photo_url failed for #{record.class}##{record.id}: #{e.message}")
    nil
  end

  #
  # Возвращает URL всех фото записи для заданного варианта (для галереи)
  #
  # @param record [ApplicationRecord] запись с has_many_attached :photos
  # @param variant [Hash] опции ресайза (THUMB/MEDIUM)
  # @return [Array<String>] массив URL
  #
  def self.photo_urls(record, variant: MEDIUM)
    record.photos.filter_map do |photo|
      if photo.image? && variant
        Rails.application.routes.url_helpers.rails_representation_path(photo.variant(variant), only_path: true)
      else
        Rails.application.routes.url_helpers.rails_blob_path(photo, only_path: true)
      end
    end
  rescue StandardError => e
    Rails.logger.warn("PhotoService: photo_urls failed for #{record.class}##{record.id}: #{e.message}")
    []
  end

  #
  # URL fallback-изображения "нет фото" из app/assets/images/no-image.png
  #
  # @return [String] URL fallback
  #
  def self.fallback_url
    ActionController::Base.helpers.asset_path("no-image.png")
  end

  class << self
    private

    #
    # Приводит вход к файлоподобному объекту на диске (Tempfile)
    #
    # @param io_or_path [Object] входное изображение
    # @param filename [String, nil] имя файла
    # @return [Tempfile, File]
    #
    def normalize_input(io_or_path, filename)
      # If input responds to :read (StringIO/Uploaded file), write to a Tempfile
      if io_or_path.respond_to?(:read)
        tmp = Tempfile.new([ "img_upload", File.extname(filename.to_s) ])
        tmp.binmode
        tmp.write(io_or_path.read)
        tmp.rewind
        return tmp
      end

      # If input is a path string
      if io_or_path.is_a?(String)
        tmp = Tempfile.new([ "img_upload", File.extname(io_or_path) ])
        tmp.binmode
        File.open(io_or_path, "rb") { |f| tmp.write(f.read) }
        tmp.rewind
        return tmp
      end

      # If given a Tempfile/Pathname-like — attempt to return as-is
      if io_or_path.is_a?(Tempfile) || io_or_path.is_a?(File)
        io_or_path
      else
        # Last resort: try to coerce
        tmp = Tempfile.new([ "img_upload", File.extname(filename.to_s) ])
        tmp.binmode
        tmp.write(io_or_path.to_s)
        tmp.rewind
        tmp
      end
    end

    #
    # Трансформация через libvips с итеративным снижением качества/размера
    #
    # @param path [String] путь к исходному файлу
    # @param filename [String, nil] имя файла
    # @param max_size [Integer] максимальный размер файла
    # @param max_dimension [Integer] максимальное измерение
    # @param format [String] целевой формат
    # @return [Tempfile, File] обработанный файл
    #
    def transform_with_vips(path, filename:, max_size:, max_dimension:, format:)
      require "image_processing/vips"
      # Iteratively reduce quality to fit max_size or reduce dimension
      quality = 80
      current_dimension = max_dimension
      Rails.logger.debug("PhotoService: Vips processing for #{filename || File.basename(path)} (max_size=#{max_size}, max_dim=#{max_dimension})")
      loop do
        pipeline = ImageProcessing::Vips.source(path)
        # resize_to_limit сохраняет aspect ratio - указываем только макс размер
        pipeline = pipeline.resize_to_limit(current_dimension, current_dimension) if current_dimension
        pipeline = pipeline.convert(format)
        # call saver with quality for webp
        result = pipeline.saver(quality: quality).call

        size = File.size(result.path)
        Rails.logger.debug("PhotoService: candidate size=#{size} q=#{quality} dim=#{current_dimension}")
        if size <= max_size || quality <= MIN_QUALITY
          return result
        end

        # decrease quality and/or dimension
        if quality - QUALITY_STEP >= MIN_QUALITY
          quality -= QUALITY_STEP
        else
          # reduce dimensions to half if possible
          if current_dimension && current_dimension > 64
            current_dimension = (current_dimension / 2).to_i
            quality = 80
          else
            # give up — return last result
            return result
          end
        end
      end
    rescue => e
      Rails.logger.warn("PhotoService: Vips transform failed: #{e.class} #{e.message}")
      # If vips fails, fallback to original file
      File.open(path)
    end

    #
    # Трансформация через MiniMagick с итеративным снижением качества/размера
    #
    # @param path [String] путь к исходному файлу
    # @param filename [String, nil] имя файла
    # @param max_size [Integer] максимальный размер файла
    # @param max_dimension [Integer] максимальное измерение
    # @param format [String] целевой формат
    # @return [Tempfile, File] обработанный файл
    #
    def transform_with_minimagick(path, filename:, max_size:, max_dimension:, format:)
      require "image_processing/mini_magick"
      quality = 80
      current_dimension = max_dimension
      loop do
        pipeline = ImageProcessing::MiniMagick.source(path)
        pipeline = pipeline.resize_to_limit(current_dimension, current_dimension) if current_dimension
        pipeline = pipeline.convert(format)
        result = pipeline.saver(quality: quality).call

        size = File.size(result.path)
        if size <= max_size || quality <= MIN_QUALITY
          return result
        end

        if quality - QUALITY_STEP >= MIN_QUALITY
          quality -= QUALITY_STEP
        else
          if current_dimension && current_dimension > 64
            current_dimension = (current_dimension / 2).to_i
            quality = 80
          else
            return result
          end
        end
      end
    rescue => e
      Rails.logger.warn("PhotoService: MiniMagick transform failed: #{e.class} #{e.message}")
      File.open(path)
    end
  end
end
