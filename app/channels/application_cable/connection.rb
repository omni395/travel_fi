module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      # Устанавливаем current_user из Devise
      # Если пользователь не аутентифицирован, reject соединение
      self.current_user = find_verified_user
      
      if current_user
        puts "[CONNECTION] ✅ ActionCable: User #{current_user.id} connected"
        Rails.logger.info("[CONNECTION] ✅ ActionCable: User #{current_user.id} connected")
      else
        puts "[CONNECTION] ❌ ActionCable: Connection rejected - no authenticated user"
        Rails.logger.warn("[CONNECTION] ❌ ActionCable: Connection rejected - no authenticated user. Warden: #{env["warden"]&.authenticated?(:user) || 'no warden'}")
        reject_unauthorized_connection
      end
    end

    def disconnect
      puts "[CONNECTION] User #{current_user&.id} disconnected"
      Rails.logger.info("[CONNECTION] User #{current_user&.id} disconnected")
    end

    private

    #
    # Находит верифицированного пользователя из сессии Devise
    # Использует cookies и session для определения текущего пользователя
    #
    def find_verified_user
      # Пытаемся получить пользователя из Devise текущей сессии
      env["warden"].user(:user) if env["warden"]&.authenticated?(:user)
    end
  end
end