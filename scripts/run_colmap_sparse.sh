#!/usr/bin/env bash
# Разрежённый пайплайн COLMAP для воркшопа (ориентир: COLMAP 3.9, SiftExtraction.* / SiftMatching.*).
set -euo pipefail

readonly SCRIPT_NAME='run_colmap_sparse.sh'
readonly SCRIPT_VERSION='1.0.0'

DATA_ROOT="${DATA_ROOT:-/workspace/data}"
IMAGES_DIR="${IMAGES_DIR:-${DATA_ROOT}/images}"
WORKSPACE_DIR="${WORKSPACE_DIR:-${DATA_ROOT}/workspace}"
DATABASE_PATH="${DATABASE_PATH:-${WORKSPACE_DIR}/database.db}"
SPARSE_DIR="${SPARSE_DIR:-${WORKSPACE_DIR}/sparse}"
LOG_DIR="${LOG_DIR:-${WORKSPACE_DIR}/logs}"
CAMERA_MODEL="${CAMERA_MODEL:-SIMPLE_RADIAL}"
SINGLE_CAMERA="${SINGLE_CAMERA:-1}"

MODE=''
NO_VERSION_WARN=0

usage() {
  cat <<EOF
${SCRIPT_NAME} — sparse-пайплайн COLMAP (воркшоп).

Версия скрипта: ${SCRIPT_VERSION}

Использование:
  bash scripts/${SCRIPT_NAME} [опции] [РЕЖИМ]

РЕЖИМ (позиционный, по умолчанию: all):
  features   — извлечение признаков (пересоздаёт database.db)
  matching   — exhaustive_matcher
  mapping    — mapper
  all        — features → matching → mapping

Опции:
  -h, --help              эта справка
  -v, --version            версия скрипта и строка COLMAP
      --no-version-warn    не печатать предупреждение, если COLMAP не 3.9

Переменные окружения (необязательно):
  DATA_ROOT, IMAGES_DIR, WORKSPACE_DIR, DATABASE_PATH, SPARSE_DIR, LOG_DIR,
  CAMERA_MODEL, SINGLE_CAMERA

Примеры:
  bash scripts/${SCRIPT_NAME} --help
  bash scripts/${SCRIPT_NAME} -- features
  IMAGES_DIR=/workspace/data/images bash scripts/${SCRIPT_NAME} mapping

Документация: docs/03_colmap_features_matching.md, docs/04_colmap_mapping.md
EOF
}

die_usage() {
  usage >&2
  exit 1
}

die_run() {
  printf '[FAIL] %s\n' "${1}" >&2
  exit 2
}

print_script_version() {
  printf '%s %s\n' "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
  if command -v colmap >/dev/null 2>&1; then
    colmap help 2>&1 | head -n 1 || true
  else
    printf '%s\n' 'colmap: не найден в PATH'
  fi
}

parse_args() {
  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
      -h | --help)
        usage
        exit 0
        ;;
      -v | --version)
        print_script_version
        exit 0
        ;;
      --no-version-warn)
        NO_VERSION_WARN=1
        shift
        ;;
      --)
        shift
        if [[ "${#}" -gt 1 ]]; then
          printf '%s: после -- ожидается один аргумент (РЕЖИМ)\n' "${SCRIPT_NAME}" >&2
          die_usage
        fi
        if [[ "${#}" -eq 1 ]]; then
          MODE="${1}"
          shift
        fi
        break
        ;;
      -*)
        printf '%s: неизвестная опция: %s\n' "${SCRIPT_NAME}" "${1}" >&2
        die_usage
        ;;
      *)
        if [[ -n "${MODE}" ]]; then
          printf '%s: лишний позиционный аргумент: %s\n' "${SCRIPT_NAME}" "${1}" >&2
          die_usage
        fi
        MODE="${1}"
        shift
        ;;
    esac
  done

  if [[ -z "${MODE}" ]]; then
    MODE='all'
  fi
}

report_colmap() {
  local line
  if [[ "${NO_VERSION_WARN}" -eq 1 ]]; then
    return 0
  fi
  line="$(colmap help 2>&1 | head -n 1 || echo 'COLMAP (не удалось получить версию)')"
  echo "== ${line}"
  if [[ "${line}" != *"3.9"* ]]; then
    printf '%s\n' '[WARN] Материалы воркшопа проверены с COLMAP 3.9; при другой версии сверяйте опции в colmap help <команда>.' >&2
  fi
}

pass() {
  printf '[ OK ] %s\n' "${1}"
}

run_colmap_tee() {
  local logfile="${1}"
  shift
  set +e
  "${@}" 2>&1 | tee "${logfile}"
  local -a st=("${PIPESTATUS[@]}")
  set -e
  if [[ "${st[0]}" -ne 0 ]]; then
    die_run "Команда colmap завершилась с кодом ${st[0]} (см. лог: ${logfile})"
  fi
}

check_prereqs() {
  command -v colmap >/dev/null 2>&1 || die_run 'colmap не найден в PATH'
  [[ -d "${IMAGES_DIR}" ]] || die_run "Каталог со снимками не существует: ${IMAGES_DIR}"
  if ! find "${IMAGES_DIR}" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print -quit | grep -q .; then
    die_run "В каталоге нет подходящих изображений: ${IMAGES_DIR}"
  fi
}

validate_mode() {
  case "${MODE}" in
    features | matching | mapping | all)
      return 0
      ;;
    *)
      printf '%s: неизвестный режим: %s\n' "${SCRIPT_NAME}" "${MODE}" >&2
      die_usage
      ;;
  esac
}

run_features() {
  echo '== Step: feature extraction =='
  echo "Images   : ${IMAGES_DIR}"
  echo "Database : ${DATABASE_PATH}"
  echo "Camera   : ${CAMERA_MODEL}"
  echo "Single   : ${SINGLE_CAMERA}"

  rm -f "${DATABASE_PATH}"

  run_colmap_tee "${LOG_DIR}/feature_extractor.log" \
    colmap feature_extractor \
    --database_path "${DATABASE_PATH}" \
    --image_path "${IMAGES_DIR}" \
    --ImageReader.camera_model "${CAMERA_MODEL}" \
    --ImageReader.single_camera "${SINGLE_CAMERA}" \
    --SiftExtraction.max_image_size 960 \
    --SiftExtraction.max_num_features 2048 \
    --SiftExtraction.use_gpu 0

  [[ -f "${DATABASE_PATH}" ]] || die_run 'database.db не создан'
  [[ -s "${DATABASE_PATH}" ]] || die_run 'database.db пуст'
  pass 'feature extraction completed'
}

run_matching() {
  echo '== Step: exhaustive matching =='
  echo "Database : ${DATABASE_PATH}"

  [[ -f "${DATABASE_PATH}" ]] || die_run 'Сначала выполните режим features (нет database.db)'

  run_colmap_tee "${LOG_DIR}/exhaustive_matcher.log" \
    colmap exhaustive_matcher \
    --database_path "${DATABASE_PATH}" \
    --SiftMatching.guided_matching 1 \
    --SiftMatching.use_gpu 0

  pass 'matching completed'
}

run_mapping() {
  echo '== Step: sparse mapping =='
  echo "Database : ${DATABASE_PATH}"
  echo "Images   : ${IMAGES_DIR}"
  echo "Output   : ${SPARSE_DIR}"

  [[ -f "${DATABASE_PATH}" ]] || die_run 'Сначала выполните features и matching'

  mkdir -p "${SPARSE_DIR}"

  run_colmap_tee "${LOG_DIR}/mapper.log" \
    colmap mapper \
    --database_path "${DATABASE_PATH}" \
    --image_path "${IMAGES_DIR}" \
    --output_path "${SPARSE_DIR}"

  [[ -d "${SPARSE_DIR}" ]] || die_run 'Каталог sparse не создан'

  local model_dir
  model_dir="$(find "${SPARSE_DIR}" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1 || true)"
  [[ -n "${model_dir}" ]] || die_run "Внутри ${SPARSE_DIR} не создан каталог модели"

  echo "Model dir : ${model_dir}"
  ls -la "${model_dir}"

  pass 'mapping completed'
}

show_summary() {
  echo
  echo '== Sparse pipeline summary =='

  if [[ -f "${DATABASE_PATH}" ]]; then
    echo "database.db : OK ($(du -h "${DATABASE_PATH}" | cut -f1))"
  else
    echo 'database.db : missing'
  fi

  echo "images      : $(find "${IMAGES_DIR}" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | wc -l | tr -d '[:space:]')"
  echo 'sparse dirs :'
  find "${SPARSE_DIR}" -mindepth 1 -maxdepth 1 -type d | sort || true

  echo 'logs        :'
  ls -1 "${LOG_DIR}" || true
}

main() {
  parse_args "${@}"
  if [[ "${MODE}" == 'help' ]]; then
    usage
    exit 0
  fi
  validate_mode
  check_prereqs
  mkdir -p "${WORKSPACE_DIR}" "${SPARSE_DIR}" "${LOG_DIR}"
  report_colmap

  case "${MODE}" in
    features)
      run_features
      ;;
    matching)
      run_matching
      ;;
    mapping)
      run_mapping
      ;;
    all)
      run_features
      run_matching
      run_mapping
      ;;
  esac

  show_summary
}

main "${@}"
