# frozen_string_literal: true

# Service to transform/normalize uploaded images before attaching to ActiveStorage.
#
# Responsibilities:
# - Convert image to a web-friendly format (webp by default)
# - Resize image to a max dimension (preserving aspect ratio)
# - Compress quality iteratively to reach a max file size threshold
# - Provide a fallback to original content if no processor is available
class ImageTransformService
  DEFAULT_MAX_SIZE = 300 * 1024 # 300 KB - увеличено для лучшего качества
  DEFAULT_AVATAR_DIMENSION = 512
  MIN_QUALITY = 60 # Минимальное качество 60 (было 30) - чтобы не портить изображение
  QUALITY_STEP = 5 # Меньший шаг (было 10) для более плавного снижения качества

  def self.process(io_or_path, filename: nil, max_size: DEFAULT_MAX_SIZE, max_dimension: DEFAULT_AVATAR_DIMENSION, format: 'webp')
    # Normalize input to a file-like object on disk (Tempfile)
    temp = normalize_input(io_or_path, filename)
    begin
      if defined?(ImageProcessing::Vips)
        transform_with_vips(temp.path, filename: filename, max_size: max_size, max_dimension: max_dimension, format: format)
      elsif defined?(ImageProcessing::MiniMagick)
        transform_with_minimagick(temp.path, filename: filename, max_size: max_size, max_dimension: max_dimension, format: format)
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

  class << self
    private

    def normalize_input(io_or_path, filename)
      # If input responds to :read (StringIO/Uploaded file), write to a Tempfile
      if io_or_path.respond_to?(:read)
        tmp = Tempfile.new(['img_upload', File.extname(filename.to_s)])
        tmp.binmode
        tmp.write(io_or_path.read)
        tmp.rewind
        return tmp
      end

      # If input is a path string
      if io_or_path.is_a?(String)
        tmp = Tempfile.new(['img_upload', File.extname(io_or_path)])
        tmp.binmode
        File.open(io_or_path, 'rb') { |f| tmp.write(f.read) }
        tmp.rewind
        return tmp
      end

      # If given a Tempfile/Pathname-like — attempt to return as-is
      if io_or_path.is_a?(Tempfile) || io_or_path.is_a?(File)
        io_or_path
      else
        # Last resort: try to coerce
        tmp = Tempfile.new(['img_upload', File.extname(filename.to_s)])
        tmp.binmode
        tmp.write(io_or_path.to_s)
        tmp.rewind
        tmp
      end
    end

    def transform_with_vips(path, filename:, max_size:, max_dimension:, format:)
      require 'image_processing/vips'
      # Iteratively reduce quality to fit max_size or reduce dimension
      quality = 80
      current_dimension = max_dimension
      Rails.logger.debug("ImageTransformService: Vips processing for #{filename || File.basename(path)} (max_size=#{max_size}, max_dim=#{max_dimension})")
      loop do
        pipeline = ImageProcessing::Vips.source(path)
        # resize_to_limit сохраняет aspect ratio - указываем только макс размер
        pipeline = pipeline.resize_to_limit(current_dimension, current_dimension) if current_dimension
        pipeline = pipeline.convert(format)
        # call saver with quality for webp
        result = pipeline.saver(quality: quality).call

        size = File.size(result.path)
        Rails.logger.debug("ImageTransformService: candidate size=#{size} q=#{quality} dim=#{current_dimension}")
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
      Rails.logger.warn("ImageTransformService: Vips transform failed: #{e.class} #{e.message}")
      # If vips fails, fallback to original file
      File.open(path)
    end

    def transform_with_minimagick(path, filename:, max_size:, max_dimension:, format:)
      require 'image_processing/mini_magick'
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
      Rails.logger.warn("ImageTransformService: MiniMagick transform failed: #{e.class} #{e.message}")
      File.open(path)
    end
  end
end
