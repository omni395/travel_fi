# frozen_string_literal: true

#
# GamificationService — единый сервис геймификации.
#
# Ответственность:
# 1. Начисление баллов за действия (award!)
# 2. Расчёт уровня от суммы баллов (level_for)
# 3. Начисление баллов пользователю (add_points!)
# 4. Выдача/удаление бейджей (grant_badge!, remove_badge!)
# 5. Пересчёт уровня (update_level!)
# 6. Проверка и выдача бейджей (check_badges!)
# 7. Реферальные бонусы (award_referral!)
#
# Конфиг: config/gamification.yml
#
# Использование:
#   GamificationService.award!(:registration, user)
#   GamificationService.add_points!(user, 10, action_key: "registration")
#   GamificationService.grant_badge!(user, 1)
#
class GamificationService
  LEVELS = [
    { level: 1, min: 0, max: 49 },
    { level: 2, min: 50, max: 199 },
    { level: 3, min: 200, max: 499 },
    { level: 4, min: 500, max: 999 },
    { level: 5, min: 1000, max: Float::INFINITY }
  ].freeze

  class << self
    #
    # Начисляет баллы пользователю за действие
    # 1. Читает количество баллов из конфига
    # 2. Начисляет через add_points!
    # 3. Проверяет условия для бейджей
    #
    # @param action_key [String] ключ действия (registration, poi_create и т.д.)
    # @param user [User] пользователь
    # @param log [String, nil] описание начисления
    #
    def award!(action_key, user, log: nil)
      points = config.dig("rewards", action_key)
      return unless points&.positive?

      add_points!(user, points, action_key: action_key, log: log || action_key.to_s)
      check_badges!(user, action_key)
    end

    #
    # Начисляет баллы пользователю и пересчитывает уровень
    #
    # @param user [User] пользователь
    # @param num [Integer] количество баллов
    # @param action_key [String] ключ действия
    # @param log [String, nil] описание начисления
    #
    def add_points!(user, num, action_key:, log: nil)
      user.gamifications.create!(event_type: "score", value: num, action_key: action_key, log: log)
      update_level!(user)
    end

    #
    # Выдаёт бейдж пользователю
    #
    # @param user [User] пользователь
    # @param badge_id [Integer] ID бейджа
    #
    def grant_badge!(user, badge_id)
      return if user.earned_badge?(badge_id)

      user.gamifications.create!(
        event_type: "badge",
        value: badge_id,
        action_key: badge_key(badge_id)
      )
    end

    #
    # Удаляет бейдж у пользователя
    #
    # @param user [User] пользователь
    # @param badge_id [Integer] ID бейджа
    #
    def remove_badge!(user, badge_id)
      user.gamifications.badges.where(value: badge_id).destroy_all
    end

    #
    # Пересчитывает уровень пользователя на основе суммы баллов
    # Уровни: 1 (0-49), 2 (50-199), 3 (200-499), 4 (500-999), 5 (1000+)
    #
    # @param user [User] пользователь
    #
    def update_level!(user)
      new_level = level_for(user.total_points)
      user.update!(level: new_level) if user.level != new_level
    end

    #
    # Начисляет реферальные бонусы рефереру и новому пользователю
    #
    # @param referrer [User] пользователь, чей код использовали
    # @param new_user [User] только что зарегистрированный пользователь
    #
    def award_referral!(referrer, new_user)
      award!(:referral_bonus_referrer, referrer, log: "Referred user ##{new_user.id}")
      award!(:referral_bonus_new_user, new_user, log: "Referred by ##{referrer.id}")
    end

    #
    # Возвращает уровень для указанного количества баллов
    #
    # @param points [Integer] сумма баллов
    # @return [Integer] уровень (1-5)
    #
    def level_for(points)
      LEVELS.each do |range|
        return range[:level] if points >= range[:min] && points <= range[:max]
      end
      1
    end

    #
    # Возвращает ключ бейджа по его ID
    #
    # @param badge_id [Integer] ID бейджа
    # @return [String, nil] ключ бейджа
    #
    def badge_key(badge_id)
      badge = config.dig("badges", badge_id.to_s)
      badge&.dig("key")
    end

    #
    # Проверяет условия для всех бейджей и выдаёт подходящие
    #
    # @param user [User] пользователь
    # @param action_key [String] ключ выполненного действия
    #
    def check_badges!(user, action_key)
      badges_config.each do |badge_id, badge|
        next if user.earned_badge?(badge_id.to_i)
        next unless badge_matches_action?(badge, action_key, user)

        grant_badge!(user, badge_id.to_i)
      end
    end

    private

    #
    # Загружает конфиг геймификации из YAML
    #
    # @return [Hash]
    #
    def config
      @config ||= YAML.safe_load_file(Rails.root.join("config/gamification.yml"))
    end

    #
    # Возвращает список бейджей из конфига
    #
    # @return [Hash]
    #
    def badges_config
      config["badges"] || {}
    end

    #
    # Проверяет, подходит ли бейдж под выполненное действие
    #
    # @param badge [Hash] конфиг бейджа
    # @param action_key [String] ключ действия
    # @param user [User] пользователь
    # @return [Boolean]
    #
    def badge_matches_action?(badge, action_key, user)
      condition = badge["condition"]
      return false unless condition

      if condition.start_with?("action == ")
        expected_action = condition.split("'")[1]
        return action_key == expected_action
      end

      begin
        user.instance_eval(condition)
      rescue StandardError
        false
      end
    end
  end
end
