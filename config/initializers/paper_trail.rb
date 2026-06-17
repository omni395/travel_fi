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

#
# Используем JSON-сериализатор для object и object_changes.
#
# По умолчанию PaperTrail использует YAML для text-колонок,
# но UserAuditLogger и PaperTrailAuditService пишут JSON.
# JSON-сериализатор гарантирует совместимость.
#
# ВАЖНО: Существующие YAML-данные в таблице versions нужно сконвертировать:
#   bin/rails versions:convert_to_json
#
# PaperTrail автоматически определяет тип колонки (text/jsonb)
# через метод object_col_is_json? из VersionConcern.
#
PaperTrail.config.serializer = PaperTrail::Serializers::JSON
