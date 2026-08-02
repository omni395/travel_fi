# frozen_string_literal: true

# Логгер ActionCable/StimulusReflex направляем в Rails.logger (log/development.log),
# чтобы Reflex-поток (WebSocket) и SQL писались в общий файл лога полностью,
# а не терялись в STDOUT foreman.
ActionCable.server.config.logger = Rails.logger
ActionCable.server.config.logger.level = Logger::DEBUG

