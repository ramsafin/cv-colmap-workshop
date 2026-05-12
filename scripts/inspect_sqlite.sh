#!/usr/bin/env bash
# Просмотр служебных таблиц database.db (COLMAP 3.x / SQLite).
set -euo pipefail

readonly SCRIPT_NAME='inspect_sqlite.sh'
readonly SCRIPT_VERSION='1.0.0'

DB_PATH='/workspace/data/workspace/database.db'
DB_FROM_FLAG=''
DB_FROM_POS=''

usage() {
  cat <<EOF
${SCRIPT_NAME} — просмотр SQLite-базы COLMAP (таблицы, счётчики строк).

Версия скрипта: ${SCRIPT_VERSION}

Использование:
  bash scripts/${SCRIPT_NAME} [опции]
  bash scripts/${SCRIPT_NAME} [опции] -- [путь_к_database.db]

Опции:
  -h, --help              справка
  -v, --version             версия скрипта
  -d, --database PATH       файл SQLite

Позиционный аргумент после -- или без флагов:
  путь к database.db (нельзя комбинировать с -d)

Примеры:
  bash scripts/${SCRIPT_NAME} --help
  bash scripts/${SCRIPT_NAME}
  bash scripts/${SCRIPT_NAME} -d /workspace/data/workspace/backup_database.db
  bash scripts/${SCRIPT_NAME} -- /workspace/data/workspace/database.db
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
      -d | --database)
        require_arg "${@}"
        DB_PATH="${2}"
        DB_FROM_FLAG=1
        shift 2
        ;;
      --)
        shift
        while [[ "${#}" -gt 0 ]]; do
          if [[ -n "${DB_FROM_POS}" ]]; then
            printf '%s: после -- ожидается один путь к базе\n' "${SCRIPT_NAME}" >&2
            die_usage
          fi
          DB_FROM_POS="${1}"
          shift
        done
        break
        ;;
      -*)
        printf '%s: неизвестная опция: %s\n' "${SCRIPT_NAME}" "${1}" >&2
        die_usage
        ;;
      *)
        if [[ -n "${DB_FROM_POS}" ]]; then
          printf '%s: лишний позиционный аргумент: %s\n' "${SCRIPT_NAME}" "${1}" >&2
          die_usage
        fi
        DB_FROM_POS="${1}"
        shift
        ;;
    esac
  done

  if [[ -n "${DB_FROM_FLAG}" && -n "${DB_FROM_POS}" ]]; then
    printf '%s: нельзя одновременно указывать -d/--database и позиционный путь\n' "${SCRIPT_NAME}" >&2
    die_usage
  fi

  if [[ -n "${DB_FROM_POS}" ]]; then
    DB_PATH="${DB_FROM_POS}"
  fi
}

main() {
  parse_args "${@}"

  command -v sqlite3 >/dev/null 2>&1 || die_run 'sqlite3 не найден в PATH'
  test -f "${DB_PATH}" || die_run "Файл базы не найден: ${DB_PATH}"
  test -s "${DB_PATH}" || die_run "Файл базы пуст: ${DB_PATH}"

  local ver_line
  ver_line="$(sqlite3 "${DB_PATH}" 'SELECT sqlite_version();')"

  echo '== SQLite inspection =='
  echo "Database: ${DB_PATH}"
  ls -lh "${DB_PATH}"

  echo
  printf 'SQLite version: %s\n' "${ver_line}"

  echo
  echo '-- Tables --'
  sqlite3 "${DB_PATH}" '.tables'

  echo
  echo '-- Row counts (best effort) --'
  local table count
  for table in cameras images keypoints descriptors matches two_view_geometries; do
    if sqlite3 "${DB_PATH}" "SELECT name FROM sqlite_master WHERE type='table' AND name='${table}';" | grep -q "^${table}$"; then
      count="$(sqlite3 "${DB_PATH}" "SELECT COUNT(*) FROM ${table};")"
      printf '%s: %s\n' "${table}" "${count}"
    fi
  done
}

main "${@}"
