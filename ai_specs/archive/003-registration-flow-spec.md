# Spec: Registration Flow with Level Assessment

Created: 2026-05-17
Status: refined

## Goal
Создать полный флоу регистрации, где пользователь регистрируется с nickname, затем проходит обязательный тест из 12 вопросов для определения CEFR-уровня английского. Приложение не пускает дальше, пока оба шага не выполнены.

## Background
Сейчас регистрация собирает name, email, password и сразу пускает в приложение. Нет оценки уровня — все данные в home/profile мокнутые. Нужен onboarding-тест, чтобы адаптировать контент под уровень пользователя.

## User Flow

### Регистрация
1. Пользователь открывает экран регистрации
2. Вводит **nickname** (вместо текущего name), email, password
3. Нажимает "Зарегистрироваться"
4. Аккаунт создается, nickname сохраняется в профиле
5. Перенаправляется на экран теста

### Тест определения уровня
6. Показывается экран с прогресс-баром (1/12, 2/12, ...)
7. Пользователь отвечает на 12 вопросов последовательно
8. Типы вопросов: multiple choice (4 варианта) и fill-in-the-blank
9. Дисциплины: Grammar (5), Reading (4), Listening (3)
10. После последнего вопроса — экран результата

### Результат
11. Показывается определённый уровень (например, "B1")
12. Краткое описание уровня на русском
13. Кнопка "Продолжить" → переход в приложение

### Redirect Guards
- Не зарегистрирован → `/login` (или `/register`)
- Зарегистрирован, тест не пройден → `/assessment` (экран теста)
- Зарегистрирован + тест пройден → `/` (приложение)

## Requirements

### Must Have
- [ ] Заменить поле `name` на `nickname` в регистрации и профиле
- [ ] Валидация nickname: max 20 символов, только латиница или кириллица (без спецсимволов, цифры — на усмотрение, но без @#$%& и т.д.)
- [ ] Банк вопросов из 12 штук, хранится локально (JSON/Dart)
- [ ] Каждый вопрос имеет: текст, тип (multiple_choice / fill_blank), дисциплину (grammar/reading/listening), CEFR-уровень, варианты ответа, правильный ответ
- [ ] Распределение вопросов по уровням: A1(2), A2(3), B1(3), B2(3), C1(1)
- [ ] Распределение по дисциплинам: Grammar(5), Reading(4), Listening(3)
- [ ] Экран теста с прогресс-баром (текущий вопрос / всего)
- [ ] Без таймера на вопросы
- [ ] Алгоритм определения уровня: пользователь уровня X правильно отвечает на ≥80% вопросов уровня X и ниже, и <60% вопросов уровня X+1
- [ ] Экран результата с уровнем и описанием на русском
- [ ] Сохранение результата (уровень) в профиле пользователя (новое поле `cefr_level` в таблице `profiles`)
- [ ] Route guard: зарегистрированный без теста → принудительный redirect на тест (с async profile loading)
- [ ] Если закрыл приложение во время теста — начинать тест сначала

### Nice to Have
- [ ] Анимация перехода между вопросами
- [ ] Анимация показа результата (confetti / celebrate)
- [ ] Индикатор дисциплины на каждом вопросе (Grammar / Reading / Listening)

## Technical Constraints

### Архитектура
- Feature: `lib/src/features/assessment/` (domain, data, application, presentation)
- State management: Riverpod с code generation (`@riverpod`)
- Navigation: GoRouter, новый route `/assessment` (вне ShellRoute, без bottom nav)
- Банк вопросов: локальный Dart файл (list of model objects) для быстрого доступа

### Зависимости (что нужно реализовать параллельно)
- `OnboardingStateProvider` — новый провайдер (`@Riverpod(keepAlive: true)`), загружает из Supabase `assessment_completed` и `cefr_level` для текущего пользователя
- Обновить `AuthNotifier.signUp` — передавать `data: {'nickname': nickname}` вместо `data: {'name': name}`
- Добавить `refreshListenable` в GoRouter — слушает и auth state, и onboarding state
- Показывать loading/splash пока профиль загружается после логина (не редиректить в неопределённом состоянии)

### Модели (domain)
```dart
enum QuestionType { multipleChoice, fillBlank }
enum Discipline { grammar, reading, listening }
enum CefrLevel { a1, a2, b1, b2, c1 }

class AssessmentQuestion {
  final String id;
  final String text;
  final QuestionType type;
  final Discipline discipline;
  final CefrLevel level;
  final List<String> options; // для multiple_choice
  final String correctAnswer;
  final String? context; // для reading — текст для чтения; для listening — описание/транскрипт
}

class AssessmentResult {
  final CefrLevel level;
  final int correctAnswers;
  final int totalQuestions;
  final Map<CefrLevel, int> correctByLevel;
}
```

### База данных
- Добавить в таблицу `profiles`:
  - Переименовать `name` → `nickname`
  - Добавить поле `cefr_level` (int, nullable) — индекс CEFR (1=A1, 2=A2, 3=B1, 4=B2, 5=C1). NULL = тест не пройден.
  - Добавить поле `assessment_completed` (boolean, default false)
  - Существующее поле `level` (int) НЕ ТРОГАТЬ — оно используется для XP-прогрессии
- Миграция: rename column + add columns + обновить trigger `handle_new_user()`
- **Существующие пользователи:** `assessment_completed = true` (grandfather — не заставлять проходить тест)
- **Новые пользователи:** `assessment_completed = false` (обязаны пройти тест)
- Trigger `handle_new_user()`: обновить — писать в `nickname` вместо `name`, брать из `raw_user_meta_data->>'nickname'`

### Router Guard Logic

**Проблема:** GoRouter `redirect` — синхронный. Текущий роутер читает `currentSession` напрямую, без Riverpod. Для проверки `assessmentCompleted` нужен профиль из Supabase (async).

**Решение:** Паттерн с `refreshListenable` + кэшированный профиль:

1. Создать `OnboardingStateProvider` (`@Riverpod(keepAlive: true)`) — загружает профиль из Supabase, кэширует `assessmentCompleted`
2. Добавить `refreshListenable` в GoRouter, который слушает изменения и auth, и onboarding state
3. Пока профиль загружается (AsyncLoading) — показывать splash/loading screen, НЕ редиректить
4. Redirect читает из кэшированного состояния провайдера

```
// OnboardingState: { isLoading, assessmentCompleted }
// Обновляется при: логине, завершении теста

redirect(state) {
  final session = currentSession;
  final isAuthRoute = state.matchedLocation in ['/login', '/register'];
  final isAssessmentRoute = state.matchedLocation == '/assessment';
  
  if (session == null) {
    return isAuthRoute ? null : '/login';
  }
  
  // Профиль ещё загружается — не редиректить
  final onboarding = ref.read(onboardingStateProvider);
  if (onboarding.isLoading) return null;
  
  // Authenticated, тест не пройден
  if (!onboarding.assessmentCompleted) {
    return isAssessmentRoute ? null : '/assessment';
  }
  
  // Fully onboarded
  if (isAuthRoute || isAssessmentRoute) return '/';
  return null;
}
```

**Route `/assessment`:** вне `ShellRoute` (без bottom nav), один route с внутренним state management через `AssessmentController`. Подэкраны (вопросы → результат) управляются контроллером, не суб-роутами.

### Алгоритм определения уровня
```
Для каждого уровня X (от C1 вниз до A1):
  correctAtX = правильных ответов на уровне X / всего вопросов на уровне X
  correctBelowX = правильных на всех уровнях ≤ X / всего вопросов на уровнях ≤ X

Уровень пользователя = максимальный X, где:
  - correctBelowOrEqualX >= 80%
  - correctAboveX < 60% (или нет вопросов выше)

Если ни один уровень не подходит — A1 (минимальный).
```

### Listening вопросы
- Для MVP: listening вопросы будут текстовыми (транскрипт диалога / предложения) без аудио
- Формат: дается текст (диалог/предложение) и вопрос по нему

### Описания уровней (для экрана результата)
```
A1: "Ты понимаешь простые фразы и можешь представиться. Отличное начало!"
A2: "Ты можешь общаться в простых бытовых ситуациях — магазин, кафе, транспорт."
B1: "Ты можешь общаться в большинстве повседневных ситуаций и понимаешь основную мысль текстов."
B2: "Ты свободно общаешься на разные темы и понимаешь сложные тексты."
C1: "Ты владеешь языком на продвинутом уровне — понимаешь нюансы и можешь выражать сложные мысли."
```

## Edge Cases
- **Все ответы неправильные** → уровень A1
- **Все ответы правильные** → уровень C1
- **Fill-in-the-blank: регистр** → сравнение case-insensitive, trim пробелы
- **Fill-in-the-blank: опечатки** → строгое сравнение (без fuzzy matching для MVP)
- **Пользователь закрыл приложение во время теста** → при следующем входе тест начинается сначала (assessment_completed = false → redirect на /assessment)
- **Пользователь нажимает "назад" на экране теста** → заблокировать системную кнопку назад (`PopScope` с `canPop: false`)
- **Переименование name → nickname в существующих данных** → миграция должна сохранить текущие значения
- **Существующие пользователи после миграции** → `assessment_completed = true`, не блокируются тестом
- **Fill-in-the-blank: дизайн вопросов** → использовать однозначные короткие ответы (1-2 слова) чтобы минимизировать проблемы со строгим сравнением

## Out of Scope
- Аудио для listening (MVP — текстовый транскрипт)
- Пересдача теста
- Адаптивный тест (вопросы подстраиваются под ответы)
- Таймер на вопросы
- Сохранение прогресса теста при закрытии приложения
- Уникальность nickname (пока без проверки)

## Definition of Done
- [ ] Поле nickname работает при регистрации и отображается в профиле
- [ ] Валидация nickname корректна (20 символов, только буквы)
- [ ] Тест из 12 вопросов отображается с прогресс-баром
- [ ] Multiple choice и fill-in-the-blank типы работают
- [ ] Алгоритм определения уровня корректно вычисляет CEFR
- [ ] Экран результата показывает уровень и описание
- [ ] CEFR-уровень сохраняется в `cefr_level` в профиле (Supabase)
- [ ] Route guard не пускает в приложение без прохождения теста
- [ ] Route guard не пускает обратно на тест после прохождения
- [ ] Закрытие приложения во время теста → тест сначала
- [ ] Кнопка "назад" заблокирована во время теста
- [ ] Manual QA: полный флоу от регистрации до главного экрана
