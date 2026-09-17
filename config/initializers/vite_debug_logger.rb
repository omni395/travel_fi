# frozen_string_literal: true

# Server-side debug logging for Vite asset pipeline
if Rails.env.development?
  class ViteDebugLogger
    def initialize(app)
      @app = app
    end

    def call(env)
      path = env["PATH_INFO"] || ""
      if path.start_with?("/vite-dev/")
        method = env["REQUEST_METHOD"]
        query = env["QUERY_STRING"].presence ? "?#{env["QUERY_STRING"]}" : ""
        Rails.logger.info "  \e[36m[VITE_PROXY]\e[0m #{method} #{path}#{query}"
      end
      @app.call(env)
    end
  end

  Rails.application.config.middleware.insert_before(0, ViteDebugLogger)
end
