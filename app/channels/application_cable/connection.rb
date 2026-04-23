module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :session_id

    def connect
      self.session_id = request.session.id
      # Если используешь Devise, можно добавить:
      # self.current_user = find_verified_user
    end
  end
end