# Версия ассетов
Rails.application.config.assets.version = "1.0"

# Путь для билдов esbuild + Tailwind CLI
Rails.application.config.assets.paths << Rails.root.join("app/assets/builds")
