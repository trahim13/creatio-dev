## Подготовка

1) Скачать Latest Creatio Studio PostgreSQL for Linux:

```text
https://creatiocom-my.sharepoint.com/:f:/g/personal/d_gamora_creatio_com/EjQ6znaqkLNGpPo9mK6qDYgBLTxjfr6YdHpSLa50QZFNvA
```

2) Разместить в корне проекта:

```text
creatio-instruction
```

![img.png](img.png)

3) Распаковать архив 8.3.2.4199_StudioNet8_Softkey_PostgreSQL_ENU.zip в папку creatio
   ![img_2.png](img_2.png)

4) creatio/db - забрать файл BPMonline832StudioNet8.backup и положить его в корень проекта
   ![img_3.png](img_3.png)

## Настройка PG+INIT SCHEMA

1. docker compose up -d postgres
2. Проверить: контейнер жив и Postgres доступен:

```text
docker exec -it postgres17-creatio-dev1 psql -U app -d postgres -c "select version();"
``` 

3. backup-файл внутрь контейнера:

```text
docker cp .\BPMonline832StudioNet8.backup postgres17-creatio-dev1:/tmp/BPMonline832StudioNet8.backup
```

или WSL

```text
docker cp c/ai-demo/creatio-instruction/BPMonline832StudioNet8.backup postgres17-creatio-dev1:/tmp/BPMonline832StudioNet8.backup
```

4. Проверим, что все ОК:
   linux: docker exec -it postgres17-creatio-dev1 pg_restore --list /tmp/BPMonline832StudioNet8.backup | head -n 20
   cmd: docker exec -it postgres17-creatio-dev1 pg_restore --list /tmp/BPMonline832StudioNet8.backup | more

5. БД уже создана при docker-compose: app

6. Восстановить дамп в базу через pg_restore

```text
docker exec -it postgres17-creatio-dev1 pg_restore \
  -U app \
  -d app \
  --no-owner \
  --no-privileges \
  /tmp/BPMonline832StudioNet8.backup

```

7. Проверить, что восстановилось

```text
docker exec -it postgres17-creatio-dev1 psql -U app -d app -c "\dt" | head
docker exec -it postgres17-creatio-dev1 psql -U app -d app -c "select count(*) from pg_class where relkind='r';"

```

8. Выполняем скрипт (в инструкции так написано)

```text
docker cp .\casts.sql postgres17-creatio-dev1:/tmp/casts.sql
```

docker cp .\casts.sql postgres17-creatio-dev1:/tmp/casts.sql

docker exec -it postgres17-creatio-dev1 psql -U app -d app -v ON_ERROR_STOP=1 -f /tmp/casts.sql

Проверка:
docker exec -it postgres17-creatio-dev1 psql -U app -d app -c "
SELECT c.oid
FROM pg_cast c
JOIN pg_type s ON s.oid = c.castsource
JOIN pg_type t ON t.oid = c.casttarget
WHERE s.typname = 'text' AND t.typname = 'uuid';
"

## Настроить север приложения:

1. Заменить creatio/Dockerfile на следующий

```text
ARG NetCoreVersion=8.0
ARG AspEnvironment=Development

FROM mcr.microsoft.com/dotnet/sdk:${NetCoreVersion}

ENV ASPNETCORE_ENVIRONMENT=${AspEnvironment} \
    TZ=Europe/Kiev

RUN apt-get update && \
    apt-get -y --no-install-recommends install \
      libgdiplus \
      libc6-dev \
      gss-ntlmssp && \
    apt-get clean all && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* && \
    sed -i 's/openssl_conf/#openssl_conf/g' /etc/ssl/openssl.cnf

WORKDIR /app
COPY . ./

EXPOSE 5000 5002
ENTRYPOINT ["dotnet", "Terrasoft.WebHost.dll"]

```

2. Настроить сервис приложений перед запуском creatio/ConnectionStrings.config, содержимое заменить на

```text
<?xml version="1.0" encoding="utf-8"?>
<connectionStrings>
  <add name="db"
       connectionString="Server=postgres17-creatio-dev1;Port=5432;Database=app;User ID=app;Password=app;Timeout=500;CommandTimeout=400;MaxPoolSize=1024;" />

  <add name="dbPostgreSql"
       connectionString="Pooling=true;Database=app;Host=postgres17-creatio-dev1;Port=5432;Username=app;Password=app;Timeout=500;CommandTimeout=400" />

  <add name="redis"
         connectionString="host=redis7-creatio;db=1;port=6379" />

  <add name="dbMssqlCore" connectionString="Data Source=tscore-ms-01\mssql2008; Initial Catalog=BPMonlineCore; Persist Security Info=True; MultipleActiveResultSets=True; Integrated Security=SSPI; Pooling = true; Max Pool Size = 100; Async = true" />
  <add name="dbMssqlUnitTest" connectionString="Data Source=TSAppHost-02; Initial Catalog=BPMonlineUnitTest; Persist Security Info=True; MultipleActiveResultSets=True; User ID=UnitTest; Password=UnitTest; Async = true" />

  <add name="tempDirectoryPath" connectionString="/tmp/creatio" />

  <add name="consumerInfoServiceUri" connectionString="http://sso.bpmonline.com:4566/ConsumerInfoService.svc" />
  <add name="consumerInfoServiceAccessInfoPageUri" connectionString="http://sso.bpmonline.com:4566/AccessInfoPage.aspx" />
  <add name="logstashConfigFolderPath" connectionString="%TEMP%\%APPLICATION%\LogstashConfig" />
  <add name="elasticsearchCredentials" connectionString="User=gs-es; Password=DEQpJMfKqUVTWg9wYVgi;" />
  <add name="influx" connectionString="url=http://10.0.7.161:30359; user=; password=; batchIntervalMs=5000" />
  <add name="clientPerformanceLoggerServiceUri" connectionString="http://tsbuild-k8s-m1:30001/" />
  <add name="messageBroker" connectionString="amqp://guest:guest@localhost/BPMonlineSolution" />
</connectionStrings>
```

3. creatio/Terrasoft.WebHost.dll.config изменить значение CookiesSameSiteMode на Lax

```text
   <add key="CookiesSameSiteMode" value="Lax" />
```

## Запуск:

Собрать всю эту штуку без кеша:

docker compose build --no-cache creatio
docker compose up -d
docker logs -f creatio83

Иногда встречаются проблемы с кэшем:
docker compose down
docker compose build --no-cache --pull creatio
docker compose up -d --force-recreate creatio
docker logs -f creatio83


## Открыть http://localhost:5000/
Login: Supervisor; password: Supervisor.

## Похлопать себя по плечу=)

## Полезное
Выключить приложения и снести их вольмы
docker compose down -v --remove-orphans

Логи у нас доступны тут, чтобы каждый раз не ходить в контейнер:
creatio/Logs