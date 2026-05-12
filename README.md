# COLMAP Workshop: sparse reconstruction из видео в Docker

Практический воркшоп: COLMAP в Docker, **разрежённая 3D-реконструкция** (*sparse reconstruction*) из видео через CLI (без GUI COLMAP). Подробные шаги — в каталоге [`docs/`](docs/).

**Навигация:** [цель](#цель-воркшопа) · [требования](#требования-к-данным) · [структура](#структура-репозитория) · [быстрый старт](#быстрый-старт) · [маршрут](#основной-маршрут-воркшопа) · [документация](#документация-по-шагам) · [шпаргалка](#команды-в-контейнере-шпаргалка) · [проблемы](#типичные-проблемы)

---

## Цель воркшопа

1. Извлечение кадров из видео (FFmpeg).
2. Извлечение признаков SIFT в COLMAP.
3. Поиск соответствий между кадрами.
4. Sparse reconstruction (`mapper`).
5. Экспорт в текстовые форматы и PLY.
6. Разбор основных артефактов COLMAP.

В конце участник получает:

- кадры `frame_001.jpg`, `frame_002.jpg`, …;
- базу `database.db`;
- разрежённую модель COLMAP (часто `sparse/0/`);
- текстовый экспорт и `model.ply`;
- понимание ролей `cameras`, `images`, `points3D` и дальнейших шагов.

---

## Формат воркшопа

- запуск **локально** у каждого участника;
- все шаги в **терминале (CLI)**;
- окружение в **Docker**;
- вычисления на **CPU**;
- графический интерфейс COLMAP **не используется**.

Единый сценарий рассчитан на **Linux (Ubuntu)**, **macOS (Apple Silicon)** и **Windows** (Docker Desktop + WSL2/Ubuntu).

---

## Что используется

| Компонент | Роль |
|-----------|------|
| **FFmpeg** | извлечение кадров из видео |
| **COLMAP** | признаки, matching, `mapper`, экспорт (в материалах ориентир на **3.9**; скрипты предупреждают, если версия по `colmap help` другая) |
| **Docker / Compose** | одно и то же окружение у всех |
| **Python 3** | опциональные задания и утилиты |

---

## Требования к данным

- вход: **MP4 (H.264)**;
- сцена в основном **статична**;
- эталонное видео **`sample.mp4`** уже в репозитории; при желании — своё видео в формате, который читает FFmpeg.

**Рекомендации к съёмке / ролику:** достаточно текстуры и деталей, **overlap** между соседними кадрами, смена **точки обзора** (не только «чистое» вращение на месте), без сильного размытия и крупных движущихся объектов.

**На воркшопе по умолчанию:** порядка **100–110** кадров (`fps=3/4` для `sample.mp4`), разрешение **960×540**, имена `frame_001.jpg`, …

---

## Структура репозитория

Корень проекта монтируется в контейнер как **`/workspace`** (см. [`compose.yaml`](compose.yaml)). На диске у вас те же файлы, что и под `/workspace/...` внутри контейнера.

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

**A.** Импорт из архива:

```bash
docker image load -i colmap-workshop-image.tar
docker images
```

**B.** Сборка из репозитория:

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

Скрипт проверяет наличие **`colmap`**, **`ffmpeg`**, **`python3`**, **`sqlite3`**, входного видео, каталогов данных и возможность записи в `workspace`. Справка: `bash scripts/smoke_test.sh --help`.

---

## Основной маршрут воркшопа

| Этап | Действие | Результат |
|------|----------|-----------|
| **0** | Подготовка Docker, вход в контейнер, `smoke_test.sh` | доступны `colmap`, `ffmpeg`, `python3`, `sqlite3` и каталоги данных |
| **1** | Кадры из видео | `data/images/frame_*.jpg` |
| **2** | `feature_extractor` | создаётся `database.db` |
| **3** | `exhaustive_matcher` | соответствия в базе |
| **4** | `mapper` | `data/workspace/sparse/0/` (или другой индекс) |
| **5** | Экспорт | `data/workspace/text/`, `data/workspace/ply/model.ply` |
| **6** | Разбор артефактов | понимание базы и текстовых файлов |

Целиком пайплайн COLMAP из скриптов: `bash scripts/run_colmap_sparse.sh all` (см. [03](docs/03_colmap_features_matching.md)).

---

## Документация по шагам

| Файл | Содержание |
|------|------------|
| [docs/01_setup.md](docs/01_setup.md) | Docker, первый запуск, smoke test |
| [docs/02_ffmpeg_frames.md](docs/02_ffmpeg_frames.md) | кадры из видео, `extract_frames.sh` |
| [docs/03_colmap_features_matching.md](docs/03_colmap_features_matching.md) | признаки и matching, `run_colmap_sparse.sh` |
| [docs/04_colmap_mapping.md](docs/04_colmap_mapping.md) | `mapper`, sparse-модель |
| [docs/05_export_and_inspect.md](docs/05_export_and_inspect.md) | экспорт TXT/PLY, `database.db`, `export_model.sh`, `inspect_sqlite.sh` |
| [docs/06_troubleshooting.md](docs/06_troubleshooting.md) | типичные сбои и диагностика |
| [docs/07_next_steps.md](docs/07_next_steps.md) | dense, mesh, идеи развития |

**Скрипты и документы**

| Скрипт | Документы |
|--------|-----------|
| `scripts/smoke_test.sh` | [01_setup.md](docs/01_setup.md) |
| `scripts/extract_frames.sh` | [02_ffmpeg_frames.md](docs/02_ffmpeg_frames.md) |
| `scripts/run_colmap_sparse.sh` | [03](docs/03_colmap_features_matching.md), [04](docs/04_colmap_mapping.md) |
| `scripts/export_model.sh`, `scripts/inspect_sqlite.sh` | [05_export_and_inspect.md](docs/05_export_and_inspect.md) |

У всех сценариев в `scripts/` есть **`--help`** и **`-h`**. У перечисленных в таблице — ещё **`--version`** и **`-v`**. Полный список опций смотрите в выводе **`bash scripts/<имя>.sh --help`** и в соответствующих файлах `docs/`.

---

## Команды в контейнере: шпаргалка

Ниже пути вида **`/workspace/data/...`** — внутри контейнера (запускайте команды из каталога **`/workspace`**). Детали и опции скриптов — в соответствующих файлах `docs/`.

Признаки, matching и `mapper` можно выполнять через **`bash scripts/run_colmap_sparse.sh`** по режимам `features`, `matching`, `mapping` или сразу **`all`** — см. [03](docs/03_colmap_features_matching.md) и [04](docs/04_colmap_mapping.md).

### 1. Кадры

```bash
ffmpeg -y -i /workspace/data/video/sample.mp4 \
  -vf "fps=3/4,scale=960:540" \
  -q:v 2 \
  -start_number 1 \
  /workspace/data/images/frame_%03d.jpg
```

Эквивалент: `bash scripts/extract_frames.sh` ([02](docs/02_ffmpeg_frames.md)).

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

Те же ключи, что в [`run_colmap_sparse.sh`](scripts/run_colmap_sparse.sh) в режиме **`features`**.

### 3. Matching

```bash
colmap exhaustive_matcher \
  --database_path /workspace/data/workspace/database.db \
  --SiftMatching.guided_matching 1 \
  --SiftMatching.use_gpu 0
```

### 4. Sparse reconstruction

```bash
mkdir -p /workspace/data/workspace/sparse

colmap mapper \
  --database_path /workspace/data/workspace/database.db \
  --image_path /workspace/data/images \
  --output_path /workspace/data/workspace/sparse
```

### 5–6. Экспорт TXT и PLY

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

Оба экспорта одной командой: **`bash scripts/export_model.sh`** ([05](docs/05_export_and_inspect.md)). База **`database.db`**: **`bash scripts/inspect_sqlite.sh`**.

---

## Что должно получиться

После успешного прохождения шагов:

| Расположение | Содержимое |
|--------------|------------|
| `data/images/` | `frame_001.jpg`, … |
| `data/workspace/` | `database.db`, `sparse/0/…`, `text/…`, `ply/model.ply`, `logs/…` |

Проверка: `model.ply` в просмотрщике; `cameras.txt`, `images.txt`, `points3D.txt` — смысл полей в [05](docs/05_export_and_inspect.md).

---

## Опционально: похожие кадры

Задание на Python: чтение кадров из `data/images/`, уменьшение размера, grayscale, попарная метрика (например, **SSIM**), поиск слишком похожих пар. Реализация — в `scripts/` или отдельном каталоге в контейнере.

---

## Что не входит в обязательную часть

Подробно не разбираются: dense reconstruction, mesh, текстурирование, GUI COLMAP, локализация новых кадров, робототехника / SLAM / 3D Gaussian Splatting. Идеи продолжения — в [07_next_steps.md](docs/07_next_steps.md).

---

## Типичные проблемы

Частые причины плохой реконструкции: малый **overlap**, почти дубликаты кадров, смаз, мало текстуры, движущиеся объекты, неудачное исходное видео.

Пошаговая диагностика: [docs/06_troubleshooting.md](docs/06_troubleshooting.md).

---

## Замечания к платформе

- **Linux (Ubuntu):** основной сценарий Docker / Compose.
- **macOS (Apple Silicon):** Docker Desktop, сценарий на CPU.
- **Windows:** Docker Desktop + WSL2 + Ubuntu (рекомендуется).

---

## Следующие шаги

Dense reconstruction, meshing, анализ поз камер, свои пайплайны, NVS / Gaussian Splatting — см. [docs/07_next_steps.md](docs/07_next_steps.md).
