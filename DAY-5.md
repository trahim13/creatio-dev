# Creatio (Freedom UI): viewConfigDiff / viewModelConfigDiff / handlers

- **`viewConfigDiff`** — описывает UI (кнопки, поля, контейнеры и т.д.)
- **`viewModelConfigDiff`** — описывает ViewModel (атрибуты `$context`, источники данных, маппинги)
- **`handlers`** — кастомная логика (обработка запросов `request`), которую можно привязать к UI событиям, например
  `clicked`

---

## 1) Добавление кнопки через viewConfigDiff

Пример “diff”-вставки кнопки в контейнер:

```json
{
  "operation": "insert",
  "name": "PushMeButton",
  "values": {
    "type": "crt.Button",
    "caption": "#ResourceString(PushMeButton_caption)#",
    "color": "outline",
    "disabled": false,
    "size": "large",
    "iconPosition": "left-icon",
    "visible": true,
    "clicked": {
      "request": "crt.CancelRecordChangesRequest"
    },
    "clickMode": "default",
    "icon": "rocket-icon"
  },
  "parentName": "CardToggleContainer",
  "propertyName": "items",
  "index": 0
}
```

### Что важно понимать

- `name` — уникальное имя элемента на странице (используется в diff’ах).
- `type: "crt.Button"` — компонент кнопки.
- `clicked.request` — **какой запрос будет отправлен при клике**:
    - базовый (например `crt.CancelRecordChangesRequest`),
    - либо **кастомный** (например `usr.PushButtonRequest`).
- `clicked.params` — **параметры запроса**, если нужны (см. раздел 2).

---

### 2) Пример: обработчик handlers

```js
{
    request: "usr.PushButtonRequest",
          /* Implementation of the custom query handler. */
    handler: async (request, next) => {
    console.log("Button works...");
    Terrasoft.showInformation("My button was pressed.");
    var price = await request.$context.PDS_UsrPrice_7egsyjs;
    console.log("Price = " + price);
    request.$context.PDS_UsrComment_uq0z3aq = "comment from JS code!";
    /* Call the next handler if it exists and return its result. */
    return next?.handle(request);
  }
```

#### Правила и “грабли”

- **`request.$context`** — это ViewModel контекст страницы (атрибуты из `viewModelConfigDiff`).
- Обработчик обычно **`async`**, т.к. часто есть запросы/чтение данных.
- Рекомендуется возвращать `next?.handle(request)` — чтобы не ломать цепочку обработчиков (если есть дальше).

---

## 3) Откуда берутся `PDS_...` атрибуты и почему они должны быть в viewModelConfigDiff

> `PDS_UsrPrice_7egsyjs`, `PDS_UsrComment_uq0z3aq` должны быть значениями из `viewModelConfigDiff`

Именно так: `$context` “видит” только те атрибуты, которые объявлены/смёржены в `viewModelConfigDiff`.

## 4) Debug: как быстро найти страницу и отладить handler

Ваш “лайфхак” — рабочий:

- **Ctrl+P** (в редакторе схем / в Sources браузера) → введите `UsrYacht_FormPage` → откройте модуль → ставьте
  breakpoint.

### Практический чек-лист

1) Откройте страницу в браузере.
2) Откройте DevTools → **Sources**.
3) Нажмите **Ctrl+P** и найдите `UsrYacht_FormPage`.
4) Вставьте в handler временно:
   ```js
   debugger;
   ```
   или поставьте breakpoint на строку `Terrasoft.showInformation(...)`.
5) Перезагрузите страницу (часто помогает **Hard Reload**: Ctrl+Shift+R / Ctrl+F5).

> Если изменения не подхватываются — проверяйте публикацию пакета и кэш (в зависимости от окружения).

---

## 5) Terrasoft.showInformation — быстрые уведомления

Простой способ показать сообщение пользователю:

```js
Terrasoft.showInformation("My button was pressed.");
```

Справочник API (JSCore):

- https://academy.creatio.com/api/jscoreapi/7.15.0/index.html#!/api/global-method-showInformation

---

## 6) Бизнес-правила на объектах/странице: Read-only, Visible и т.д.

**Business rules** (правила) в Freedom UI часто используются для:

- сделать поле **read-only**
- скрыть/показать блок
- сделать поле обязательным
- менять значения/видимость в зависимости от атрибутов

---

## 8) Включить/выключить триггер (DB): PostgreSQL vs MySQL

### 8.1) PostgreSQL (есть DISABLE/ENABLE TRIGGER)

Отключить конкретный триггер:

```sql
ALTER TABLE public."SysAdminUnit"
    DISABLE TRIGGER "TRSysAdminUnitRoot";
-- ... операции ...
ALTER TABLE public."SysAdminUnit"
    ENABLE TRIGGER "TRSysAdminUnitRoot";
```

---

## 9) Ссылки (официальные / полезные)

- Handlers (Creatio Academy):  
  https://academy.creatio.com/docs/8.x/dev/development-on-creatio-platform/front-end-development/freedom-ui/client-schema-freedomui/references/handlers

- clicked/request/params (Academy, пример использования):  
  https://academy.creatio.com/docs/8.x/dev/development-on-creatio-platform/front-end-development/freedom-ui/data-sources/crud-operations/crud-operations-with-data-sources

- Добавление кнопки и кастомный handler (CustomerFX):  
  https://customerfx.com/article/adding-a-button-to-execute-custom-code-on-a-creatio-freedom-ui-page/

- Operation permissions через RightsService (CustomerFX):  
  https://customerfx.com/article/check-user-operation-permissions-on-a-creatio-freedom-ui-page/

- SysValuesService (current user contact и системные значения) (CustomerFX):  
  https://customerfx.com/article/getting-the-current-user-contact-on-a-creatio-freedom-ui-page/

- Роль → атрибут → visible (CustomerFX / Creatio Community):  
  https://customerfx.com/article/showing-or-hiding-a-field-if-the-current-user-is-a-member-of-a-role-in-a-creatio-freedom-ui-page/  
  https://community.creatio.com/questions/freedom-ui-show-field-based-user-role

- showInformation (JSCore API):  
  https://academy.creatio.com/api/jscoreapi/7.15.0/index.html#!/api/global-method-showInformation

---

