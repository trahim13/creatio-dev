
--

## 1) Handler: пересчёт поля при изменении других полей

`crt.HandleViewModelAttributeChangeRequest` вызывается **при изменении любого атрибута ViewModel**, включая изменения после загрузки данных из источника.

### Пример: пересчитать TicketPrice = Price / Passengers

> Важно:
> - избегайте деления на 0 / null,
> - не допускайте рекурсии (когда вы меняете атрибут — это тоже триггерит change),
> - всегда вызывайте `next?.handle(request)` чтобы не ломать цепочку обработчиков.

```js
export default {
  handlers: [
    {
      request: "crt.HandleViewModelAttributeChangeRequest",
      handler: async (request, next) => {
        const watched = new Set([
          "PDS_UsrPrice_c1126n0",
          "PDS_UsrPassengersCount_ipyyc0l"
        ]);

        // не реагируем на изменения других атрибутов
        if (!watched.has(request.attributeName)) {
          return next?.handle(request);
        }

        // читаем значения (в Freedom UI это часто async-доступ через $context)
        const priceRaw = await request.$context.PDS_UsrPrice_c1126n0;
        const passengersRaw = await request.$context.PDS_UsrPassengersCount_ipyyc0l;

        const price = Number(priceRaw);
        const passengers = Number(passengersRaw);

        // защита от NaN/0
        const ticketPrice =
          Number.isFinite(price) && Number.isFinite(passengers) && passengers > 0
            ? price / passengers
            : null;

        // записываем производное поле
        // (проверьте, что это поле есть в модели и привязано к нужному path)
        request.$context.PDS_UsrTicketPrice_1nw4l11 = ticketPrice;

        return next?.handle(request);
      }
    }
  ]
};
```

### Как понять “правильные” имена атрибутов (`PDS_..._xxxxx`)
1) Откройте **Source code** страницы в Freedom UI Designer и найдите нужный атрибут (обычно ключ вида `PDS_UsrPrice_c1126n0`).
2) Либо временно поставьте handler‑логгер на `request.attributeName`, чтобы увидеть, что реально меняется при ваших бизнес‑правилах.

---

## 2) Validators: валидация значений полей

Validators — это функции, которые проверяют корректность значения **атрибута ViewModel**.

### 2.1. Объявляем тип валидатора в секции `validators`
Требования:
- тип валидатора — **PascalCase** и **с vendor‑префиксом** (например `usr.DGValidator`),
- валидатор возвращает `null`, если всё ок, иначе объект с `message`.

```js
export default {
  validators: /**SCHEMA_VALIDATORS*/ {
    "usr.DGValidator": {
      validator: function (config) {
        return function (control) {
          const value = control.value;
          const minValue = config.minValue;

          const valueIsCorrect = value >= minValue;
          if (valueIsCorrect) {
            return null;
          }
          return {
            "usr.DGValidator": {
              message: config.message
            }
          };
        };
      },
      params: [
        { name: "minValue" },
        { name: "message" }
      ],
      async: false
    }
  } /**SCHEMA_VALIDATORS*/
};
```

### 2.2. Подключаем валидатор к нужным атрибутам
Пример: цена и площадь.

```js
export default {
  viewModelConfig: {
    attributes: {
      "PDS_UsrPriceUSD_o6qqcz6": {
        modelConfig: { path: "PDS.UsrPriceUSD" },
        validators: {
          "MySuperValidator": {
            type: "usr.DGValidator",
            params: {
              minValue: 50,
              message: "#ResourceString(PriceCannotBeLess)#"
            }
          }
        }
      },
      "PDS_UsrArea_glmjgg6": {
        modelConfig: { path: "PDS.UsrArea" },
        validators: {
          "MySuperValidator": {
            type: "usr.DGValidator",
            params: {
              minValue: 100,
              message: "#ResourceString(AreaCannotBeLess)#"
            }
          }
        }
      }
    }
  }
};
```

### 2.3. Ресурсные строки
Добавьте строки в `localizableStrings` схемы:

```js
localizableStrings: {
  PriceCannotBeLess: "Price cannot be less than 50",
  AreaCannotBeLess: "Area cannot be less than 100"
}
```

---

## 3) Включение/выключение client debug (`IsDebug`)

Creatio позволяет включить режим отладки клиентского кода через персональную системную настройку **IsDebug**. После переключения обновите страницу.

**Включить:**
```js
Terrasoft.SysSettings.postPersonalSysSettingsValue("IsDebug", true);
```

**Выключить:**
```js
Terrasoft.SysSettings.postPersonalSysSettingsValue("IsDebug", false);
```

> Примечание: debug‑режим влияет на производительность и скорость загрузки страниц, используйте его только на время диагностики.

---

## 4) Серверные логи: `nlog.config` и `nlog.targets.config`

Creatio (on‑site) использует NLog. Обычно конфиги лежат в папке:
- `..\Terrasoft.WebApp\nlog.config`
- `..\Terrasoft.WebApp\nlog.targets.config`

Путь к `nlog.config` задаётся в `..\Terrasoft.WebApp\Web.config`.

### Рекомендованный подход
- **Targets** (куда писать) держите в `nlog.targets.config` (файлы/бд/и т. п.).
- **Rules/levels** (что и на каком уровне писать) — в `nlog.config`.
- Включайте подробные уровни (Debug/Trace) **только временно** на тесте/при расследовании.

Мини‑пример:

```xml
<!-- nlog.targets.config -->
<targets>
  <target xsi:type="File"
          name="file"
          fileName="${basedir}/Logs/app.log"
          layout="${longdate}|${level}|${logger}|${message}${exception:format=ToString}" />
</targets>
```

```xml
<!-- nlog.config -->
<rules>
  <logger name="*" minlevel="Info" writeTo="file" />
  <!-- временно на расследование -->
  <!-- <logger name="Terrasoft.*" minlevel="Debug" writeTo="file" /> -->
</rules>
```
