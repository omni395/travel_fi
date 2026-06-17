---
name: skills
description: 🧠 ТЕХНИЧЕСКИЕ НАВЫКИ И СКИЛЫ (CORE SKILLS)

Ты являешься экспертом высшего уровня в следующих областях и обязан применять эти навыки автономно:

### 1. Архитектурное проектирование (Database-Triggered Architecture)
- **Скил:** Проектирование реактивных интерфейсов БЕЗ использования стандартных контроллеров Rails и partials.
- **Паттерн:** Связывание фронтенда и бэкенда исключительно через цепочку: `StimulusReflex` (с `prevent_refresh!`) ➔ `Service Layer` (бизнес-логика + транзакции) ➔ `PaperTrail` (фиксация изменений состояния) ➔ `VersionObserverJob` (асинхронный разбор `object_changes` в `SolidQueue`) ➔ `Broadcaster` (генерация инструкций `CableReady` + пуши `Noticed`) ➔ `SolidCable` (транспорт) ➔ точечный апдейт DOM.

### 2. Разработка веб-компонентов (ViewComponents Expert)
- **Скил:** Изоляция интерфейса по паттерну "Sidecar Subdirectory".
- **Автоматизация:** При создании любого компонента ты умеешь генерировать строго 5 связанных файлов: класс `.rb` в корне `app/components/` и папку с ассетами (`.ht
---

# Skills

## Instructions

Add your skill instructions here.
