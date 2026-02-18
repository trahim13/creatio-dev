# Creatio 8.3 в Docker: два окружения dev1/dev2 + перенос приложений и данных
Цели:

- иметь **два изолированных runtime** (`runtime/dev1`, `runtime/dev2`) с отдельными логами и конфигами;
- иметь **два изолированных хранилища** (PostgreSQL + Redis) без конфликтов по volume/портам;
- уметь:
    - переносить **приложение** (`.zip` из Application Hub) между `dev1` → `dev2`;
    - переносить **данные** между окружениями через встроенный объект **Data**.
---

## 1) Структура проекта

Структура:

```text
.
├─ creatio/                              # исходники/дистрибутив Creatio (распакованный архив)
│  ├─ Terrasoft.Configuration/           # исходная Terrasoft.Configuration из архива Creatio
│  ├─ Terrasoft.WebHost.dll.config
│  ├─ ConnectionStrings.config
│  └─ ...
├─ runtime/
│  ├─ dev1/
│  │  ├─ Logs/
│  │  ├─ Terrasoft.Configuration/        # рабочая файловая копия (volume в контейнер)
│  │  ├─ Terrasoft.WebHost.dll.config
│  │  └─ ConnectionStrings.config
│  └─ dev2/
│     ├─ Logs/
│     ├─ Terrasoft.Configuration/
│     ├─ Terrasoft.WebHost.dll.config
│     └─ ConnectionStrings.config
├─ docker-compose.dev1.yml
└─ docker-compose.dev2.yml
```

---

## 2) Важно: подготовить `Terrasoft.Configuration` для volume

Для корректной работы **file system development mode** и пакетов на диске,
нужно чтобы в `runtime/dev1` и `runtime/dev2` лежала **полная “эталонная”** `Terrasoft.Configuration`
из исходного архива Creatio.

### Что сделать один раз (до первого старта контейнеров)

1) Скопировать оригинальную папку из архива (из `creatio/Terrasoft.Configuration`) в runtime.


> Почему это важно:  
> если примонтировать в `/app/Terrasoft.Configuration` “пустую” папку, Creatio получит неполное окружение
> для работы с пакетами/компиляцией, и часть функций (особенно IDE/FSD) будет ломаться.

---

## 3) Сохранить наш пакет (UsrYachts) отдельно

После выгрузки пакетов на диск он появится здесь:

```text
runtime/dev1/Terrasoft.Configuration/Pkg/UsrYachts
```

---

## 4) Запуск dev1/dev2 по шагам

### 4.1 Поднять только PostgreSQL (dev1 + dev2)

```text
docker compose -p creatio-dev1 -f docker-compose.dev1.yml up -d postgres
docker compose -p creatio-dev2 -f docker-compose.dev2.yml up -d postgres
```

На этом шаге БД уже запущены, но Creatio ещё нет.

---

## 5) Инициализация PostgreSQL (как в начале, см. [README.md](README.md))


## 6) Поднять всё окружение (Creatio + Redis + PostgreSQL)

```text
docker compose -p creatio-dev1 -f docker-compose.dev1.yml up -d
docker compose -p creatio-dev2 -f docker-compose.dev2.yml up -d
```

Порты (пример):

- dev1: `http://localhost:5000/`
- dev2: `http://localhost:5100/`

---

## 7) Установка приложения из архива и продолжение разработки

По умолчанию приложение, установленное из `.zip` (Application Hub), будет “locked” для редактирования.

Если необходимо, для dev-окружений включаем системную настройку:

- `CanEditOwnAppsFromArchive` = `true`  
  (Allow to edit your own apps from an archive)

Но обычно это не нужно. У нас есть Git + пакеты на файловой системе

---

## 8) Перенос между dev1/dev2: приложение vs данные

### 8.1 Приложение (Configuration / пакеты) — через `.zip`

- Экспортируем приложение из `dev1` в zip (Application Hub archive).
- Устанавливаем zip в `dev2`.

> Этот процесс мы автоматизируем через Clio (см. отдельный README про Clio: [README.md](tools%2Fclio-docker%2FREADME.md)).

### 8.2 Данные (records) — через объект **Data**

В Creatio есть специальный объект/раздел **Data**, который используется для **экспорта/импорта данных**.

Ключевые моменты:

- экспорт/импорт данных делается **отдельно от приложения**;
- при импорте можно выбрать стратегию поведения для повторяющихся записей:
    - обновлять существующую запись (и какие поля обновлять),
    - либо пропускать/не трогать.

#### Если при создании lookup была 500 ошибка (краш)

У меня был кейс: при создании Lookup происходил краш (HTTP 500).
Рабочее решение было:

1) зайти в раздел/объект **Data**,
2) “переопределить тип”/пересохранить (смысл: обновить метаданные),
3) сохранить — после этого Data/Lookup начали работать корректно.

---

## 9) Перенос системных настроек (System settings) между окружениями

Есть удобный паттерн для экспорта/импорта:

- **System setting** — “заголовок” / ключ настройки (что именно переносим),
- **System setting value** — “значение” настройки (что переносим как value).

Если цель — утащить набор системных настроек из `dev1` в `dev2`,
то лучше экспортировать:

- список имён/кодов настроек,
- и соответствующие значения,
  чтобы при импорте можно было корректно применить в другом окружении.

---

## 10) SQL-скрипты: использовать редко

SQL-скрипты в контексте Creatio используются **очень редко** и в основном для:

- аварийной очистки/удаления данных,
- или “жёсткого ремонта” при проблемах данных/ссылочной целостности.

Сначала всегда пытаться решать через штатные механизмы
(Data import/export, packages, system settings), а SQL — только когда очевидно,
что штатные инструменты не подходят.

---

## 11) Восстановление значений Lookup из пакета

Если Lookup/значения были добавлены/изменены например через пакет (`UsrYachts`),
то после:

- установки пакета (или приложения),
- компиляции,
- обновления конфигурации,

часто возможно восстановить Lookup-значения из пакета (т.к. пакет содержит соответствующие изменения конфигурации).
---

## 12) Команды запуска (коротко)

### Поднять только PostgreSQL

```text
docker compose -p creatio-dev1 -f docker-compose.dev1.yml up -d postgres
docker compose -p creatio-dev2 -f docker-compose.dev2.yml up -d postgres
```

### Поднять всё окружение

```text
docker compose -p creatio-dev1 -f docker-compose.dev1.yml up -d
docker compose -p creatio-dev2 -f docker-compose.dev2.yml up -d
```

---