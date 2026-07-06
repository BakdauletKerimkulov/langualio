# Plan: Registration Flow with Level Assessment

Source: ai_specs/003-registration-flow-spec.md
Created: 2026-05-17

## Overview
Добавляем полный onboarding-флоу: замена поля `name` на `nickname` в регистрации, обязательный тест из 12 вопросов для определения CEFR-уровня, route guard с async-загрузкой профиля, и экран результата. Архитектурно — новая feature `assessment/`, новый `OnboardingStateProvider`, переработанный GoRouter с `refreshListenable`.

## Stages

### Stage 1: Database Migration & Profile Update
**Goal:** Подготовить базу данных — переименовать `name` → `nickname`, добавить `cefr_level` и `assessment_completed`, обновить trigger.
**Files to create/modify:**
- `supabase/migrations/XXXXXXXX_assessment_fields.sql` — миграция: rename column, add columns, update trigger, grandfather existing users
**Steps:**
- [x] Создать миграцию: `ALTER TABLE profiles RENAME COLUMN name TO nickname`
- [x] Добавить `cefr_level INT NULL` и `assessment_completed BOOLEAN DEFAULT false`
- [x] Обновить trigger `handle_new_user()`: читать `nickname` из `raw_user_meta_data->>'nickname'`
- [x] Установить `assessment_completed = true` для всех существующих пользователей (UPDATE)
- [x] Проверить, что RLS policies на `profiles` не затронуты (они используют `auth.uid()`)
**Verification:** `supabase db reset` проходит без ошибок, в таблице видны новые колонки, trigger корректно создает строку с nickname для нового пользователя.

### Stage 2: Auth & Domain Model Changes
**Goal:** Обновить клиентский код — `AppUser`, `AuthNotifier.signUp`, `RegisterScreen` — для работы с nickname вместо name.
**Files to create/modify:**
- `lib/src/features/auth/domain/app_user.dart` — rename `name` → `nickname`
- `lib/src/features/auth/application/auth_provider.dart` — `signUp` передает `data: {'nickname': nickname}`
- `lib/src/features/auth/presentation/register_screen.dart` — поле "Никнейм" + валидация (max 20, только буквы)
- `lib/src/features/profile/domain/user_profile.dart` — rename `name` → `nickname` в модели
**Steps:**
- [x] В `AppUser`: переименовать поле `name` → `nickname`, обновить маппинг из `user_metadata`
- [x] В `AuthNotifier.signUp`: изменить параметр на `nickname`, передавать `data: {'nickname': nickname}`
- [x] В `RegisterScreen`: переименовать контроллер, label → "Никнейм", добавить валидатор (max 20 символов, RegExp `r'^[a-zA-Zа-яА-ЯёЁ0-9]+$'` — буквы + цифры, без спецсимволов)
- [x] В `UserProfile`: переименовать `name` → `nickname`
- [x] Обновить все references к старому полю `name` в проекте
- [x] Запустить `dart run build_runner build --delete-conflicting-outputs`
**Verification:** Регистрация с nickname работает, данные появляются в `profiles.nickname`, валидация отклоняет спецсимволы.

### Stage 3: Assessment Feature — Domain & Data
**Goal:** Создать domain-модели и банк вопросов для теста.
**Files to create/modify:**
- `lib/src/features/assessment/domain/assessment_question.dart` — модель вопроса (enums + class)
- `lib/src/features/assessment/domain/assessment_result.dart` — модель результата
- `lib/src/features/assessment/data/question_bank.dart` — 12 вопросов (статический список)
- `lib/src/features/assessment/data/assessment_repository.dart` — сохранение результата в Supabase
**Steps:**
- [x] Создать enums: `QuestionType`, `Discipline`, `CefrLevel` (с расширениями для описаний и int-индексов)
- [x] Создать `AssessmentQuestion` — immutable class с полями из спеки
- [x] Создать `AssessmentResult` — immutable class с level, correctAnswers, totalQuestions, correctByLevel
- [x] Написать банк из 12 вопросов: A1(2), A2(3), B1(3), B2(3), C1(1); Grammar(5), Reading(4), Listening(3)
- [x] Создать `AssessmentRepository` с методом `saveResult(CefrLevel)` — обновляет `profiles` (set `cefr_level`, `assessment_completed = true`)
- [x] Создать провайдер `assessmentRepositoryProvider` (`@Riverpod(keepAlive: true)`)
**Verification:** Unit-test алгоритма или ручная проверка: банк содержит 12 вопросов с правильным распределением.

### Stage 4: Assessment Feature — Application (Controller & Algorithm)
**Goal:** Реализовать бизнес-логику теста — контроллер состояния и алгоритм определения уровня.
**Files to create/modify:**
- `lib/src/features/assessment/application/assessment_controller.dart` — контроллер теста
- `lib/src/features/assessment/application/level_calculator.dart` — алгоритм CEFR
**Steps:**
- [x] Создать `AssessmentController` (`@riverpod` AsyncNotifier) со state: currentIndex, answers (Map<int, String>), result (nullable)
- [x] Метод `submitAnswer(String answer)` — сохраняет ответ, переходит к следующему вопросу или вычисляет результат
- [x] Метод `calculateLevel()` — реализует алгоритм из спеки (≥80% на уровне и ниже, <60% выше)
- [x] Метод `saveAndComplete()` — вызывает repository, обновляет onboarding state
- [x] Fill-in-the-blank сравнение: `trim().toLowerCase()` (case-insensitive, trim пробелы)
- [x] Запустить `dart run build_runner build --delete-conflicting-outputs`
**Verification:** Ручной тест алгоритма: все правильные → C1, все неправильные → A1, смешанные → корректный уровень.

### Stage 5: Onboarding State & Router Guard
**Goal:** Создать `OnboardingStateProvider` и переработать GoRouter для поддержки async redirect с assessment guard.
**Files to create/modify:**
- `lib/src/features/assessment/application/onboarding_state_provider.dart` — загружает профиль, кэширует `assessmentCompleted`
- `lib/src/routing/app_router.dart` — добавить `refreshListenable`, route `/assessment`, обновить redirect logic
**Steps:**
- [x] Создать `OnboardingState` (isLoading, assessmentCompleted, cefrLevel) и `OnboardingStateProvider` (`@Riverpod(keepAlive: true)`)
- [x] Provider загружает из Supabase `profiles` поля `assessment_completed` и `cefr_level` при инициализации
- [x] Метод `markCompleted(CefrLevel)` для обновления state после прохождения теста
- [x] Создать `RouterRefreshNotifier` (ChangeNotifier) — слушает auth stream + onboarding state changes
- [x] В GoRouter: добавить `refreshListenable: routerRefreshNotifier`
- [x] Обновить redirect: не авторизован → `/login`; авторизован + isLoading → null (остаемся); авторизован + !completed → `/assessment`; fully onboarded + на auth/assessment route → `/`
- [x] Добавить route `/assessment` вне ShellRoute (без bottom nav)
- [x] Запустить `dart run build_runner build --delete-conflicting-outputs`
**Verification:** После регистрации пользователь попадает на `/assessment`, не может уйти назад; после прохождения — на `/`; повторный вход в приложение с `assessment_completed=false` → снова `/assessment`.

### Stage 6: Assessment Feature — Presentation (UI)
**Goal:** Создать экраны теста и результата.
**Files to create/modify:**
- `lib/src/features/assessment/presentation/assessment_screen.dart` — основной экран (orchestrator)
- `lib/src/features/assessment/presentation/widgets/question_card.dart` — карточка вопроса (multiple choice + fill blank)
- `lib/src/features/assessment/presentation/widgets/progress_indicator.dart` — прогресс-бар
- `lib/src/features/assessment/presentation/widgets/result_view.dart` — экран результата
**Steps:**
- [x] `AssessmentScreen`: `PopScope(canPop: false)`, watch controller, показывает question или result view
- [x] `ProgressIndicator`: линейный прогресс-бар + текст "X / 12"
- [x] `QuestionCard` для `multipleChoice`: текст вопроса + context (если есть) + 4 кнопки-варианта
- [x] `QuestionCard` для `fillBlank`: текст вопроса + TextField для ввода ответа + кнопка "Ответить"
- [x] `ResultView`: уровень (большой текст), описание на русском, кнопка "Продолжить" → вызывает saveAndComplete
- [x] Обработка loading state при сохранении результата (кнопка disabled)
- [x] Стилизация по гайдлайнам: `Sizes.pX`, `AppColors`, `gapH/gapW`, Nunito font
**Verification:** Полный ручной прогон: регистрация → 12 вопросов с прогресс-баром → результат → кнопка "Продолжить" → главный экран. Кнопка "назад" заблокирована.

## Supabase Changes
- Migration: rename `profiles.name` → `profiles.nickname`
- Add column `profiles.cefr_level INT NULL`
- Add column `profiles.assessment_completed BOOLEAN DEFAULT false`
- Update trigger `handle_new_user()`: read `nickname` from `raw_user_meta_data`
- Backfill: `UPDATE profiles SET assessment_completed = true WHERE assessment_completed = false`
- Existing `level` field (XP progression) — NOT touched

## Test Coverage
- Алгоритм `calculateLevel`: unit-тесты для edge cases (all correct → C1, all wrong → A1, boundary cases)
- Nickname валидация: unit-тесты для допустимых/недопустимых значений
- Router redirect logic: unit-тест с мок-состояниями (loading, not completed, completed)
- Integration: ручной QA полного флоу

## Risks
- **Router refactoring:** текущий GoRouter не имеет `refreshListenable` — добавление может потребовать рефакторинга provider-зависимостей (router auto-dispose vs auth keepAlive)
- **Async profile loading:** между login и загрузкой профиля может мелькнуть неправильный экран — нужен splash/loading state
- **Migration на проде:** rename column может сломать существующие запросы, если где-то hardcoded `name` — нужно убедиться что все references обновлены
- **Fill-in-the-blank UX:** строгое сравнение может фрустрировать пользователей — вопросы должны быть с однозначными короткими ответами

## Out of Scope
- Аудио для listening (MVP — текстовый транскрипт)
- Пересдача теста
- Адаптивный тест (вопросы подстраиваются под ответы)
- Таймер на вопросы
- Сохранение прогресса теста при закрытии приложения
- Уникальность nickname (пока без проверки)
