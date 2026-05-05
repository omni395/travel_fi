# frozen_string_literal: true

#
# PaperTrail Configuration
#
# PaperTrail - это система аудита для Rails, которая автоматически
# отслеживает все изменения в моделях и сохраняет историю изменений.
#
# Документация: https://github.com/paper-trail-gem/paper_trail
#

PaperTrail.config.enabled = true

# Сохранять информацию о том, кто сделал изменение
PaperTrail::Version.class_eval do
  belongs_to :user, optional: true
end


