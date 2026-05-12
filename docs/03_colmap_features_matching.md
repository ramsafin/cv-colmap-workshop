# 03. COLMAP: извлечение признаков и сопоставление изображений

Здесь из подготовленных **снимков** (кадров из видео) строится **база данных COLMAP** с **признаками** на каждом изображении и **парами сопоставлений** между изображениями. Это нужно перед шагом **разрежённой 3D-реконструкции** (*sparse reconstruction*).

**Где выполнять команды:** внутри контейнера, каталог `/workspace` (см. [01. Подготовка окружения](01_setup.md)); снимки должны быть уже в `/workspace/data/images` по [02_ffmpeg_frames.md](02_ffmpeg_frames.md).

## Как пользоваться этим файлом

1. Убедитесь, что в `/workspace/data/images` есть файлы `frame_*.jpg`.
2. Прочитайте блок **«Почему такая схема»** — чтобы понимать выбор программ и режима сопоставления.
3. Запустите **`run_colmap_sparse.sh`** в нужном режиме (часто по отдельности: сначала признаки, потом сопоставление). Список режимов и флагов: **`bash scripts/run_colmap_sparse.sh --help`**.
4. Проверьте **`database.db`** и **логи**; затем переходите к [04_colmap_mapping.md](04_colmap_mapping.md).

На этом этапе в командной строке (интерфейс **CLI**, без графического окна COLMAP) выполняются две стандартные команды:

1. **`feature_extractor`** — извлечение **локальных признаков** (в воркшопе используются дескрипторы **SIFT**);
2. **`exhaustive_matcher`** — **полный перебор пар** изображений и поиск соответствий признаков между каждой парой.

## Цель этапа

После успешного прохода вы должны получить:

- файл **`database.db`** (база **SQLite** — один файл с таблицами признаков и сопоставлений);
- признаки для всех (или почти всех) снимков;
- записи о **соответствиях** между изображениями внутри той же базы;
- готовность к следующему шагу — запуску **`mapper`** (восстановление геометрии сцены).

---

## Почему выбрана именно такая схема

Для занятия взят простой и наглядный маршрут:

- одна **камера** (все снимки с одного видео);
- модель камеры **`SIMPLE_RADIAL`** (простая модель с искажением; не нужно вручную задавать полную калибровку);
- сопоставление через **`exhaustive_matcher`** — понятно учебно: «каждая пара кадров».

Так проще объяснять цепочку шагов при **небольшом** числе кадров (~110). На больших наборах с **видео** в реальных проектах чаще используют **`sequential_matcher`** (соседние кадры); в нашем скрипте он **не** включён — только отдельная ручная команда, см. [06_troubleshooting.md](06_troubleshooting.md).

---

## Входные данные

После шага с FFmpeg должна существовать папка:

```text
/workspace/data/images
```

и в ней снимки, например:

```text
frame_001.jpg
frame_002.jpg
frame_003.jpg
...
```

---

## Выходные данные

После **`feature_extractor`** появляется (или пересоздаётся) файл:

```text
/workspace/data/workspace/database.db
```

После **`exhaustive_matcher`**:

* в **тот же** файл `database.db` дописываются результаты **сопоставления** (*matching*);
* база готова для команды **`mapper`** (следующий документ).

---

## Запуск через скрипт `run_colmap_sparse.sh`

Сценарий: [`scripts/run_colmap_sparse.sh`](../scripts/run_colmap_sparse.sh). В начале комментария в файле указано: **ориентир — COLMAP 3.9** (такие же ключи должны подходить к соседним версиям 3.x; при отличии сверяйтесь с `colmap <command> -h`).

**Справка по режимам** (не требует снимков и не вызывает COLMAP):

```bash
bash scripts/run_colmap_sparse.sh --help
```

### Важно: пересоздание базы

При каждом запуске в режиме **`features`** скрипт **удаляет** существующий `database.db` и создаёт новый. Если нужно сохранить базу — **скопируйте файл** перед повторным `features`.

### Режим сопоставления в скрипте

Скрипт **всегда** вызывает **`exhaustive_matcher`**. Переход на **`sequential_matcher`** для ускорения на видео — только **вручную** (пример в [06_troubleshooting.md](06_troubleshooting.md)).

### Режимы скрипта

| Команда | Что выполняется |
|---------|------------------|
| `bash scripts/run_colmap_sparse.sh features` | только извлечение признаков (и новый `database.db`) |
| `bash scripts/run_colmap_sparse.sh matching` | только сопоставление (нужна уже заполненная база после `features`) |
| `bash scripts/run_colmap_sparse.sh mapping` | только `mapper` (см. [следующий файл](04_colmap_mapping.md)) |
| `bash scripts/run_colmap_sparse.sh all` | **всё подряд**: признаки → сопоставление → `mapper` |
| `bash scripts/run_colmap_sparse.sh -h` | только текст справки (режимы и переменные окружения) |

Если нужно остановиться **после сопоставления**, не используйте `all` — вызывайте `features` и `matching` отдельно.

```bash
bash scripts/run_colmap_sparse.sh features
```

```bash
bash scripts/run_colmap_sparse.sh matching
```

```bash
bash scripts/run_colmap_sparse.sh all
```

---

## Ручная команда: извлечение признаков

Эквивалент тому, что делает скрипт в режиме `features` (ограничения SIFT совпадают со скриптом — быстрее на **CPU**):

```bash
colmap feature_extractor \
  --database_path /workspace/data/workspace/database.db \
  --image_path /workspace/data/images \
  --ImageReader.camera_model SIMPLE_RADIAL \
  --ImageReader.single_camera 1 \
  --SiftExtraction.max_image_size 960 \
  --SiftExtraction.max_num_features 2048 \
  --SiftExtraction.use_gpu 0
```

### Что делает команда

* создаёт или перезаписывает базу **`database.db`**;
* читает снимки из **`/workspace/data/images`**;
* считает, что съёмка с **одной камеры**;
* извлекает **локальные признаки** (SIFT);
* **`--SiftExtraction.use_gpu 0`** — считать на **процессоре**, без видеокарты.

---

## Почему модель камеры `SIMPLE_RADIAL`

Удобная стартовая модель для одного видео и фиксированного разрешения: не нужно вручную вводить полную калибровку. Позже можно сравнить с **`PINHOLE`**.

---

## Ручная команда: полное сопоставление пар

```bash
colmap exhaustive_matcher \
  --database_path /workspace/data/workspace/database.db \
  --SiftMatching.guided_matching 1 \
  --SiftMatching.use_gpu 0
```

### Что делает команда

* перебирает **все пары** снимков;
* ищет **взаимные соответствия** признаков;
* записывает результат в **`database.db`**.

---

## Почему `exhaustive_matcher` в учебном сценарии

При ~110 кадрах полный перебор пар ещё допустим по времени и хорошо **иллюстрирует** идею сопоставления. Для длинных видео на практике чаще берут **`sequential_matcher`**; наш учебный скрипт намеренно оставляет **полный перебор**.

---

## Логи

Скрипт пишет журналы в:

```text
/workspace/data/workspace/logs
```

Ожидаемые имена файлов:

```text
feature_extractor.log
exhaustive_matcher.log
```

---

## Проверка после извлечения признаков

Файл базы создан и не пустой:

```bash
ls -lh /workspace/data/workspace/database.db
test -s /workspace/data/workspace/database.db && echo OK
```

Хвост журнала:

```bash
tail -n 20 /workspace/data/workspace/logs/feature_extractor.log
```

---

## Проверка после сопоставления

```bash
tail -n 20 /workspace/data/workspace/logs/exhaustive_matcher.log
```

Убедитесь, что в конце нет явной ошибки COLMAP.

---

## Критерии успеха

* есть **`database.db`** ненулевого размера;
* **`feature_extractor`** и **`exhaustive_matcher`** завершились без ошибки (по логам);
* можно переходить к **`mapper`**: [04_colmap_mapping.md](04_colmap_mapping.md).

---

## Возможные проблемы

### 1. `database.db` не создаётся

* есть ли папка **`/workspace/data/images`** и файлы **`frame_*.jpg`**;
* верны ли пути **`--image_path`** и **`--database_path`**;
* читайте **`feature_extractor.log`**.

### 2. Сопоставление завершается с ошибкой

* выполнен ли до этого **`features`**;
* существует ли непустая **`database.db`**;
* не удалялись ли снимки между шагами.

### 3. Снимки «не видны» COLMAP

```bash
ls /workspace/data/images | head
```

Если пусто — вернитесь к [02_ffmpeg_frames.md](02_ffmpeg_frames.md).

---

## Следующий шаг

[04_colmap_mapping.md)](04_colmap_mapping.md).
