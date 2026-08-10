# frozen_string_literal: true

#
# Rake task: заполнение пропущенных friendly_id slug у пользователей.
#
# Проблема: колонка slug добавлена миграцией без бэкфилла; пользователи,
# созданные до этого (или без имени — OAuth), имеют slug = nil, из-за чего
# friendly_id-ссылки на их профили нерабочие.
#
# Запуск: bin/rails users:backfill_slugs
#
namespace :users do
  desc "Заполняет пропущенные friendly_id slug у пользователей"
  task backfill_slugs: :environment do
    puts "=== Backfill user slugs (friendly_id) ==="

    fixed = 0

    User.where(slug: nil).find_each do |user|
      # Читаемый slug из имени; при пустом имени — "user-<id>"
      base = user.name.to_s.parameterize.presence || "user-#{user.id}"

      # Уникализация: добавляем числовой суффикс при коллизии
      slug = base
      n = 2
      while User.where.not(id: user.id).exists?(slug: slug)
        slug = "#{base}-#{n}"
        n += 1
      end

      # update_columns минует колбэки/аудит — разовый бэкфилл данных, не runtime-логика
      user.update_columns(slug: slug)
      fixed += 1
    end

    puts "Заполнено slug: #{fixed}"
    puts "=== Done ==="
  end
end
