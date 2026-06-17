module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user

      if current_user
        Rails.logger.info("[CONNECTION] ✅ ActionCable: User #{current_user.id} connected")
      else
        Rails.logger.info("[CONNECTION] ✅ ActionCable: Guest connected (no user session)")
      end
    end

    def disconnect
      Rails.logger.info("[CONNECTION] User #{current_user&.id} disconnected")
    end

    private

    # Находит верифицированного пользователя из сессии Devise через Warden.
    # Возвращает объект User или nil. Строгая проверка типа для предотвращения
    # ошибок при нестандартном поведении Warden в контексте ActionCable.
    def find_verified_user
      user = env["warden"]&.user(:user)
      user if user.is_a?(User)
    end
  end
end