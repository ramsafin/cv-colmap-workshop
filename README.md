# COLMAP Workshop: sparse reconstruction из видео в Docker

Практическое занятие по запуску **COLMAP** в **Docker** и построению **разрежённой 3D-реконструкции** сцены из видео (*sparse 3D reconstruction*) **в командной строке** (без графического интерфейса COLMAP). Подробные шаги — в каталоге [`docs/`](docs/).

---

## Цель воркшопа

1. Извлечение кадров из видео с помощью **FFmpeg**.
2. Извлечение признаков **SIFT** в **COLMAP**.
3. Сопоставление кадров по признакам (*matching*).
4. Разрежённая реконструкция командой **`mapper`**.
5. Экспорт результатов в текстовые форматы и в **PLY**.
6. Разбор основных артефактов **COLMAP**.

По итогам участник получает:

- кадры `frame_001.jpg`, `frame_002.jpg`, …;
- базу данных `database.db`;
- разрежённую модель **COLMAP** (часто в каталоге `sparse/0/`);
- текстовый экспорт и файл `model.ply`;
- понимание назначения данных в `cameras`, `images`, `points3D` и возможных дальнейших шагов.

---

## Формат воркшопа

- работа **локально** на машине каждого участника;
- все действия — **в терминале** (интерфейс командной строки);
- окружение — в **Docker**;
- вычисления — **на CPU**;
- графический интерфейс **COLMAP** **не используется**.

**Ход занятия** одинаков для **Linux (Ubuntu)**, **macOS (Apple Silicon)** и **Windows** (Docker Desktop, **WSL2** и дистрибутив **Ubuntu** внутри WSL).

---

## Что используется

| Компонент | Назначение |
|-----------|------------|
| **FFmpeg** | извлечение кадров из видео |
| **COLMAP** | признаки, сопоставление (*matching*), **`mapper`**, экспорт |
| **Docker / Compose** | одинаковое окружение у всех участников |
| **Python 3** | дополнительные задания и вспомогательные скрипты |

---

## Требования к данным

- на входе — **MP4 (H.264)**;
- сцена по возможности статична относительно камеры;
- эталонное видео **`sample.mp4`** уже лежит в репозитории; при желании можно подставить **свой** ролик в формате, который поддерживает **FFmpeg**.

**Рекомендации к съёмке и выбору ролика:** в кадре должно быть достаточно **текстуры и мелких деталей**; между соседними кадрами нужно **перекрытие** сцены (*overlap*); камера должна **менять точку съёмки**, а не только вращаться «на месте»; избегайте сильного **размытия**, пересветов и крупных **движущихся объектов** в кадре.

**Параметры по умолчанию на занятии:** порядка **100–110** кадров (для `sample.mp4` задаётся `fps=3/4`), разрешение **960×540**, имена файлов `frame_001.jpg`, …

---

## Структура репозитория

Корень проекта при запуске контейнера монтируется как **`/workspace`** (см. [`compose.yaml`](compose.yaml)). Файлы в папке проекта на диске и пути вида **`/workspace/...`** внутри контейнера — это **одни и те же** данные.

```text
cv-colmap-workshop/
├─ README.md
├─ compose.yaml
├─ docker/
│  ├─ Dockerfile
│  └─ entrypoint.sh
├─ docs/
│  ├─ 01_setup.md … 07_next_steps.md
├─ scripts/
│  ├─ smoke_test.sh
│  ├─ extract_frames.sh
│  ├─ run_colmap_sparse.sh
│  ├─ export_model.sh
│  └─ inspect_sqlite.sh
└─ data/
   ├─ video/sample.mp4
   ├─ images/
   └─ workspace/   # database.db, sparse/, text/, ply/, logs/
```

---

## Быстрый старт

### Образ

**А.** Импорт из архива:

```bash
docker image load -i colmap-workshop-image.tar
docker images
```

**Б.** Сборка из репозитория:

```bash
docker compose build
```

### Контейнер

```bash
docker compose run --rm workshop bash
```

Рабочий каталог внутри контейнера: **`/workspace`**.

### Проверка окружения

```bash
bash scripts/smoke_test.sh
```

Скрипт проверяет, что в системе есть **`colmap`**, **`ffmpeg`**, **`python3`**, **`sqlite3`**, что на месте входное видео и каталоги данных, и что в рабочую область можно **записывать** файлы. Справка по вызову: `bash scripts/smoke_test.sh --help`.

---

## Основной маршрут воркшопа

| Этап | Действие | Результат |
|------|----------|-----------|
| **0** | Подготовка **Docker**, вход в контейнер, скрипт **`smoke_test.sh`** | доступны `colmap`, `ffmpeg`, `python3`, `sqlite3` и каталоги данных |
| **1** | Извлечение кадров из видео | файлы `data/images/frame_*.jpg` |
| **2** | **`feature_extractor`** | создаётся `database.db` |
| **3** | **`exhaustive_matcher`** | в базе появляются соответствия между кадрами |
| **4** | **`mapper`** | каталог `data/workspace/sparse/0/` (или другой номер модели) |
| **5** | Экспорт модели | каталоги `data/workspace/text/` и файл `data/workspace/ply/model.ply` |
| **6** | Разбор артефактов | понимание устройства базы и текстовых выгрузок |

Запустить **весь** пайплайн **COLMAP** одним скриптом: `bash scripts/run_colmap_sparse.sh all` (подробности — в [документе 03](docs/03_colmap_features_matching.md)).

---

## Документация по шагам

| Файл | Содержание |
|------|------------|
| [docs/01_setup.md](docs/01_setup.md) | **Docker**, первый запуск, проверка окружения (*smoke test*) |
| [docs/02_ffmpeg_frames.md](docs/02_ffmpeg_frames.md) | кадры из видео, скрипт `extract_frames.sh` |
| [docs/03_colmap_features_matching.md](docs/03_colmap_features_matching.md) | признаки и сопоставление, скрипт `run_colmap_sparse.sh` |
| [docs/04_colmap_mapping.md](docs/04_colmap_mapping.md) | **`mapper`**, разрежённая модель |
| [docs/05_export_and_inspect.md](docs/05_export_and_inspect.md) | экспорт в **TXT**/**PLY**, база `database.db`, скрипты `export_model.sh` и `inspect_sqlite.sh` |
| [docs/06_troubleshooting.md](docs/06_troubleshooting.md) | типичные сбои и диагностика |
| [docs/07_next_steps.md](docs/07_next_steps.md) | плотная реконструкция, сетки, идеи для самостоятельной работы |

**Соответствие скриптов и документов**

| Скрипт | Документы |
|----------|-----------|
| `scripts/smoke_test.sh` | [01_setup.md](docs/01_setup.md) |
| `scripts/extract_frames.sh` | [02_ffmpeg_frames.md](docs/02_ffmpeg_frames.md) |
| `scripts/run_colmap_sparse.sh` | [03](docs/03_colmap_features_matching.md), [04](docs/04_colmap_mapping.md) |
| `scripts/export_model.sh`, `scripts/inspect_sqlite.sh` | [05_export_and_inspect.md](docs/05_export_and_inspect.md) |

У всех скриптов в каталоге `scripts/` предусмотрены опции **`--help`** и **`-h`**. Для скриптов из таблицы выше доступны также **`--version`** и **`-v`**. Полный перечень параметров смотрите в выводе команды **`bash scripts/<имя>.sh --help`** и в соответствующих файлах в **`docs/`**.

---

## Команды в контейнере: шпаргалка

Ниже — примеры команд с путями вида **`/workspace/data/...`**. Их нужно выполнять **из каталога `/workspace`** внутри контейнера. Пояснения к скриптам и ручным командам — в соответствующих разделах **`docs/`**.

Извлечение признаков, сопоставление и **`mapper`** можно выполнять через **`bash scripts/run_colmap_sparse.sh`** в режимах `features`, `matching`, `mapping` либо одной командой **`all`** — см. [03](docs/03_colmap_features_matching.md) и [04](docs/04_colmap_mapping.md).

### 1. Кадры

```bash
ffmpeg -y -i /workspace/data/video/sample.mp4 \
  -vf "fps=3/4,scale=960:540" \
  -q:v 2 \
  -start_number 1 \
  /workspace/data/images/frame_%03d.jpg
```

То же действие: `bash scripts/extract_frames.sh` (см. [02](docs/02_ffmpeg_frames.md)).

### 2. Признаки

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

Те же параметры, что задаёт [`run_colmap_sparse.sh`](scripts/run_colmap_sparse.sh) в режиме **`features`**.

### 3. Сопоставление (*matching*)

```bash
colmap exhaustive_matcher \
  --database_path /workspace/data/workspace/database.db \
  --SiftMatching.guided_matching 1 \
  --SiftMatching.use_gpu 0
```

### 4. Разрежённая реконструкция

```bash
mkdir -p /workspace/data/workspace/sparse

colmap mapper \
  --database_path /workspace/data/workspace/database.db \
  --image_path /workspace/data/images \
  --output_path /workspace/data/workspace/sparse
```

### 5–6. Экспорт в TXT и PLY

```bash
mkdir -p /workspace/data/workspace/text /workspace/data/workspace/ply

colmap model_converter \
  --input_path /workspace/data/workspace/sparse/0 \
  --output_path /workspace/data/workspace/text \
  --output_type TXT

colmap model_converter \
  --input_path /workspace/data/workspace/sparse/0 \
  --output_path /workspace/data/workspace/ply/model.ply \
  --output_type PLY
```

Оба экспорта подряд можно выполнить скриптом **`bash scripts/export_model.sh`** (см. [05](docs/05_export_and_inspect.md)). Для просмотра таблиц в **`database.db`** служит **`bash scripts/inspect_sqlite.sh`**.

---

## Что должно получиться

После успешного выполнения всех шагов:

| Расположение | Содержимое |
|--------------|------------|
| `data/images/` | `frame_001.jpg`, … |
| `data/workspace/` | `database.db`, `sparse/0/…`, `text/…`, `ply/model.ply`, `logs/…` |

Имеет смысл открыть `model.ply` в программе просмотра облаков точек; структуру и смысл полей в `cameras.txt`, `images.txt`, `points3D.txt` разбирают в [05](docs/05_export_and_inspect.md).

---

## Дополнительно: похожие кадры

Необязательное задание на **Python**: прочитать кадры из `data/images/`, уменьшить разрешение, перевести в оттенки серого, оценить попарную схожесть (например, метрикой **SSIM**) и найти слишком похожие пары кадров. Код можно разместить в `scripts/` или в отдельной папке внутри контейнера.

---

## Что не входит в обязательную часть

В рамках основного занятия **подробно не рассматриваются**: плотная реконструкция (*dense reconstruction*), построение сетки (*mesh*), текстурирование, графический интерфейс **COLMAP**, локализация новых кадров, связка с робототехникой, **SLAM** и **3D Gaussian Splatting**. Куда двигаться дальше — в [07_next_steps.md](docs/07_next_steps.md).

---

## Типичные проблемы

Частые причины неудачной реконструкции: **слишком малое перекрытие** кадров (*overlap*), почти **дубликаты** кадров, **смаз**, **мало текстуры** на объектах, **движущиеся объекты** в кадре, неудачно выбранное исходное видео.

Пошаговая диагностика — в [docs/06_troubleshooting.md](docs/06_troubleshooting.md).

---

## Замечания к платформе

- **Linux (Ubuntu):** типовой вариант — **Docker** и **Docker Compose**.
- **macOS (Apple Silicon):** **Docker Desktop**, вычисления на **CPU**.
- **Windows:** **Docker Desktop**, **WSL2** и **Ubuntu** внутри подсистемы (такой вариант рекомендуется).

---

## Следующие шаги

Плотная реконструкция, построение сетки, анализ **положений камер**, собственные конвейеры обработки, синтез видов (**NVS**) и **Gaussian Splatting** — см. [docs/07_next_steps.md](docs/07_next_steps.md).
. 