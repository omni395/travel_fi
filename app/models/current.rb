# frozen_string_literal: true

#
# Current
#
# Thread-safe current request context
# Используется для хранения текущего запроса и пользователя в рамках потока
#
class Current < ActiveSupport::CurrentAttributes
  attribute :request
  attribute :user
  attribute :admin_context
  attribute :user_lat
  attribute :user_lng
end
