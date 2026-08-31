# frozen_string_literal: true

#
# TestGeolocation — единый источник координат тестовой геолокации.
#
# Все system-тесты, которым нужна геолокация браузера (карта, проксимити 100м
# для голосования/комментариев, OSM-импорт), используют эти константы вместо
# размазанных магических чисел. Значение — Берлин (центр карты + fallback).
#
# Координаты обязаны совпадать во всех точках системы:
#   - CDP Emulation.setGeolocationOverride (нативная браузерная геолокация);
#   - JS-стаб navigator.geolocation (getCurrentPosition/watchPosition);
#   - координаты POI, создаваемых в спеках (иначе проксимити 100м блокирует);
#   - fallback-центр карты DEFAULT_MAP_CENTER в map_component_controller.js.
#
# Изменение города тестовой геолокации — только здесь (и в DEFAULT_MAP_CENTER JS).
#
module TestGeolocation
  # Широта тестовой геолокации (Берлин, WGS84).
  DEFAULT_TEST_LAT = 52.52
  # Долгота тестовой геолокации (Берлин, WGS84).
  DEFAULT_TEST_LNG = 13.405
  # Точность (метры) — используется CDP-override и JS-стабом.
  DEFAULT_TEST_ACCURACY = 100
end
