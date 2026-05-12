#!/usr/bin/env bash
# Быстрая проверка окружения воркшопа (COLMAP ~3.9, FFmpeg, Python3, …).
set -euo pipefail

readonly SCRIPT_NAME='smoke_test.sh'
readonly SCRIPT_VERSION='1.1.0'

usage() {
  cat <<EOF
${SCRIPT_NAME} — проверка каталогов, бинарников и прав записи в /workspace.

Версия скрипта: ${SCRIPT_VERSION}

Использование:
  bash scripts/${SCRIPT_NAME} [опции]

Опции:
  -h, --help     справка
  -v, --version  версия скрипта

Примеры:
  bash scripts/${SCRIPT_NAME}
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
      --)
        shift
        if [[ "${#}" -gt 0 ]]; then
          printf '%s: неожиданные аргументы после --\n' "${SCRIPT_NAME}" >&2
          die_usage
        fi
        break
        ;;
      -*)
        printf '%s: неизвестная опция: %s\n' "${SCRIPT_NAME}" "${1}" >&2
        die_usage
        ;;
      *)
        printf '%s: неожиданный аргумент: %s\n' "${SCRIPT_NAME}" "${1}" >&2
        die_usage
        ;;
    esac
  done
}

main() {
  parse_args "${@}"

  echo '== Smoke test: COLMAP workshop environment =='

  echo
  echo '-- Check working directory --'
  pwd
  test -d /workspace || die_run '/workspace недоступен'
  pass '/workspace смонтирован'

  echo
  echo '-- Check required directories --'
  test -d /workspace/data || die_run 'нет каталога /workspace/data'
  test -d /workspace/data/video || die_run 'нет каталога /workspace/data/video'
  test -d /workspace/data/images || die_run 'нет каталога /workspace/data/images'
  test -d /workspace/data/workspace || die_run 'нет каталога /workspace/data/workspace'
  pass 'каталоги данных на месте'

  echo
  echo '-- Check input video --'
  test -f /workspace/data/video/sample.mp4 || die_run 'не найден /workspace/data/video/sample.mp4'
  pass 'sample.mp4 существует'

  echo
  echo '-- Check COLMAP --'
  command -v colmap >/dev/null 2>&1 || die_run 'colmap не найден в PATH'
  colmap -h >/dev/null 2>&1 || die_run 'colmap -h завершился с ошибкой'
  local colmap_line
  colmap_line="$(colmap help 2>&1 | head -n 1 || echo '')"
  printf '%s\n' "${colmap_line}"
  if [[ -n "${colmap_line}" && "${colmap_line}" != *'3.9'* ]]; then
    printf '%s\n' '[WARN] Документация воркшопа ориентирована на COLMAP 3.9; у вас другая сборка — при расхождении опций см. colmap help <команда>.' >&2
  fi
  pass 'colmap доступен'

  echo
  echo '-- Check FFmpeg --'
  command -v ffmpeg >/dev/null 2>&1 || die_run 'ffmpeg не найден в PATH'
  ffmpeg -version >/dev/null 2>&1 || die_run 'ffmpeg -version завершился с ошибкой'
  pass 'ffmpeg доступен'

  echo
  echo '-- Check Python --'
  if command -v python3 >/dev/null 2>&1; then
    python3 --version
    pass 'python3 доступен'
  else
    die_run 'python3 не найден в PATH'
  fi

  echo
  echo '-- Check sqlite3 --'
  command -v sqlite3 >/dev/null 2>&1 || die_run 'sqlite3 не найден в PATH'
  sqlite3 --version >/dev/null 2>&1 || die_run 'sqlite3 --version завершился с ошибкой'
  pass 'sqlite3 доступен'

  echo
  echo '-- Check write access --'
  touch /workspace/data/workspace/.write_test || die_run 'нет записи в /workspace/data/workspace'
  rm -f /workspace/data/workspace/.write_test || die_run 'не удалось удалить временный файл в /workspace/data/workspace'
  pass 'в workspace можно писать'

  echo
  printf '%s\n' 'All smoke tests passed.'
}

main "${@}"
