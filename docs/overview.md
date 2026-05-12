# COLMAP Workshop

**FFmpeg → SIFT → exhaustive matching → mapper → export → разбор артефактов**. 

COLMAP разделяет Structure-from-Motion на три стадии: 

1. Извлечение признаков (feature extraction), 
2. Matching с geometric verification
3. и реконструкция структуры/движения.

## 1. Цель воркшопа

К концу занятия студент должен:

* извлечь около 100 кадров из видео;
* построить sparse reconstruction в COLMAP;
* получить и открыть облако точек (point cloud);
* разобрать, что лежит в `database.db`, `sparse/0`, а затем в текстовом и PLY-экспорте;
* понять, как эти артефакты использовать дальше для dense/MVS, локализации, NVS/3DGS или анализа поз камер.

## 2. Что входит в репозиторий воркшопа?

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
```

## 3. Архитектура Docker

**Контейнер** с:

* COLMAP CLI,
* FFmpeg,
* Python 3,
* SQLite tools,
* bash/coreutils.

Варианты сборки Docker-образа:

* **основной:** импорт готового образа из `.tar` через `docker image load -i ...`;
* **резервный:** локальная сборка из `docker/Dockerfile`. 

Для кроссплатформенности:

* `linux/amd64` для Ubuntu и Windows/WSL,
* `linux/arm64` для macOS ARM.

## 4. Compose-стратегия

Хотя сервис фактически один, `compose.yaml` всё равно полезен: он даёт единый способ запускать контейнер, монтировать каталог проекта и переиспользовать переменные окружения. 

**Docker Compose** предназначен для описания сервисов, точек монтирования и конфигурации в одном YAML-файле и запуска их одной командой.

* сервис `workshop`,
* bind mount корня проекта в `/workspace`,
* рабочая директория `/workspace`,
* интерактивный shell по умолчанию.

## 5. Сценарий

### Блок 0

`docs/00_overview.md`

Содержание:

* что такое SfM;
* почему вход должен иметь текстуру, overlap и разные точки обзора;
* почему видео стоит прореживать по fps;
* что будет на выходе: `database.db`, sparse model, txt export, PLY.

COLMAP рекомендует хороший overlap, разные viewpoints, достаточную текстуру и отдельно отмечает, что при использовании видео имеет смысл down-sampling frame rate.

### Блок 1

`docs/01_setup.md`

Содержание:

* импорт готового образа;
* `docker images` проверка;
* `docker compose run --rm workshop bash`;
* `scripts/smoke_test.sh`.

Smoke test должен проверить:

* `colmap help`,
* `ffmpeg -version`,
* `python --version`,
* наличие `/workspace/data/video/sample.mp4`.

CLI COLMAP официально предоставляет все команды через `colmap`, а Docker Compose предназначен для запуска и управления сервисами из YAML.

### Блок 2

`docs/02_ffmpeg_frames.md`

Содержание:

* зачем извлекать не все кадры;
* как выбрать fps, чтобы получить ~100 изображений;
* почему сразу уменьшаем разрешение до `960x540`.

Базовая команда:

```bash
ffmpeg -i /workspace/data/video/sample.mp4 \
  -vf "fps=1,scale=960:540" \
  -q:v 2 \
  -start_number 1 \
  /workspace/data/images/frame_%03d.jpg
```

FFmpeg документирует `fps` как стандартный video filter для задания выходной частоты кадров, а `scale` — как стандартный filter изменения размера изображения.

Ожидаемый результат:

* папка `data/images/`;
* файлы `frame_001.jpg ...`;
* около 100 кадров.

### Блок 3

`docs/03_colmap_features_matching.md`

Сначала feature extraction:

```bash
colmap feature_extractor \
  --database_path /workspace/data/workspace/database.db \
  --image_path /workspace/data/images \
  --ImageReader.camera_model SIMPLE_RADIAL \
  --ImageReader.single_camera 1 \
  --FeatureExtraction.use_gpu 0
```

Далее, matching:

```bash
colmap exhaustive_matcher \
  --database_path /workspace/data/workspace/database.db \
  --FeatureMatching.use_gpu 0
```

COLMAP прямо рекомендует отключать GPU через соответствующие флаги. 

Ожидаемый результат:

* появился `database.db`;
* extraction и matching завершились без ошибок;
* в `database.db` лежат признаки и сопоставления.

### Блок 4

`docs/04_colmap_mapping.md`

Команда:

```bash
mkdir -p /workspace/data/workspace/sparse

colmap mapper \
  --database_path /workspace/data/workspace/database.db \
  --image_path /workspace/data/images \
  --output_path /workspace/data/workspace/sparse
```

Это официальный следующий шаг после extraction/matching в COLMAP.

Ожидаемый результат:

* папка `sparse/0`;
* внутри как минимум бинарные файлы sparse model;
* студенты видят число зарегистрированных изображений в логах.

В новых форматах sparse model по умолчанию хранится в бинарном виде и включает данные о `rigs`, `cameras`, `frames`, `images`, `points`. Если рядом есть и `.bin`, и `.txt`, COLMAP предпочитает бинарный формат.

### Блок 5

`docs/05_export_and_inspect.md`

Экспорт в читаемый текст:

```bash
mkdir -p /workspace/data/workspace/text

colmap model_converter \
  --input_path /workspace/data/workspace/sparse/0 \
  --output_path /workspace/data/workspace/text \
  --output_type TXT
```

Экспорт в PLY:

```bash
mkdir -p /workspace/data/workspace/ply

colmap model_converter \
  --input_path /workspace/data/workspace/sparse/0 \
  --output_path /workspace/data/workspace/ply/model.ply \
  --output_type PLY
```

COLMAP официально указывает, что `model_converter` используется для конвертации между бинарным, текстовым и другими форматами, включая PLY.

Разбор файлов:

* `cameras.txt` — intrinsics;
* `images.txt` — poses и 2D observations;
* `points3D.txt` — 3D points и tracks;
* `rigs.txt` и `frames.txt` — если есть в модели.

Имена и назначение этих файлов официально описаны в формате sparse output COLMAP.

### Блок 6

`docs/06_troubleshooting.md` и `docs/07_next_steps.md`

Troubleshooting:

* мало overlap;
* мало текстуры;
* повторяющиеся/смазанные кадры;
* reconstruction распалась на несколько компонентов;
* слишком мало registered images.

Следующие шаги:

* dense reconstruction;
* meshing;
* pycolmap / Python-анализ;
* downstream pipelines.

COLMAP tutorial прямо делит pipeline на sparse SfM и dense MVS и показывает, что dense стадия идёт отдельно после sparse результата.

## 6. Что делают скрипты?

`scripts/smoke_test.sh`

* проверяет бинарные файлы;
* печатает версии;
* проверяет наличие видео и каталогов.

`scripts/extract_frames.sh`

* принимает `INPUT_VIDEO`, `FPS`, `OUT_DIR`;
* создаёт `frame_%03d.jpg`.

`scripts/run_colmap_sparse.sh`

* feature extraction;
* exhaustive matcher;
* mapper;
* логирует в `data/workspace/logs/`.

`scripts/export_model.sh`

* экспортирует TXT и PLY.

`scripts/inspect_sqlite.sh`

* показывает список таблиц в `database.db`;
* делает пару простых запросов `sqlite3`.

`optional_frame_similarity.py`

* grayscale + resize;
* попарный SSIM;
* CSV с наиболее похожими кадрами.

## 7. Контрольные точки для студентов

После FFmpeg студент должен увидеть:

* `data/images/frame_001.jpg`;
* примерно 100 изображений.

После `feature_extractor`:

* `database.db` создан;
* команда завершилась без ошибки.

После `exhaustive_matcher`:

* `database.db` обновлена;
* matching не завершился аварийно.

После `mapper`:

* есть `data/workspace/sparse/0`;
* внутри файлы модели.

После `model_converter`:

* в `text/` лежат `.txt`;
* в `ply/` лежит `model.ply`.

## 8. Что не включено?

В обязательную часть **не включено**:

* `image_undistorter`,
* `patch_match_stereo`,
* `stereo_fusion`,
* mesh reconstruction,
* GUI,
* локализация,
* downstream robotics/NVS.

## References

1. https://colmap.github.io/cli.html "Command-line Interface — COLMAP 4.1.0.dev0 | 43dd3bb2 (2026-03-16) documentation"
2. https://colmap.github.io/format.html "Output Format — COLMAP 4.1.0.dev0 | 43dd3bb2 (2026-03-16) documentation"
3. https://docs.docker.com/reference/cli/docker/image/load/ "docker image load | Docker Docs"
4. https://docs.docker.com/build/building/multi-platform/ "Multi-platform builds | Docker Docs"
5. https://docs.docker.com/compose/ "Docker Compose | Docker Docs"
6. https://colmap.github.io/tutorial.html "Tutorial — COLMAP 4.1.0.dev0 | 43dd3bb2 (2026-03-16) documentation"
7. https://ffmpeg.org/ffmpeg-filters.html "FFmpeg Filters Documentation"

