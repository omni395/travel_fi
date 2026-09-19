# frozen_string_literal: true

namespace :gamification do
  desc <<~DESC
    Заполняет геймификацию (rewards + pool + badges) в глобальную синглтон-запись
    Setting (user_id = NULL, колонка gamification_config) значениями по умолчанию
    (Setting::GAMIFICATION_DEFAULTS). Идемпотентно: не перезаписывает уже
    сохранённую админом конфигурацию.
  DESC
  task backfill_config: :environment do
    global = Setting.global_settings
    current = global.gamification_config

    if current.present?
      puts "⚠️  gamification_config уже задан — пропускаю (правь через настройки админа)."
      next
    end

    global.update!(gamification_config: Setting::GAMIFICATION_DEFAULTS)
    puts "✅ gamification_config заполнен дефолтами в Setting.global (user_id=#{global.user_id.inspect})."
  end
end
