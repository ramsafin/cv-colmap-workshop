# 05. Экспорт и просмотр: текстовые файлы, PLY, база, разрежённая модель

После **`mapper`** модель лежит в **бинарном** виде в каталоге вроде **`sparse/0`**. Здесь мы:

1. **экспортируем** разрежённую модель в **текст** и в файл **PLY** (облако точек для просмотра);
2. кратко разбираем **имена и роли** выходных файлов;
3. при необходимости **смотрим содержимое** базы **`database.db`**.

**Где выполнять:** контейнер, `/workspace`. Нужна готовая модель из [шага 04](04_colmap_mapping.md).

## Как пользоваться этим файлом

1. Убедитесь, что существует **`/workspace/data/workspace/sparse/0`** (или другой номер — подставьте свой путь).
2. Запустите **`export_model.sh`** или команды **`model_converter`** вручную.
3. Проверьте папки **`text/`** и **`ply/`**.
4. При желании запустите **`inspect_sqlite.sh`** для базы.
5. При проблемах см. [06_troubleshooting.md](06_troubleshooting.md), затем [07_next_steps.md](07_next_steps.md).

## Скрипты шага: справка

Сценарии **`export_model.sh`** и **`inspect_sqlite.sh`** поддерживают:

* **`--help`** / **`-h`** — описание опций и примеры

## Цель этапа

Вы получаете:

- **текстовые** файлы описания модели COLMAP;
- файл **`model.ply`** — разрежённое **облако точек** для программ просмотра;
- понимание, где лежат **внутренние параметры камеры** (англ. *intrinsics*), **позы** (*poses*) и **3D-точки**;
- базовое представление о таблицах в **`database.db`**.

---

## Входные данные

Ожидается каталог модели, чаще всего:

```text
/workspace/data/workspace/sparse/0
```

Если COLMAP создал, например, **`sparse/1`**, укажите этот путь в скрипте или в **`--input_path`** вручную.

---

## Что экспортируем

Утилита **`colmap model_converter`** переводит разрежённую модель в другие форматы. В воркшопе используются:

* **TXT** — человекочитаемые текстовые таблицы;
* **PLY** — облако точек для **просмотрщиков** (англ. *viewer*).

---

## Запуск через скрипт `export_model.sh`

Справка по всем опциям: `bash scripts/export_model.sh --help` (или `-h`).

```bash
bash scripts/export_model.sh
```

По умолчанию вход — **`/workspace/data/workspace/sparse/0`**.

Другая модель — **флагом** или **первым позиционным аргументом** (как раньше):

```bash
bash scripts/export_model.sh -i /workspace/data/workspace/sparse/1
bash scripts/export_model.sh /workspace/data/workspace/sparse/1
```

Или через **индекс** (путь будет **`${SPARSE_DIR}/${MODEL_INDEX}`**):

```bash
bash scripts/export_model.sh --model-index 1
MODEL_INDEX=1 bash scripts/export_model.sh
```

Переменные **`DATA_ROOT`**, **`WORKSPACE_DIR`**, **`SPARSE_DIR`**, **`TEXT_DIR`**, **`PLY_DIR`** описаны в [`scripts/export_model.sh`](../scripts/export_model.sh) и в выводе `--help`.

Перед вызовом **`model_converter`** скрипт проверяет, что в каталоге модели есть файлы **`*.bin`** или **`*.txt`** (типичный выход **`mapper`** в COLMAP 3.x). Если папка пустая или не та, вы получите понятное сообщение об ошибке.

---

## Ручной экспорт в TXT

```bash
mkdir -p /workspace/data/workspace/text

colmap model_converter \
  --input_path /workspace/data/workspace/sparse/0 \
  --output_path /workspace/data/workspace/text \
  --output_type TXT
```

---

## Ручной экспорт в PLY

```bash
mkdir -p /workspace/data/workspace/ply

colmap model_converter \
  --input_path /workspace/data/workspace/sparse/0 \
  --output_path /workspace/data/workspace/ply/model.ply \
  --output_type PLY
```

---

## Ожидаемые файлы

После экспорта в TXT:

```text
/workspace/data/workspace/text/rigs.txt
/workspace/data/workspace/text/cameras.txt
/workspace/data/workspace/text/frames.txt
/workspace/data/workspace/text/images.txt
/workspace/data/workspace/text/points3D.txt
```

После PLY:

```text
/workspace/data/workspace/ply/model.ply
```

Файлы **`rigs.txt`** и **`frames.txt`** относятся к структуре **риг/кадр** в новых версиях COLMAP; при одной камере они всё равно могут появиться.

---

## Проверка

```bash
ls -la /workspace/data/workspace/text
ls -lh /workspace/data/workspace/ply/model.ply
```

---

## Краткий разбор текстовых файлов

### `cameras.txt`

Параметры **камер**: номер, модель, ширина и высота снимка, **внутренние параметры** (*intrinsics*) — фокусные расстояния, главная точка, искажения в зависимости от модели.

### `images.txt`

Для каждого снимка: идентификатор, **ориентация и положение камеры** в мире, ссылка на камеру, имя файла, **2D-наблюдения** (*2D observations*) — связь точек на снимке с 3D.

### `points3D.txt`

**3D-точки**, цвет **RGB**, ошибка перепроецирования, **дорожки наблюдений** (*tracks*) — на каких снимках видна точка.

---

## Просмотр базы `database.db`

Справка: `bash scripts/inspect_sqlite.sh --help`.

Скрипт диагностики выводит размер файла, версию **SQLite**, список таблиц и число строк в типичных для COLMAP 3.x таблицах:

```bash
bash scripts/inspect_sqlite.sh
```

По умолчанию открывается **`/workspace/data/workspace/database.db`**. Другой путь — **`-d`** или **первым аргументом**:

```bash
bash scripts/inspect_sqlite.sh -d /workspace/data/workspace/backup_database.db
bash scripts/inspect_sqlite.sh /workspace/data/workspace/backup_database.db
```

(любой путь к вашему файлу SQLite с данными COLMAP.)

---

## Как открыть `model.ply` на своём компьютере

Файл лежит в проекте на диске (через монтирование в **`/workspace/...`**). На **хосте** его можно открыть, например, в **MeshLab**, **Blender** или другом **просмотрщике PLY**.

---

## Критерии успеха

* **`export_model.sh`** завершился с кодом **0** (без **`[FAIL]`** в stderr);
* есть каталог **`text/`** с ожидаемыми файлами;
* есть **`ply/model.ply`** ненулевого размера;
* вы понимаете, где искать **внутренние параметры камеры**, **позы** и **3D-точки**.

---

## Возможные проблемы

### 1. Нет `sparse/0`

Сначала успешно выполните **`mapper`** ([шаг 04](04_colmap_mapping.md)).

### 2. TXT не создались

Проверьте **`--input_path`**, что каталог модели **не пустой**, что путь вывода **`--output_path`** верный.

### 3. PLY не открывается

Проверьте размер файла и ошибки **`model_converter`** в консоли.

---

## Следующие шаги

1. [06_troubleshooting.md](06_troubleshooting.md) — если что-то пошло не так на любом этапе.
2. [07_next_steps.md](07_next_steps.md) — плотная реконструкция, сетки, Python и т.д.
