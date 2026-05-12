#!/usr/bin/env bash
# Извлечение кадров (FFmpeg) → frame_001.jpg, …
set -euo pipefail

readonly SCRIPT_NAME='extract_frames.sh'
readonly SCRIPT_VERSION='1.0.0'

INPUT_VIDEO='/workspace/data/video/sample.mp4'
OUTPUT_DIR='/workspace/data/images'
FPS='3/4'
WIDTH='960'
HEIGHT='540'
QUALITY='2'
NO_CLEANUP=0

usage() {
  cat <<EOF
${SCRIPT_NAME} — извлечение JPEG-кадров из видео.

Версия скрипта: ${SCRIPT_VERSION}

Использование:
  bash scripts/${SCRIPT_NAME} [опции]
  bash scripts/${SCRIPT_NAME} [опции] -- [видео] [каталог] [fps] [ширина] [высота] [качество]

Опции:
  -h, --help                 справка
  -v, --version              версия скрипта
  -i, --input PATH           входной видеофайл (${INPUT_VIDEO})
  -o, --output-dir DIR       каталог для frame_*.jpg (${OUTPUT_DIR})
      --fps RATE             аргумент фильтра ffmpeg fps (дробь или число) (${FPS})
      --width N              ширина (${WIDTH})
      --height N             высота (${HEIGHT})
      --quality N            значение -q:v для JPEG (${QUALITY})
      --no-cleanup           не удалять существующие frame_*.jpg перед записью

Позиционные аргументы после -- (как в прежних версиях воркшопа):
  видео каталог fps ширина высота качество

Примеры:
  bash scripts/${SCRIPT_NAME} --help
  bash scripts/${SCRIPT_NAME}
  bash scripts/${SCRIPT_NAME} -i /workspace/data/video/sample.mp4 -o /workspace/data/images
  bash scripts/${SCRIPT_NAME} -- /workspace/data/video/sample.mp4 /workspace/data/images 1 960 540 2
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

require_arg() {
  if [[ "${#}" -lt 2 ]]; then
    printf '%s: опция %s требует значение\n' "${SCRIPT_NAME}" "${1}" >&2
    die_usage
  fi
}

parse_args() {
  local -a positional=()

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
      -i | --input)
        require_arg "${@}"
        INPUT_VIDEO="${2}"
        shift 2
        ;;
      -o | --output-dir)
        require_arg "${@}"
        OUTPUT_DIR="${2}"
        shift 2
        ;;
      --fps)
        require_arg "${@}"
        FPS="${2}"
        shift 2
        ;;
      --width)
        require_arg "${@}"
        WIDTH="${2}"
        shift 2
        ;;
      --height)
        require_arg "${@}"
        HEIGHT="${2}"
        shift 2
        ;;
      --quality)
        require_arg "${@}"
        QUALITY="${2}"
        shift 2
        ;;
      --no-cleanup)
        NO_CLEANUP=1
        shift
        ;;
      --)
        shift
        while [[ "${#}" -gt 0 ]]; do
          positional+=("${1}")
          shift
        done
        break
        ;;
      -*)
        printf '%s: неизвестная опция: %s\n' "${SCRIPT_NAME}" "${1}" >&2
        die_usage
        ;;
      *)
        positional+=("${1}")
        shift
        ;;
    esac
  done

  if [[ "${#positional[@]}" -gt 0 ]]; then
    [[ "${#positional[@]}" -le 6 ]] || die_usage
    [[ -n "${positional[0]:-}" ]] && INPUT_VIDEO="${positional[0]}"
    [[ -n "${positional[1]:-}" ]] && OUTPUT_DIR="${positional[1]}"
    [[ -n "${positional[2]:-}" ]] && FPS="${positional[2]}"
    [[ -n "${positional[3]:-}" ]] && WIDTH="${positional[3]}"
    [[ -n "${positional[4]:-}" ]] && HEIGHT="${positional[4]}"
    [[ -n "${positional[5]:-}" ]] && QUALITY="${positional[5]}"
  fi
}

run_ffmpeg() {
  set +e
  ffmpeg -hide_banner -nostdin -y \
    -i "${INPUT_VIDEO}" \
    -vf "fps=${FPS},scale=${WIDTH}:${HEIGHT}" \
    -q:v "${QUALITY}" \
    -start_number 1 \
    "${OUTPUT_DIR}/frame_%03d.jpg"
  local rc="${?}"
  set -e
  if [[ "${rc}" -ne 0 ]]; then
    die_run "ffmpeg завершился с кодом ${rc}"
  fi
}

main() {
  parse_args "${@}"

  if [[ ! -f "${INPUT_VIDEO}" ]]; then
    die_run "Входное видео не найдено: ${INPUT_VIDEO}"
  fi

  command -v ffmpeg >/dev/null 2>&1 || die_run 'ffmpeg не найден в PATH'

  mkdir -p "${OUTPUT_DIR}"

  if [[ "${NO_CLEANUP}" -eq 0 ]]; then
    find "${OUTPUT_DIR}" -maxdepth 1 -type f -name 'frame_*.jpg' -delete
  fi

  echo '== Frame extraction =='
  echo "Input video : ${INPUT_VIDEO}"
  echo "Output dir  : ${OUTPUT_DIR}"
  echo "FPS         : ${FPS}"
  echo "Resolution  : ${WIDTH}x${HEIGHT}"
  echo "JPEG quality: ${QUALITY}"

  run_ffmpeg

  local frame_count first_frame last_frame
  frame_count="$(find "${OUTPUT_DIR}" -maxdepth 1 -type f -name 'frame_*.jpg' | wc -l | tr -d '[:space:]')"
  first_frame="$(find "${OUTPUT_DIR}" -maxdepth 1 -type f -name 'frame_*.jpg' | sort | head -n 1)"
  last_frame="$(find "${OUTPUT_DIR}" -maxdepth 1 -type f -name 'frame_*.jpg' | sort | tail -n 1)"

  echo
  echo '== Extraction summary =='
  echo "Frames created: ${frame_count}"
  echo "First frame   : ${first_frame:-<none>}"
  echo "Last frame    : ${last_frame:-<none>}"

  if [[ "${frame_count}" -eq 0 ]]; then
    die_run 'Не извлечено ни одного кадра'
  fi

  printf '%s\n' '[OK] Frame extraction completed.'
}

main "${@}"
