# coursework-stand

Практичний стенд для курсової роботи  
"Моделі загроз і аналіз ризиків при зберіганні та використанні секретів у DevOps-процесах."

## Призначення

Цей репозиторій відтворює локальний стенд:

- kind (локальний Kubernetes cluster),
- HashiCorp Vault (секрети + auth),
- PostgreSQL (цільовий сервіс для dynamic credentials),
- сценарії:
  - `01-static-secret-leak` (антипатерн зі статичними секретами),
  - `02-dynamic-short-lived` (короткоживучі динамічні секрети через Vault).

## Структура

```text
kind/                 # конфігурація kind cluster
helm/                 # values для Helm chart'ів
vault/                # політики та bootstrap-скрипти Vault
scenarios/            # сценарії відтворення
capture/              # скріншоти та логи запусків
scripts/              # up/down/smoke helpers
```

## Передумови

- Docker Desktop (running)
- `kubectl`, `helm`, `kind`, `vault`, `python`
- Git Bash (для запуску `.sh` скриптів на Windows)

## Швидкий старт

```bash
bash scripts/up.sh
bash scripts/smoke-test.sh
bash scenarios/01-static-secret-leak/reproduce.sh
bash scenarios/02-dynamic-short-lived/reproduce.sh
bash scripts/down.sh
```


