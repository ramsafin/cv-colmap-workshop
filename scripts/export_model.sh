#!/usr/bin/env bash
# Экспорт разрежённой модели COLMAP 3.x в TXT и PLY (model_converter).
set -euo pipefail

readonly SCRIPT_NAME='export_model.sh'
readonly SCRIPT_VERSION='1.0.0'

DATA_ROOT="${DATA_ROOT:-/workspace/data}"
WORKSPACE_DIR="${WORKSPACE_DIR:-${DATA_ROOT}/workspace}"
SPARSE_DIR="${SPARSE_DIR:-${WORKSPACE_DIR}/sparse}"
TEXT_DIR="${TEXT_DIR:-${WORKSPACE_DIR}/text}"
PLY_DIR="${PLY_DIR:-${WORKSPACE_DIR}/ply}"
MODEL_INDEX="${MODEL_INDEX:-0}"

INPUT_MODEL_DIR=''
INPUT_FROM_FLAG=''
INPUT_FROM_POS=''

usage() {
  cat <<EOF
${SCRIPT_NAME} — экспорт модели COLMAP в TXT и PLY.

Версия скрипта: ${SCRIPT_VERSION}

Использование:
  bash scripts/${SCRIPT_NAME} [опции]
  bash scripts/${SCRIPT_NAME} [опции] -- [каталог_модели]

Опции:
  -h, --help                 справка
  -v, --version              версия скрипта
  -i, --input-model DIR      каталог с выходом mapper (файлы *.bin / *.txt)
      --model-index N        индекс модели при пути по умолчанию (см. ниже)
      --sparse-dir DIR       родительский каталог моделей (по умолчанию из окружения)
  -t, --text-dir DIR         каталог для TXT-экспорта
  -p, --ply-dir DIR          каталог для PLY (файл model.ply)

Позиционный аргумент после -- или без флагов:
  каталог_модели — то же, что -i (нельзя комбинировать с -i)

По умолчанию вход: \${SPARSE_DIR}/\${MODEL_INDEX} (см. переменные окружения).

Переменные окружения (необязательно):
  DATA_ROOT, WORKSPACE_DIR, SPARSE_DIR, TEXT_DIR, PLY_DIR, MODEL_INDEX

Примеры:
  bash scripts/${SCRIPT_NAME} --help
  bash scripts/${SCRIPT_NAME}
  bash scripts/${SCRIPT_NAME} -i /workspace/data/workspace/sparse/1
  bash scripts/${SCRIPT_NAME} --model-index 1
  MODEL_INDEX=1 bash scripts/${SCRIPT_NAME}
  bash scripts/${SCRIPT_NAME} -- /workspace/data/workspace/sparse/0
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

pass() {
  printf '[ OK ] %s\n' "${1}"
}

require_arg() {
  if [[ "${#}" -lt 2 ]]; then
    printf '%s: опция %s требует значение\n' "${SCRIPT_NAME}" "${1}" >&2
    die_usage
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
        printf '%s %s\n' "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
        exit 0
        ;;
      -i | --input-model)
        require_arg "${@}"
        INPUT_MODEL_DIR="${2}"
        INPUT_FROM_FLAG=1
        shift 2
        ;;
      --model-index)
        require_arg "${@}"
        MODEL_INDEX="${2}"
        shift 2
        ;;
      --sparse-dir)
        require_arg "${@}"
        SPARSE_DIR="${2}"
        shift 2
        ;;
      -t | --text-dir)
        require_arg "${@}"
        TEXT_DIR="${2}"
        shift 2
        ;;
      -p | --ply-dir)
        require_arg "${@}"
        PLY_DIR="${2}"
        shift 2
        ;;
      --)
        shift
        while [[ "${#}" -gt 0 ]]; do
          if [[ -n "${INPUT_FROM_POS}" ]]; then
            printf '%s: после -- ожидается один каталог модели\n' "${SCRIPT_NAME}" >&2
            die_usage
          fi
          INPUT_FROM_POS="${1}"
          shift
        done
        break
        ;;
      -*)
        printf '%s: неизвестная опция: %s\n' "${SCRIPT_NAME}" "${1}" >&2
        die_usage
        ;;
      *)
        if [[ -n "${INPUT_FROM_POS}" ]]; then
          printf '%s: лишний позиционный аргумент: %s\n' "${SCRIPT_NAME}" "${1}" >&2
          die_usage
        fi
        INPUT_FROM_POS="${1}"
        shift
        ;;
    esac
  done

  if [[ -n "${INPUT_FROM_FLAG}" && -n "${INPUT_FROM_POS}" ]]; then
    printf '%s: нельзя одновременно указывать -i/--input-model и позиционный путь\n' "${SCRIPT_NAME}" >&2
    die_usage
  fi

  if [[ -n "${INPUT_FROM_FLAG}" ]]; then
    :
  elif [[ -n "${INPUT_FROM_POS}" ]]; then
    INPUT_MODEL_DIR="${INPUT_FROM_POS}"
  else
    INPUT_MODEL_DIR="${SPARSE_DIR}/${MODEL_INDEX}"
  fi
}

model_dir_has_artifacts() {
  if ! find "${INPUT_MODEL_DIR}" -maxdepth 1 -type f \( -name '*.bin' -o -name '*.txt' \) -print -quit | grep -q .; then
    return 1
  fi
  return 0
}

run_colmap_txt() {
  set +e
  colmap model_converter \
    --input_path "${INPUT_MODEL_DIR}" \
    --output_path "${TEXT_DIR}" \
    --output_type TXT
  local rc="${?}"
  set -e
  if [[ "${rc}" -ne 0 ]]; then
    die_run "model_converter (TXT) завершился с кодом ${rc}"
  fi
}

run_colmap_ply() {
  set +e
  colmap model_converter \
    --input_path "${INPUT_MODEL_DIR}" \
    --output_path "${PLY_DIR}/model.ply" \
    --output_type PLY
  local rc="${?}"
  set -e
  if [[ "${rc}" -ne 0 ]]; then
    die_run "model_converter (PLY) завершился с кодом ${rc}"
  fi
}

main() {
  parse_args "${@}"

  command -v colmap >/dev/null 2>&1 || die_run 'colmap не найден в PATH'

  test -d "${INPUT_MODEL_DIR}" || die_run "Каталог модели не существует: ${INPUT_MODEL_DIR}"

  model_dir_has_artifacts || die_run "Каталог не похож на модель COLMAP (нет .bin/.txt): ${INPUT_MODEL_DIR}"

  mkdir -p "${TEXT_DIR}" "${PLY_DIR}"

  echo '== Export model =='
  colmap help 2>&1 | head -n 1 || true
  echo "Input model : ${INPUT_MODEL_DIR}"
  echo "Text output : ${TEXT_DIR}"
  echo "PLY output  : ${PLY_DIR}/model.ply"

  run_colmap_txt
  pass 'TXT export completed'

  run_colmap_ply
  pass 'PLY export completed'

  echo
  echo '== Export summary =='

  local f
  for f in rigs.txt cameras.txt frames.txt images.txt points3D.txt; do
    if [[ -f "${TEXT_DIR}/${f}" ]]; then
      printf '[ OK ] %s\n' "${TEXT_DIR}/${f}"
    else
      printf '[WARN] %s not found\n' "${TEXT_DIR}/${f}"
    fi
  done

  if [[ -f "${PLY_DIR}/model.ply" ]]; then
    printf '[ OK ] %s\n' "${PLY_DIR}/model.ply"
  else
    die_run 'PLY export missing'
  fi
}

main "${@}"
