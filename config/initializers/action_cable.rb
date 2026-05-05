# frozen_string_literal: true

# Включи логирование ActionCable для диагностики проблем с WebSocket
# ActionCable.server.config.logger = Logger.new(nil)  # Отключить логирование (слишком шумный)

# Раскомментируй для полного логирования:
ActionCable.server.config.logger = Logger.new(STDOUT)
ActionCable.server.config.logger.level = Logger::INFO

