# frozen_string_literal: true

#
# SettingService — сервис для управления настройками (юзер + глобальные).
#
# Ответственность:
# 1. `update` — атомарное обновление конкретного параметра настройки.
# 2. `toggle` — инверсия булевого параметра.
#
# Безопасность: изменения допустимы ТОЛЬКО для полей из PERMITTED_FIELDS
# (allowlist). Любой неизвестный/запрещённый ключ игнорируется — защита от
# mass-assignment и произвольной записи в служебные колонки (PaperTrail,
# timestamps, user_id, gamification_config и т.д.).
#
class SettingService
  # Все настраиваемые булевы поля (событие × канал).
  # Формируется из списков событий модели. Общий выключатель каналов
  # (мастер-флаги) тоже входит в allowlist.
  PERMITTED_FIELDS = (
    Setting::NOTIFICATIONS_CHANNELS.map { |c| "#{c}_enabled" } +
    (Setting::USER_EVENTS + Setting::ADMIN_EVENTS).flat_map do |event|
      Setting::NOTIFICATIONS_CHANNELS.map { |c| "#{event}_#{c}_enabled" }
    end
  ).freeze

  # Секции gamification_config, редактируемые через форму админа (числовые).
  GAMIFICATION_SECTIONS = %w[rewards pool].freeze

  class << self
    #
    # Обновляет конкретный параметр настройки.
    #
    # @param setting [Setting] объект настроек
    # @param field [String/Symbol] имя поля (должно быть в PERMITTED_FIELDS)
    # @param value [Boolean] новое значение
    # @return [Boolean] успешно ли сохранение
    #
    def update(setting, field, value)
      field = field.to_s
      return false unless permitted?(field)

      setting.update!(field => normalize(value))
      true
    rescue ActiveRecord::RecordInvalid, StandardError => e
      Rails.logger.error("SettingService#update failed: #{e.class} #{e.message}")
      false
    end

    #
    # Инвертирует булевый параметр настройки (из текущего состояния в БД).
    #
    # @param setting [Setting] объект настроек
    # @param field [String/Symbol] имя поля
    # @return [Boolean] новое значение после инверсии
    #
    def toggle(setting, field)
      field = field.to_s
      return false unless permitted?(field)

      current = !!setting.public_send(field)
      setting.update!(field => (!current).to_s)
      !current
    rescue StandardError => e
      Rails.logger.error("SettingService#toggle failed: #{e.class} #{e.message}")
      false
    end

    #
    # Обновляет одно значение в глобальной конфигурации геймификации
    # (gamification_config, JSONB) — для формы настройки админа.
    #
    # Разрешённые секции: rewards (числовые награды), pool (lock_days,
    # warning_balance, critical_balance). Badges (условия/иконки) — структурные,
    # через форму НЕ редактируются (только rewards/pool), чтобы не поломать
    # conditions с instance_eval.
    #
    # @param section [String] "rewards" или "pool"
    # @param key [String] ключ внутри секции (напр. "poi_create", "lock_days")
    # @param value [Numeric, String] новое числовое значение
    # @return [Boolean] успешность сохранения
    #
    def update_gamification(section, key, value)
      section = section.to_s
      key = key.to_s
      return false unless GAMIFICATION_SECTIONS.include?(section)

      setting = Setting.global_settings
      cfg = setting.gamification_config.is_a?(Hash) ? setting.gamification_config.deep_dup : Setting::GAMIFICATION_DEFAULTS.deep_dup

      cleaned = value.to_s.gsub(/\s/, "")
      return false unless cleaned.match?(/\A\d+\z/) # только неотрицательное целое

      numeric = cleaned.to_i

      cfg[section] ||= {}
      cfg[section][key] = numeric
      setting.update!(gamification_config: cfg)
      true
    rescue StandardError => e
      Rails.logger.error("SettingService#update_gamification failed: #{e.class} #{e.message}")
      false
    end

    private

    #
    # Проверяет, что поле разрешено к изменению (allowlist).
    # PERMITTED_FIELDS сформирован из констант Setting и гарантирует
    # существование соответствующего атрибута с сеттером.
    #
    # @param field [String] имя поля
    # @return [Boolean]
    #
    def permitted?(field)
      PERMITTED_FIELDS.include?(field)
    end

    #
    # Нормализует входящее значение в булево (для boolean-колонки).
    #
    # @param value [Object] значение из клиента ("true"/"false"/1/0/true/false)
    # @return [Boolean]
    #
    def normalize(value)
      value == true || value.to_s == "true" || value.to_i == 1
    end
  end
end
