#!/bin/bash

# Выходим при любой ошибке
set -e

echo "🧹 Начинаем зачистку проекта от дичи..."

# 1. Родные рельсовые очистки
if [ -f "bin/rails" ]; then
  echo "👉 Очищаем логи и стандартный tmp через Rails..."
  bin/rails log:clear tmp:clear
else
  echo "👉 Очищаем логи и стандартный tmp через bundle..."
  bundle exec rails log:clear tmp:clear
fi

# 2. Жесткий снос кэша Bootsnap
# На Rails 8 он часто забивается и начинает скармливать старые куски кода при перезапусках
if [ -d "tmp/cache/bootsnap" ]; then
  echo "🚀 Выносим кэш Bootsnap..."
  rm -rf tmp/cache/bootsnap
  rm -rf tmp/cache/bootsnap-compile-cache
fi

# 3. Удаление локально скомпилированных ассетов
# Если ты случайно запустил assets:precompile локально, Propshaft/Sprockets засрут public/assets, 
# и изменения в CSS/JS перестанут подтягиваться в деве.
echo "🎨 Удаляем локальный билд ассетов..."
rm -rf public/assets
rm -rf public/packs
rm -rf tmp/cache/assets

# 4. Удаление мусора от тестов и дебага
echo "🧪 Вычищаем отчеты покрытия (SimpleCov) и историю дебаггеров..."
rm -rf coverage
rm -f .rspec_status
rm -f .byebug_history
rm -f .pry_history

# 5. Системный шлак (особенно актуально, если работаешь на Mac или дергаешь файлы туда-сюда)
echo "🖥️ Выметаем системные скрытые файлы (.DS_Store, свапы)..."
find . -name ".DS_Store" -depth -exec rm {} \;
find . -name "*.swp" -depth -exec rm {} \;
find . -name "*~" -depth -exec rm {} \;

# 6. Очистка Docker (раз уж у тебя контейнеры)
if command -v docker &> /dev/null; then
  echo "🐳 Найдена разводка Docker. Почистить зависшие контейнеры, кэш сборщика и анонимные волумы? (y/n)"
  read -r answer
  if [ "$answer" != "${answer#[Yy]}" ] ;then
    echo "🧹 Запускаем docker system prune..."
    docker system prune -a --volumes -f
  fi
fi

echo "✨ Проект девственно чист. Можно запускаться с чистого листа!"