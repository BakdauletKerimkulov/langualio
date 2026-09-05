---
title: AdminWordList reads state inside build()
status: done
date: 2026-09-05
type: fix
severity: S
references: []
---

## Symptom

Открытие экрана управления словами (`/admin`, `AdminWordListScreen`) немедленно
падает с `Bad state: Tried to read the state of an uninitialized provider`.
Экран не строится, список слов не появляется. В стектрейсе:
`AdminWordListScreen.build:16` → `ref.watch(adminWordListProvider)` →
`AdminWordList.build:54` → `AdminWordList._loadWords:59` →
`NotifierBase.state` → `ProviderElementBase.requireState`.

## Root cause

`AdminWordList.build()` вызывал `_loadWords()` до того, как вернуть начальное
состояние, а первая строка `_loadWords` — `state = state.copyWith(isLoading: true,
error: null)` (`lib/src/features/admin/application/admin_word_list.dart:59`) —
синхронная и **читает** `state`, чтобы взять из него `activeFilter`. Чтение
требует уже проинициализированного `ProviderElement`, а `build()` ещё не
вернулся, поэтому `requireState` бросает.

Сломанное допущение: `_loadWords` спроектирован как метод действия, который
берёт текущий фильтр из состояния, но переиспользован как инициализатор, где
состояния ещё нет.

## Fix

- **Files changed:** `lib/src/features/admin/application/admin_word_list.dart`
- **Failing test that catches the regression:**
  `test/src/features/admin/application/admin_word_list_test.dart::AdminWordList build() does not read state before the provider is initialized`
- **`ai_toolkit/` rules applied:** `riverpod.md` (cleanup через `ref.onDispose` в
  `build()`; `NotifierMounted` + `if (mounted)` после `await`; `ref.read` в
  методах действий), `testing.md` (регрессионный тест обязателен; тесты
  подменяют репозиторий, `ProviderContainer` в unit-тестах), `architecture.md`
  (`application/` без Flutter-виджетов), `code-style.md`.
- **Toolkit deviations:** none.

`_loadWords` теперь принимает фильтр параметром и ничего не читает и не пишет в
`state` до `await`; `build()` возвращает `AdminWordListState(isLoading: true)` и
запускает загрузку с `null`-фильтром. Взведение `isLoading` переехало в
`setFilter()` и `refresh()` — методы действий, вызываемые уже после
инициализации провайдера. Присвоения после `await` остались под существующей
защитой `if (!mounted) return`. Тестом закрыты пять сценариев: инициализация без
чтения состояния, загрузка без фильтра, `setFilter`, `refresh` с сохранением
активного фильтра, ветка ошибки.

## Замечено, но не исправлено

`AdminWordListState.copyWith` присваивает `error: error` без `??`, поэтому любой
вызов `copyWith` без явного `error:` молча стирает ошибку. Здесь это работает в
нашу пользу, но как API — ловушка.

`./scripts/gate.sh --fast` красный на шаге `format`: 65 закоммиченных файлов вне
этого дифа не проходят `dart format` (дрейф версии форматтера). `analyze`,
`custom_lint`, `test` зелёные; файлы этого дифа форматированы чисто. Дрейф —
отдельная задача.
