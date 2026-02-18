# Clio в Docker: экспорт приложения из dev1 → импорт в dev2

Этот README описывает **воспроизводимый flow** для работы с **Creatio Clio** внутри Docker-контейнера (как будто вы работаете не из Windows),
чтобы:

1) один раз собрать образ с `clio`
2) зарегистрировать два Creatio-инстанса (`dev1`, `dev2`)
3) проверить регистрацию и доступность
4) **выгрузить приложение** (например `Yachts`) в `.zip` из `dev1`
5) **установить** это `.zip` в `dev2`

---

## Структура

Папка: `tools/clio-docker/`

Структура:

```text
tools/
  clio-docker/
    Dockerfile
    docker-compose.yml
    volumes/
      home/   # конфигурация clio (регистрация окружений)
      out/    # экспортированные zip и логи установки
```
> Чтобы обращаться к сервисам, проброшенным на хост, используйте `host.docker.internal`.

---

## docker-compose.yml

Файл: `tools/clio-docker/docker-compose.yml`

```yaml
services:
  clio:
    build:
      context: .
      dockerfile: Dockerfile
    image: creatio-clio:local
    working_dir: /work
    volumes:
      # Clio сохраняет конфиг (appsettings.json) сюда:
      - ./volumes/home:/root/creatio/clio
      # Сюда складываем артефакты (zip, логи):
      - ./volumes/out:/work/out
```

---

## Dockerfile

Файл: `tools/clio-docker/Dockerfile`

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0

RUN dotnet tool install -g clio \
 && ln -s /root/.dotnet/tools/clio /usr/local/bin/clio

WORKDIR /work
ENTRYPOINT ["clio"]
CMD ["-h"]
```

---

# Подготовка папок volumes

Из корня репозитория (PowerShell / CMD):

```text
mkdir tools\clio-docker\volumes\home
mkdir tools\clio-docker\volumes\out
```

---

## 1) Собрать образ Clio один раз

```text
docker compose -p creatio-clio -f tools/clio-docker/docker-compose.yml build
```

---

## 2) Проверить версию Clio

```text
docker compose -f tools/clio-docker/docker-compose.yml run --rm clio ver
```

---
## 3) Зарегистрировать окружения dev1/dev2

### dev1 (пример: Creatio доступен на `http://localhost:5000`)

```text
docker compose -f tools/clio-docker/docker-compose.yml run --rm clio reg-web-app dev1 -u http://host.docker.internal:5000 -l Supervisor -p Supervisor
```

### dev2 (пример: Creatio доступен на `http://localhost:5100`)

```text
docker compose -f tools/clio-docker/docker-compose.yml run --rm clio reg-web-app dev2 -u http://host.docker.internal:5100 -l Supervisor -p Supervisor
```

---

## 4) Проверить список зарегистрированных окружений

```text
docker compose -f tools/clio-docker/docker-compose.yml run --rm clio show-web-app-list
```

---

## 5) Посмотреть установленные приложения (Application Hub / Installed applications)

> Эта команда показывает **список установленных приложений** в выбранном окружении.  
> Обязательно указывайте `-e dev1` / `-e dev2`.

```text
docker compose -f tools/clio-docker/docker-compose.yml run --rm clio apps -e dev1
docker compose -f tools/clio-docker/docker-compose.yml run --rm clio apps -e dev2
```

---

## 6) Экспорт приложения из dev1 в zip

Пример: приложение называется **`Yachts`**.

```text
docker compose -f tools/clio-docker/docker-compose.yml run --rm clio download-application Yachts -e dev1 -f /work/out/Yachts.zip
```

Результат на хосте:

```text
tools/clio-docker/volumes/out/Yachts.zip
```

---

## 7) Установка zip в dev2

```text
docker compose -f tools/clio-docker/docker-compose.yml run --rm clio install-application /work/out/Yachts.zip -e dev2 -r /work/out/install_dev2.log
```

Лог установки на хосте:

```text
tools/clio-docker/volumes/out/install_dev2.log
```

---


## Готовый сценарий (всё по порядку)

```text
docker compose -p creatio-clio -f tools/clio-docker/docker-compose.yml build
docker compose -f tools/clio-docker/docker-compose.yml run --rm clio ver

docker compose -f tools/clio-docker/docker-compose.yml run --rm clio reg-web-app dev1 -u http://host.docker.internal:5000 -l Supervisor -p Supervisor
docker compose -f tools/clio-docker/docker-compose.yml run --rm clio reg-web-app dev2 -u http://host.docker.internal:5100 -l Supervisor -p Supervisor

docker compose -f tools/clio-docker/docker-compose.yml run --rm clio show-web-app-list

docker compose -f tools/clio-docker/docker-compose.yml run --rm clio apps -e dev1
docker compose -f tools/clio-docker/docker-compose.yml run --rm clio apps -e dev2

docker compose -f tools/clio-docker/docker-compose.yml run --rm clio download-application Yachts -e dev1 -f /work/out/Yachts.zip
docker compose -f tools/clio-docker/docker-compose.yml run --rm clio install-application /work/out/Yachts.zip -e dev2 -r /work/out/install_dev2.log
```
