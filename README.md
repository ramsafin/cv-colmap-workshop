# COLMAP Workshop: Sparse Reconstruction from Video in Docker

Практический воркшоп по запуску COLMAP в Docker и построению **sparse 3D reconstruction** из видео.

## Цель воркшопа

1. Извлечение кадров из видео при помощи FFmpeg;
2. Обнаружение признаков SIFT в COLMAP;
3. Поиск соответствий между кадрами;
4. Sparse reconstruction (`mapper`);
5. Экспорт результатов в текстовые форматы и PLY;
6. Разбор основных артефактов COLMAP.

В конце воркшопа студент должен получить:

- набор кадров `frame_001.jpg`, `frame_002.jpg`, ...;
- базу данных `database.db`;
- sparse-модель COLMAP;
- текстовый экспорт модели;
- PLY-файл point cloud;
- понимание того, что лежит в `cameras`, `images`, `points3D` и как это можно использовать дальше.

---

## Формат воркшопа

- запуск локально у каждого студента;
- все шаги выполняются **через CLI (командную строку, терминал)**;
- окружение запускается в **Docker**;
- вычисления выполняются **на CPU**;
- графический интерфейс COLMAP в рамках воркшопа **не используется**.

Это сделано специально, чтобы обеспечить единый сценарий запуска на:

- Linux (Ubuntu),
- macOS (Apple Silicon / ARM),
- Windows (Docker Desktop + WSL/Ubuntu).

---

## Что будет использоваться

- **FFmpeg** — извлечение кадров из видео;
- **COLMAP** — feature extraction, matching, sparse mapping, export;
- **Docker / Docker Compose** — единое окружение;
- **Python** — для дополнительных утилит и опциональных заданий.

---

## Требования к данным

Основной набор данных для воркшопа:

- входное видео: `mp4 (H.264)`;
- сцена: в основном статичная;
- видео заранее подготовлено и раздаётся всем участникам;
- по желанию можно использовать собственное видео в формате, поддерживаемом FFmpeg.

### Рекомендации к видео

Для получения качественной sparse reconstruction желательно:

- чтобы сцена была **статичной**;
- чтобы в кадре было достаточно **текстуры и деталей**;
- чтобы между соседними кадрами был **overlap** (общая область сцены);
- чтобы камера меняла **точку обзора (viewpoint)**, а не только вращалась на месте (англ. pure rotation);
- чтобы не было сильного размытия (англ. blur), пересветов и больших движущихся объектов.

### Что делаем с видео на воркшопе?

- извлекаем около **100 кадров**;
- уменьшаем разрешение кадров до **960x540**;
- используем имена вида `frame_001.jpg`, `frame_002.jpg`, ...

---

## Структура репозитория

```text
cv-colmap-workshop/
├─ README.md
├─ compose.yaml
├─ .env.example
├─ docker/
│  ├─ Dockerfile
│  ├─ Dockerfile.dev
│  └─ entrypoint.sh
├─ docs/
│  ├─ 00_overview.md
│  ├─ 01_setup.md
│  ├─ 02_ffmpeg_frames.md
│  ├─ 03_colmap_features_matching.md
│  ├─ 04_colmap_mapping.md
│  ├─ 05_export_and_inspect.md
│  ├─ 06_troubleshooting.md
│  └─ 07_next_steps.md
├─ scripts/
│  ├─ smoke_test.sh
│  ├─ extract_frames.sh
│  ├─ run_colmap_sparse.sh
│  ├─ export_model.sh
│  ├─ inspect_sqlite.sh
│  └─ optional_frame_similarity.py
├─ data/
│  ├─ video/
│  │  └─ sample.mp4
│  ├─ images/
│  ├─ workspace/
│  │  ├─ sparse/
│  │  ├─ text/
│  │  ├─ ply/
│  │  └─ logs/
│  └─ README.md
└─ examples/
   ├─ expected_tree.txt
   ├─ expected_logs/
   └─ sample_outputs/
````

---

## Основной маршрут воркшопа

### Этап 0. Подготовка окружения

* импорт готового Docker image из архива **или** сборка вручную;
* запуск контейнера;
* проверка, что доступны `colmap`, `ffmpeg`, `python`.

### Этап 1. Извлечение кадров из видео

* извлекаем кадры из `sample.mp4`;
* задаём фиксированную частоту кадров;
* уменьшаем разрешение до `960x540`.

Результат:

* папка `data/images/`;
* набор изображений `frame_001.jpg`, `frame_002.jpg`, ... .

### Этап 2. Извлечение признаков

* запускаем `colmap feature_extractor`;
* используем одну камеру для всех кадров;
* базовая модель камеры: `SIMPLE_RADIAL`.

Результат:

* создаётся `database.db`;
* в базу записываются ключевые точки и дескрипторы.

### Этап 3. Поиск соответствий

* запускаем `colmap exhaustive_matcher`;
* выполняем matching для всех пар кадров;
* получаем верефицированные соответствия.

Результат:

* `database.db` содержит признаки и соответствия.

### Этап 4. Sparse reconstruction

* запускаем `colmap mapper`;
* строим sparse 3D reconstruction;
* получаем позы камер и 3D points.

Результат:

* появляется папка `data/workspace/sparse/0/`.

### Этап 5. Экспорт модели

* экспортируем результат из бинарного формата в текстовый;
* экспортируем point cloud в PLY.

Результат:

* папка `data/workspace/text/`;
* файл `data/workspace/ply/model.ply`.

### Этап 6. Разбор артефактов

* что лежит в `database.db`;
* что содержат `cameras`, `images`, `points3D`;
* как читать результаты и использовать их дальше.

---

## Быстрый старт

### Вариант A. Импорт готового Docker image

Поместите архив с образом в удобную директорию и выполните:

```bash
docker image load -i colmap-workshop-image.tar
```

Проверьте, что образ появился:

```bash
docker images
```

### Вариант B. Сборка образа вручную

Из корня репозитория:

```bash
docker compose build
```

### Запуск контейнера

```bash
docker compose run --rm workshop bash
```

### Smoke test

Внутри контейнера:

```bash
bash scripts/smoke_test.sh
```

Smoke test должен проверить:

* наличие `colmap`;
* наличие `ffmpeg`;
* наличие `python`;
* наличие входного видео;
* доступность рабочих директорий.

---

## Пример основных действий

Подробные объяснения и комментарии находятся в папке `docs/`.

### 1. Извлечение кадров

```bash
ffmpeg -i /workspace/data/video/sample.mp4 \
  -vf "fps=1,scale=960:540" \
  -q:v 2 \
  -start_number 1 \
  /workspace/data/images/frame_%03d.jpg
```

### 2. Извлечение признаков

```bash
colmap feature_extractor \
  --database_path /workspace/data/workspace/database.db \
  --image_path /workspace/data/images \
  --ImageReader.camera_model SIMPLE_RADIAL \
  --ImageReader.single_camera 1 \
  --FeatureExtraction.use_gpu 0
```

### 3. Matching

```bash
colmap exhaustive_matcher \
  --database_path /workspace/data/workspace/database.db \
  --FeatureMatching.use_gpu 0
```

### 4. Sparse reconstruction

```bash
mkdir -p /workspace/data/workspace/sparse

colmap mapper \
  --database_path /workspace/data/workspace/database.db \
  --image_path /workspace/data/images \
  --output_path /workspace/data/workspace/sparse
```

### 5. Экспорт в TXT

```bash
mkdir -p /workspace/data/workspace/text

colmap model_converter \
  --input_path /workspace/data/workspace/sparse/0 \
  --output_path /workspace/data/workspace/text \
  --output_type TXT
```

### 6. Экспорт в PLY

```bash
mkdir -p /workspace/data/workspace/ply

colmap model_converter \
  --input_path /workspace/data/workspace/sparse/0 \
  --output_path /workspace/data/workspace/ply/model.ply \
  --output_type PLY
```

---

## Что должно получиться

После успешного прохождения всех шагов у вас должны появиться:

### В `data/images/`

* извлеченные кадры `frame_001.jpg`, `frame_002.jpg`, ...

### В `data/workspace/`

* `database.db`
* `sparse/0/...`
* `text/...`
* `ply/model.ply`
* `logs/...`

### Что можно открыть и проверить

* `model.ply` — в MeshLab, Blender или браузерном viewer;
* `cameras.txt` — intrinsics камеры;
* `images.txt` — позы камер и наблюдения;
* `points3D.txt` — sparse 3D points.

---

## Optional: задание на отбор похожих кадров

Дополнительно можно выполнить задание:

* написать Python-скрипт, который считывает изображения из `data/images/`;
* уменьшает их размер (для быстрого попарного сравнения);
* переводит в grayscale;
* оценивает попарную схожесть кадров;
* находит слишком похожие пары.

Рекомендуемый простой baseline:

* resize (Lanczos),
* grayscale,
* SSIM как метрика схожести между двумя кадрами.

Скрипт-заготовка будет находиться в:

```text
scripts/optional_frame_similarity.py
```

---

## Что не входит в обязательную часть

В рамках этого воркшопа **не рассматриваются подробно**:

* dense reconstruction;
* mesh reconstruction;
* texture mapping;
* GUI COLMAP;
* локализация новых кадров;
* интеграция с робототехникой / SLAM / Gaussian Splatting.

Эти темы упомянуты в финальном обзорном блоке как следующие шаги.

---

## Документация по шагам

Подробные инструкции находятся в папке `docs/`:

* `docs/00_overview.md` — краткая теория и обзор пайплайна;
* `docs/01_setup.md` — установка и запуск Docker;
* `docs/02_ffmpeg_frames.md` — извлечение кадров;
* `docs/03_colmap_features_matching.md` — SIFT и matching;
* `docs/04_colmap_mapping.md` — sparse reconstruction;
* `docs/05_export_and_inspect.md` — экспорт и разбор артефактов;
* `docs/06_troubleshooting.md` — типичные проблемы;
* `docs/07_next_steps.md` — что делать дальше.

---

## Типичные проблемы

Наиболее частые причины плохой реконструкции:

* слишком небольшой overlap между кадрами;
* слишком много почти одинаковых кадров;
* смазанные кадры;
* мало текстуры на сцене;
* движущиеся объекты (двигается не только камера, но и объекты на сцене);
* плохой выбор исходного видео.

Секция troubleshooting будет вынесена отдельно в:

```text
docs/06_troubleshooting.md
```

---

## Замечания к платформе 

### Linux (Ubuntu)

Поддерживается основной сценарий запуска через Docker и Docker Compose.

### macOS (Apple Silicon / ARM)

Поддерживается запуск через Docker Desktop. Используется CPU-only сценарий.

### Windows

Рекомендуемый вариант:

* Docker Desktop;
* WSL2;
* Ubuntu в WSL.

---

## Следующие шаги после воркшопа

После получения sparse reconstruction можно двигаться дальше в одном из направлений:

* dense reconstruction;
* meshing;
* анализ camera poses;
* экспорт данных в собственные пайплайны;
* подготовка данных для NVS / 3D Gaussian Splatting;
* использование результатов в CV/robotics задачах.
