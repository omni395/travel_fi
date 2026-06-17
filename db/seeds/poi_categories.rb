# frozen_string_literal: true

#
# Seed для 10 категорий POI с полями (OSM-теги)
# Все select/multiselect options имеют локализованные label (en, ru, es, zh)
# Формат: { key: "machine_name", label: { en: "...", ru: "...", es: "...", zh: "..." } }
#

puts "Seeding POI categories..."

categories = [
  {
    name: { en: "SIM/eSIM", ru: "SIM/eSIM", es: "SIM/eSIM", zh: "SIM/eSIM" },
    slug: "sim_esim",
    icon: "mdi-sim",
    description: { en: "Mobile operators and SIM card providers", ru: "Операторы мобильной связи и продавцы SIM-карт", es: "Operadores móviles y proveedores de tarjetas SIM", zh: "移动运营商和SIM卡提供商" },
    position: 1,
    fields: [
      { field_key: "operator_names", field_type: "multiselect",
        label: { en: "Operators", ru: "Операторы", es: "Operadores", zh: "运营商" },
        required: true,
        options: { values: [
          { key: "vodafone", label: { en: "Vodafone", ru: "Vodafone", es: "Vodafone", zh: "沃达丰" } },
          { key: "orange", label: { en: "Orange", ru: "Orange", es: "Orange", zh: "Orange" } },
          { key: "t_mobile", label: { en: "T-Mobile", ru: "T-Mobile", es: "T-Mobile", zh: "T-Mobile" } },
          { key: "att", label: { en: "AT&T", ru: "AT&T", es: "AT&T", zh: "AT&T" } },
          { key: "verizon", label: { en: "Verizon", ru: "Verizon", es: "Verizon", zh: "Verizon" } },
          { key: "o2", label: { en: "O2", ru: "O2", es: "O2", zh: "O2" } },
          { key: "three", label: { en: "Three", ru: "Three", es: "Three", zh: "Three" } },
          { key: "ee", label: { en: "EE", ru: "EE", es: "EE", zh: "EE" } },
          { key: "tim", label: { en: "TIM", ru: "TIM", es: "TIM", zh: "TIM" } },
          { key: "movistar", label: { en: "Movistar", ru: "Movistar", es: "Movistar", zh: "Movistar" } },
          { key: "claro", label: { en: "Claro", ru: "Claro", es: "Claro", zh: "Claro" } },
          { key: "telcel", label: { en: "Telcel", ru: "Telcel", es: "Telcel", zh: "Telcel" } }
        ]}, position: 1 },
      { field_key: "has_esim", field_type: "boolean",
        label: { en: "eSIM available", ru: "eSIM доступна", es: "eSIM disponible", zh: "支持eSIM" },
        required: true, position: 2 },
      { field_key: "requires_passport", field_type: "boolean",
        label: { en: "Passport required", ru: "Требуется паспорт", es: "Requiere pasaporte", zh: "需要护照" },
        required: false, position: 3 },
      { field_key: "price_range", field_type: "string",
        label: { en: "Price range", ru: "Ценовой диапазон", es: "Rango de precios", zh: "价格范围" },
        required: false,
        placeholder: { en: "e.g. $10-$50", ru: "например 10-50$", es: "ej. $10-$50", zh: "例如 $10-$50" },
        position: 4 }
    ]
  },
  {
    name: { en: "Toilets/Showers", ru: "Туалеты/Душевые", es: "Baños/Duchas", zh: "厕所/淋浴" },
    slug: "toilets_showers",
    icon: "mdi-toilet",
    description: { en: "Public toilets and shower facilities", ru: "Общественные туалеты и душевые", es: "Baños públicos y duchas", zh: "公共厕所和淋浴设施" },
    position: 2,
    fields: [
      { field_key: "has_showers", field_type: "boolean",
        label: { en: "Showers available", ru: "Есть душевые", es: "Duchas disponibles", zh: "有淋浴" },
        required: true, position: 1 },
      { field_key: "fee_amount", field_type: "string",
        label: { en: "Fee", ru: "Стоимость", es: "Tarifa", zh: "费用" },
        required: false, placeholder: { en: "e.g. Free, $1", ru: "например Бесплатно, 1$", es: "ej. Gratis, $1", zh: "例如 免费, $1" },
        position: 2 },
      { field_key: "wheelchair_accessible", field_type: "boolean",
        label: { en: "Wheelchair accessible", ru: "Доступно для инвалидов", es: "Accesible para silla de ruedas", zh: "无障碍通道" },
        required: false, position: 3 },
      { field_key: "has_changing_table", field_type: "boolean",
        label: { en: "Changing table", ru: "Пеленальный столик", es: "Mesa de cambio", zh: "有换尿布台" },
        required: false, position: 4 }
    ]
  },
  {
    name: { en: "Water", ru: "Вода", es: "Agua", zh: "饮用水" },
    slug: "water",
    icon: "mdi-water",
    description: { en: "Drinking water points and refill stations", ru: "Питьевая вода и станции заправки воды", es: "Puntos de agua potable y estaciones de recarga", zh: "饮用水点和加水站" },
    position: 3,
    fields: [
      { field_key: "water_type", field_type: "select",
        label: { en: "Water type", ru: "Тип воды", es: "Tipo de agua", zh: "水源类型" },
        required: true,
        options: { values: [
          { key: "potable", label: { en: "Potable", ru: "Питьевая", es: "Potable", zh: "可饮用" } },
          { key: "non_potable", label: { en: "Non-potable", ru: "Непитьевая", es: "No potable", zh: "不可饮用" } },
          { key: "recycled", label: { en: "Recycled", ru: "Очищенная", es: "Reciclada", zh: "循环水" } }
        ]}, position: 1 },
      { field_key: "is_free", field_type: "boolean",
        label: { en: "Free", ru: "Бесплатно", es: "Gratis", zh: "免费" },
        required: true, position: 2 },
      { field_key: "has_hose", field_type: "boolean",
        label: { en: "Hose available", ru: "Есть шланг", es: "Manguera disponible", zh: "有软管" },
        required: false, position: 3 },
      { field_key: "suitable_for_drinking", field_type: "boolean",
        label: { en: "Suitable for drinking", ru: "Пригодна для питья", es: "Apta para beber", zh: "适合饮用" },
        required: true, position: 4 }
    ]
  },
  {
    name: { en: "Laundry", ru: "Прачечные", es: "Lavandería", zh: "洗衣店" },
    slug: "laundry",
    icon: "mdi-washing-machine",
    description: { en: "Laundry services and self-service laundromats", ru: "Прачечные и прачечные самообслуживания", es: "Servicios de lavandería y lavanderías autoservicio", zh: "洗衣服务和自助洗衣店" },
    position: 4,
    fields: [
      { field_key: "laundry_type", field_type: "select",
        label: { en: "Type", ru: "Тип", es: "Tipo", zh: "类型" },
        required: true,
        options: { values: [
          { key: "self_service", label: { en: "Self-service", ru: "Самообслуживание", es: "Autoservicio", zh: "自助" } },
          { key: "full_service", label: { en: "Full service", ru: "Полный сервис", es: "Servicio completo", zh: "全套服务" } },
          { key: "both", label: { en: "Both", ru: "Оба варианта", es: "Ambos", zh: "两者都有" } }
        ]}, position: 1 },
      { field_key: "has_dryer", field_type: "boolean",
        label: { en: "Dryer available", ru: "Есть сушилка", es: "Secadora disponible", zh: "有烘干机" },
        required: true, position: 2 },
      { field_key: "price_per_load", field_type: "string",
        label: { en: "Price per load", ru: "Цена за загрузку", es: "Precio por carga", zh: "每次洗涤价格" },
        required: false, placeholder: { en: "e.g. $3-5", ru: "например 3-5$", es: "ej. $3-5", zh: "例如 $3-5" },
        position: 3 },
      { field_key: "has_soap_vending", field_type: "boolean",
        label: { en: "Soap vending machine", ru: "Автомат с мылом", es: "Máquina expendedora de jabón", zh: "有肥皂自动售货机" },
        required: false, position: 4 }
    ]
  },
  {
    name: { en: "Luggage Storage", ru: "Хранение багажа", es: "Consigna de equipaje", zh: "行李寄存" },
    slug: "luggage_storage",
    icon: "mdi-luggage",
    description: { en: "Luggage storage and left luggage facilities", ru: "Камеры хранения багажа", es: "Consignas de equipaje", zh: "行李寄存处" },
    position: 5,
    fields: [
      { field_key: "storage_type", field_type: "select",
        label: { en: "Storage type", ru: "Тип хранения", es: "Tipo de almacenamiento", zh: "寄存类型" },
        required: true,
        options: { values: [
          { key: "locker", label: { en: "Locker", ru: "Ячейка", es: "Taquilla", zh: "储物柜" } },
          { key: "staffed_counter", label: { en: "Staffed counter", ru: "Стойка администратора", es: "Mostrador atendido", zh: "人工柜台" } },
          { key: "automated", label: { en: "Automated", ru: "Автомат", es: "Automático", zh: "自动寄存" } }
        ]}, position: 1 },
      { field_key: "price_per_hour", field_type: "string",
        label: { en: "Price per hour", ru: "Цена за час", es: "Precio por hora", zh: "每小时价格" },
        required: false, placeholder: { en: "e.g. $2/hr", ru: "например 2$/час", es: "ej. $2/h", zh: "例如 $2/小时" },
        position: 2 },
      { field_key: "price_per_day", field_type: "string",
        label: { en: "Price per day", ru: "Цена за день", es: "Precio por día", zh: "每天价格" },
        required: false, placeholder: { en: "e.g. $10/day", ru: "например 10$/день", es: "ej. $10/día", zh: "例如 $10/天" },
        position: 3 },
      { field_key: "max_duration_hours", field_type: "number",
        label: { en: "Max duration (hours)", ru: "Макс. срок (часы)", es: "Duración máxima (horas)", zh: "最长寄存时间（小时）" },
        required: false, position: 4 }
    ]
  },
  {
    name: { en: "Charging Stations", ru: "Зарядки", es: "Estaciones de carga", zh: "充电站" },
    slug: "charging_stations",
    icon: "mdi-battery-charging",
    description: { en: "Device charging stations and power outlets", ru: "Зарядные станции для устройств и розетки", es: "Estaciones de carga para dispositivos y enchufes", zh: "设备充电站和电源插座" },
    position: 6,
    fields: [
      { field_key: "charging_type", field_type: "multiselect",
        label: { en: "Charging types", ru: "Типы зарядки", es: "Tipos de carga", zh: "充电类型" },
        required: true,
        options: { values: [
          { key: "usb_a", label: { en: "USB-A", ru: "USB-A", es: "USB-A", zh: "USB-A" } },
          { key: "usb_c", label: { en: "USB-C", ru: "USB-C", es: "USB-C", zh: "USB-C" } },
          { key: "wireless", label: { en: "Wireless", ru: "Беспроводная", es: "Inalámbrica", zh: "无线充电" } },
          { key: "power_outlet", label: { en: "Power outlet", ru: "Розетка", es: "Enchufe", zh: "电源插座" } },
          { key: "fast_charging", label: { en: "Fast charging", ru: "Быстрая зарядка", es: "Carga rápida", zh: "快充" } }
        ]}, position: 1 },
      { field_key: "is_free", field_type: "boolean",
        label: { en: "Free", ru: "Бесплатно", es: "Gratis", zh: "免费" },
        required: true, position: 2 },
      { field_key: "requires_purchase", field_type: "boolean",
        label: { en: "Requires purchase", ru: "Требуется покупка", es: "Requiere compra", zh: "需要消费" },
        required: false, position: 3 },
      { field_key: "has_seating", field_type: "boolean",
        label: { en: "Seating available", ru: "Есть места для сидения", es: "Asientos disponibles", zh: "有座位" },
        required: false, position: 4 }
    ]
  },
  {
    name: { en: "ATMs", ru: "Банкоматы", es: "Cajeros automáticos", zh: "自动取款机" },
    slug: "atms",
    icon: "mdi-currency-usd",
    description: { en: "ATMs and currency exchange points", ru: "Банкоматы и обмен валют", es: "Cajeros automáticos y cambio de divisas", zh: "自动取款机和货币兑换点" },
    position: 7,
    fields: [
      { field_key: "bank_name", field_type: "string",
        label: { en: "Bank name", ru: "Название банка", es: "Nombre del banco", zh: "银行名称" },
        required: false, position: 1 },
      { field_key: "fee_percentage", field_type: "string",
        label: { en: "Fee percentage", ru: "Комиссия (%)", es: "Porcentaje de comisión", zh: "手续费百分比" },
        required: false, placeholder: { en: "e.g. 3%", ru: "например 3%", es: "ej. 3%", zh: "例如 3%" },
        position: 2 },
      { field_key: "currencies", field_type: "multiselect",
        label: { en: "Currencies", ru: "Валюты", es: "Monedas", zh: "支持的货币" },
        required: true,
        options: { values: [
          { key: "usd", label: { en: "USD", ru: "USD", es: "USD", zh: "美元" } },
          { key: "eur", label: { en: "EUR", ru: "EUR", es: "EUR", zh: "欧元" } },
          { key: "gbp", label: { en: "GBP", ru: "GBP", es: "GBP", zh: "英镑" } },
          { key: "chf", label: { en: "CHF", ru: "CHF", es: "CHF", zh: "瑞士法郎" } },
          { key: "jpy", label: { en: "JPY", ru: "JPY", es: "JPY", zh: "日元" } },
          { key: "cny", label: { en: "CNY", ru: "CNY", es: "CNY", zh: "人民币" } },
          { key: "rub", label: { en: "RUB", ru: "RUB", es: "RUB", zh: "卢布" } },
          { key: "try", label: { en: "TRY", ru: "TRY", es: "TRY", zh: "里拉" } },
          { key: "thb", label: { en: "THB", ru: "THB", es: "THB", zh: "泰铢" } },
          { key: "vnd", label: { en: "VND", ru: "VND", es: "VND", zh: "越南盾" } }
        ]}, position: 3 },
      { field_key: "has_exchange", field_type: "boolean",
        label: { en: "Currency exchange available", ru: "Обмен валют", es: "Cambio de divisas disponible", zh: "提供货币兑换" },
        required: false, position: 4 }
    ]
  },
  {
    name: { en: "Parking", ru: "Парковки", es: "Estacionamiento", zh: "停车场" },
    slug: "parking",
    icon: "mdi-parking",
    description: { en: "Parking lots and parking spaces", ru: "Парковки и парковочные места", es: "Estacionamientos y plazas de aparcamiento", zh: "停车场和停车位" },
    position: 8,
    fields: [
      { field_key: "parking_type", field_type: "select",
        label: { en: "Parking type", ru: "Тип парковки", es: "Tipo de estacionamiento", zh: "停车类型" },
        required: true,
        options: { values: [
          { key: "street", label: { en: "Street", ru: "Улица", es: "Calle", zh: "路边" } },
          { key: "lot", label: { en: "Lot", ru: "Площадка", es: "Lote", zh: "停车场" } },
          { key: "garage", label: { en: "Garage", ru: "Гараж", es: "Garaje", zh: "车库" } },
          { key: "underground", label: { en: "Underground", ru: "Подземная", es: "Subterráneo", zh: "地下" } },
          { key: "rv", label: { en: "RV", ru: "Для автодомов", es: "Para autocaravanas", zh: "房车" } }
        ]}, position: 1 },
      { field_key: "fee_amount", field_type: "string",
        label: { en: "Fee", ru: "Стоимость", es: "Tarifa", zh: "费用" },
        required: false, placeholder: { en: "e.g. Free, $5/hr", ru: "например Бесплатно, 5$/час", es: "ej. Gratis, $5/h", zh: "例如 免费, $5/小时" },
        position: 2 },
      { field_key: "has_security", field_type: "boolean",
        label: { en: "Security", ru: "Охрана", es: "Seguridad", zh: "有安保" },
        required: false, position: 3 },
      { field_key: "max_height_meters", field_type: "number",
        label: { en: "Max height (meters)", ru: "Макс. высота (метры)", es: "Altura máxima (metros)", zh: "最大高度（米）" },
        required: false, position: 4 },
      { field_key: "has_electric_charging", field_type: "boolean",
        label: { en: "EV charging", ru: "Зарядка для электромобилей", es: "Carga para vehículos eléctricos", zh: "电动车充电" },
        required: false, position: 5 }
    ]
  },
  {
    name: { en: "Pharmacies", ru: "Аптеки", es: "Farmacias", zh: "药店" },
    slug: "pharmacies",
    icon: "mdi-medical-bag",
    description: { en: "Pharmacies and drugstores", ru: "Аптеки и лекарственные магазины", es: "Farmacias y droguerías", zh: "药店和药房" },
    position: 9,
    fields: [
      { field_key: "pharmacy_type", field_type: "select",
        label: { en: "Type", ru: "Тип", es: "Tipo", zh: "类型" },
        required: true,
        options: { values: [
          { key: "chain", label: { en: "Chain", ru: "Сеть", es: "Cadena", zh: "连锁" } },
          { key: "independent", label: { en: "Independent", ru: "Частная", es: "Independiente", zh: "独立" } },
          { key: "hospital", label: { en: "Hospital", ru: "Больничная", es: "Hospitalaria", zh: "医院" } },
          { key: "online", label: { en: "Online", ru: "Онлайн", es: "En línea", zh: "在线" } }
        ]}, position: 1 },
      { field_key: "has_prescription", field_type: "boolean",
        label: { en: "Prescription service", ru: "Рецептурный отпуск", es: "Servicio de recetas", zh: "处方药服务" },
        required: true, position: 2 },
      { field_key: "is_24h", field_type: "boolean",
        label: { en: "24 hours", ru: "Круглосуточно", es: "24 horas", zh: "24小时" },
        required: false, position: 3 },
      { field_key: "has_consultation", field_type: "boolean",
        label: { en: "Consultation available", ru: "Консультация", es: "Consulta disponible", zh: "提供咨询" },
        required: false, position: 4 }
    ]
  },
  {
    name: { en: "Bonus", ru: "Бонусные", es: "Bonificación", zh: "其他便利设施" },
    slug: "bonus",
    icon: "mdi-star-circle",
    description: { en: "Other useful points of interest for travelers", ru: "Другие полезные для путешественников места", es: "Otros puntos de interés útiles para viajeros", zh: "其他对旅行者有用的地点" },
    position: 10,
    fields: [
      { field_key: "bonus_type", field_type: "select",
        label: { en: "Type", ru: "Тип", es: "Tipo", zh: "类型" },
        required: true,
        options: { values: [
          { key: "free_wifi", label: { en: "Free WiFi", ru: "Бесплатный WiFi", es: "WiFi gratis", zh: "免费WiFi" } },
          { key: "lounge", label: { en: "Lounge", ru: "Лаунж", es: "Salón", zh: "休息室" } },
          { key: "prayer_room", label: { en: "Prayer room", ru: "Молельная комната", es: "Sala de oración", zh: "祈祷室" } },
          { key: "nursing_room", label: { en: "Nursing room", ru: "Комната матери и ребёнка", es: "Sala de lactancia", zh: "哺乳室" } },
          { key: "pet_area", label: { en: "Pet area", ru: "Зона для животных", es: "Zona para mascotas", zh: "宠物区" } },
          { key: "kids_play_area", label: { en: "Kids play area", ru: "Детская игровая зона", es: "Zona de juegos infantiles", zh: "儿童游乐区" } },
          { key: "post_office", label: { en: "Post office", ru: "Почта", es: "Oficina de correos", zh: "邮局" } },
          { key: "library", label: { en: "Library", ru: "Библиотека", es: "Biblioteca", zh: "图书馆" } },
          { key: "co_working", label: { en: "Co-working space", ru: "Коворкинг", es: "Espacio de coworking", zh: "共享办公空间" } }
        ]}, position: 1 },
      { field_key: "is_free", field_type: "boolean",
        label: { en: "Free", ru: "Бесплатно", es: "Gratis", zh: "免费" },
        required: true, position: 2 },
      { field_key: "requires_membership", field_type: "boolean",
        label: { en: "Requires membership", ru: "Требуется членство", es: "Requiere membresía", zh: "需要会员资格" },
        required: false, position: 3 },
      { field_key: "description", field_type: "string",
        label: { en: "Description", ru: "Описание", es: "Descripción", zh: "描述" },
        required: false, placeholder: { en: "Brief description", ru: "Краткое описание", es: "Breve descripción", zh: "简要描述" },
        position: 4 }
    ]
  },
  # Showers — отдельно от туалетов
  {
    name: { en: "Showers", ru: "Душевые", es: "Duchas", zh: "淋浴" },
    slug: "showers",
    icon: "mdi-shower",
    description: { en: "Public shower facilities", ru: "Общественные душевые", es: "Duchas públicas", zh: "公共淋浴设施" },
    position: 11,
    fields: [
      { field_key: "has_hot_water", field_type: "boolean",
        label: { en: "Hot water", ru: "Горячая вода", es: "Agua caliente", zh: "热水" },
        required: true, position: 1 },
      { field_key: "fee_amount", field_type: "string",
        label: { en: "Fee", ru: "Стоимость", es: "Tarifa", zh: "费用" },
        required: false, placeholder: { en: "e.g. Free, $3", ru: "например Бесплатно, 3$", es: "ej. Gratis, $3", zh: "例如 免费, $3" },
        position: 2 }
    ]
  },
  # Banks — отдельно от банкоматов
  {
    name: { en: "Banks", ru: "Банки", es: "Bancos", zh: "银行" },
    slug: "banks",
    icon: "mdi-bank",
    description: { en: "Bank branches", ru: "Отделения банков", es: "Sucursales bancarias", zh: "银行分行" },
    position: 12,
    fields: [
      { field_key: "bank_name", field_type: "string",
        label: { en: "Bank name", ru: "Название банка", es: "Nombre del banco", zh: "银行名称" },
        required: false, position: 1 },
      { field_key: "has_atm", field_type: "boolean",
        label: { en: "ATM available", ru: "Есть банкомат", es: "Cajero disponible", zh: "有自动取款机" },
        required: false, position: 2 },
      { field_key: "has_exchange", field_type: "boolean",
        label: { en: "Currency exchange", ru: "Обмен валют", es: "Cambio de divisas", zh: "货币兑换" },
        required: false, position: 3 }
    ]
  },
  # Currency Exchange — отдельно
  {
    name: { en: "Currency Exchange", ru: "Обмен валют", es: "Cambio de divisas", zh: "货币兑换" },
    slug: "currency_exchange",
    icon: "mdi-currency-usd",
    description: { en: "Currency exchange points", ru: "Пункты обмена валют", es: "Puntos de cambio de divisas", zh: "货币兑换点" },
    position: 13,
    fields: [
      { field_key: "rates_displayed", field_type: "boolean",
        label: { en: "Rates displayed", ru: "Курс отображается", es: "Tarifas mostradas", zh: "显示汇率" },
        required: false, position: 1 },
      { field_key: "commission_percentage", field_type: "string",
        label: { en: "Commission", ru: "Комиссия", es: "Comisión", zh: "手续费" },
        required: false, placeholder: { en: "e.g. 3%", ru: "например 3%", es: "ej. 3%", zh: "例如 3%" },
        position: 2 }
    ]
  },
  # Phone Charging — отдельно от авто-зарядок
  {
    name: { en: "Phone Charging", ru: "Зарядка телефонов", es: "Carga de teléfonos", zh: "手机充电" },
    slug: "charging_phone",
    icon: "mdi-cellphone-charging",
    description: { en: "Device charging stations", ru: "Станции зарядки устройств", es: "Estaciones de carga de dispositivos", zh: "设备充电站" },
    position: 14,
    fields: [
      { field_key: "charging_types", field_type: "multiselect",
        label: { en: "Charging types", ru: "Типы зарядки", es: "Tipos de carga", zh: "充电类型" },
        required: true,
        options: { values: [
          { key: "usb_a", label: { en: "USB-A", ru: "USB-A", es: "USB-A", zh: "USB-A" } },
          { key: "usb_c", label: { en: "USB-C", ru: "USB-C", es: "USB-C", zh: "USB-C" } },
          { key: "wireless", label: { en: "Wireless", ru: "Беспроводная", es: "Inalámbrica", zh: "无线充电" } }
        ]}, position: 1 },
      { field_key: "is_free", field_type: "boolean",
        label: { en: "Free", ru: "Бесплатно", es: "Gratis", zh: "免费" },
        required: true, position: 2 },
      { field_key: "has_seating", field_type: "boolean",
        label: { en: "Seating available", ru: "Есть места для сидения", es: "Asientos disponibles", zh: "有座位" },
        required: false, position: 3 }
    ]
  },
  # Tourist Info
  {
    name: { en: "Tourist Info", ru: "Туристическая информация", es: "Información turística", zh: "旅游信息" },
    slug: "tourist_info",
    icon: "mdi-information",
    description: { en: "Tourist information points", ru: "Информационные туристические пункты", es: "Puntos de información turística", zh: "旅游信息点" },
    position: 15,
    fields: [
      { field_key: "has_maps", field_type: "boolean",
        label: { en: "Free maps", ru: "Бесплатные карты", es: "Mapas gratuitos", zh: "免费地图" },
        required: false, position: 1 },
      { field_key: "has_wifi", field_type: "boolean",
        label: { en: "Free WiFi", ru: "Бесплатный WiFi", es: "WiFi gratis", zh: "免费WiFi" },
        required: false, position: 2 }
    ]
  },
  # Post Office
  {
    name: { en: "Post Office", ru: "Почта", es: "Oficina de correos", zh: "邮局" },
    slug: "post_office",
    icon: "mdi-email",
    description: { en: "Post offices", ru: "Почтовые отделения", es: "Oficinas de correos", zh: "邮局" },
    position: 16,
    fields: [
      { field_key: "has_parcel_service", field_type: "boolean",
        label: { en: "Parcel service", ru: "Отправка посылок", es: "Servicio de paquetes", zh: "包裹服务" },
        required: false, position: 1 },
      { field_key: "has_poste_restante", field_type: "boolean",
        label: { en: "Poste restante", ru: "До востребования", es: "Lista de correos", zh: "存局候领" },
        required: false, position: 2 }
    ]
  },
  # Playgrounds
  {
    name: { en: "Playgrounds", ru: "Детские площадки", es: "Parques infantiles", zh: "儿童游乐场" },
    slug: "playgrounds",
    icon: "mdi-playground",
    description: { en: "Children's playgrounds", ru: "Детские игровые площадки", es: "Parques infantiles", zh: "儿童游乐场" },
    position: 17,
    fields: [
      { field_key: "has_shade", field_type: "boolean",
        label: { en: "Shade", ru: "Есть навес", es: "Sombra", zh: "有遮阳" },
        required: false, position: 1 },
      { field_key: "fenced", field_type: "boolean",
        label: { en: "Fenced", ru: "Огорожено", es: "Cercado", zh: "有围栏" },
        required: false, position: 2 },
      { field_key: "suitable_for", field_type: "select",
        label: { en: "Suitable for", ru: "Подходит для", es: "Adecuado para", zh: "适合" },
        required: true,
        options: { values: [
          { key: "toddlers", label: { en: "Toddlers", ru: "Малышей", es: "Bebés", zh: "幼儿" } },
          { key: "children", label: { en: "Children", ru: "Детей", es: "Niños", zh: "儿童" } },
          { key: "all", label: { en: "All ages", ru: "Всех возрастов", es: "Todas las edades", zh: "所有年龄段" } }
        ]}, position: 3 }
    ]
  },
  # EV Charging — отдельно от зарядок для телефонов
  {
    name: { en: "EV Charging", ru: "Зарядка для электромобилей", es: "Carga para vehículos eléctricos", zh: "电动汽车充电" },
    slug: "charging_car",
    icon: "mdi-ev-station",
    description: { en: "Electric vehicle charging stations", ru: "Зарядные станции для электромобилей", es: "Estaciones de carga para vehículos eléctricos", zh: "电动汽车充电站" },
    position: 18,
    fields: [
      { field_key: "charging_types", field_type: "multiselect",
        label: { en: "Charging types", ru: "Типы зарядки", es: "Tipos de carga", zh: "充电类型" },
        required: true,
        options: { values: [
          { key: "type2", label: { en: "Type 2", ru: "Type 2", es: "Type 2", zh: "Type 2" } },
          { key: "ccs", label: { en: "CCS", ru: "CCS", es: "CCS", zh: "CCS" } },
          { key: "chademo", label: { en: "CHAdeMO", ru: "CHAdeMO", es: "CHAdeMO", zh: "CHAdeMO" } },
          { key: "tesla", label: { en: "Tesla Supercharger", ru: "Tesla Supercharger", es: "Tesla Supercharger", zh: "特斯拉超级充电" } }
        ]}, position: 1 },
      { field_key: "is_free", field_type: "boolean",
        label: { en: "Free", ru: "Бесплатно", es: "Gratis", zh: "免费" },
        required: false, position: 2 },
      { field_key: "price_per_kwh", field_type: "string",
        label: { en: "Price per kWh", ru: "Цена за кВт·ч", es: "Precio por kWh", zh: "每千瓦时价格" },
        required: false, placeholder: { en: "e.g. $0.30/kWh", ru: "например 0.30$/кВт·ч", es: "ej. $0.30/kWh", zh: "例如 $0.30/千瓦时" },
        position: 3 },
      { field_key: "max_power_kw", field_type: "string",
        label: { en: "Max power (kW)", ru: "Макс. мощность (кВт)", es: "Potencia máxima (kW)", zh: "最大功率（千瓦）" },
        required: false, placeholder: { en: "e.g. 50kW, 150kW", ru: "например 50кВт, 150кВт", es: "ej. 50kW, 150kW", zh: "例如 50千瓦, 150千瓦" },
        position: 4 },
      { field_key: "has_roof", field_type: "boolean",
        label: { en: "Covered", ru: "Под навесом", es: "Cubierto", zh: "有顶棚" },
        required: false, position: 5 }
    ]
  }
]

categories.each do |cat_data|
  fields = cat_data.delete(:fields)

  category = PoiCategory.find_or_initialize_by(slug: cat_data[:slug])
  category.assign_attributes(cat_data)
  category.save!

  fields.each do |field_data|
    field = category.poi_category_fields.find_or_initialize_by(field_key: field_data[:field_key])
    field.assign_attributes(field_data)
    field.save!
  end

  puts "  ✓ #{cat_data[:name][:en]} (#{category.poi_category_fields.count} fields)"
end

puts "Seeding POI categories completed!"
