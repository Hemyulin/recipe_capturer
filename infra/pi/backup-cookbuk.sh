#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${COOKBUK_DATA_DIR:-/srv/cookbuk/data}"
BACKUP_DIR="${COOKBUK_BACKUP_DIR:-/srv/cookbuk/backups}"
DATABASE_PATH="${DATA_DIR}/cookbuk.sqlite"
IMAGES_DIR="${DATA_DIR}/images"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "${BACKUP_DIR}"

if [[ ! -f "${DATABASE_PATH}" ]]; then
  echo "CookBuk database not found at ${DATABASE_PATH}" >&2
  exit 1
fi

sqlite3 "${DATABASE_PATH}" ".backup '${BACKUP_DIR}/cookbuk-${STAMP}.sqlite'"

if [[ -d "${IMAGES_DIR}" ]]; then
  tar -C "${DATA_DIR}" -czf "${BACKUP_DIR}/cookbuk-images-${STAMP}.tar.gz" images
fi

find "${BACKUP_DIR}" -type f -name "cookbuk-*.sqlite" -mtime +30 -delete
find "${BACKUP_DIR}" -type f -name "cookbuk-images-*.tar.gz" -mtime +30 -delete

echo "CookBuk backup written to ${BACKUP_DIR}"
