#!/bin/bash

# Variabili d'ambiente richieste (iniettate via env e secret nel CronJob):
#   MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE
#   S3_BUCKET, AWS_DEFAULT_REGION

set -euo pipefail

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
DUMP_FILE="/tmp/${MYSQL_DATABASE}_${TIMESTAMP}.sql.gz"

echo "[${TIMESTAMP}] Inizio backup di ${MYSQL_DATABASE}..."

mysqldump \
  -h "${MYSQL_HOST}" \
  -u "${MYSQL_USER}" \
  -p"${MYSQL_PASSWORD}" \
  "${MYSQL_DATABASE}" | gzip > "${DUMP_FILE}"

# i dump vengono caricati su S3 compressi e con SSE-KMS (Server-side encryption + AWS key management service)
aws s3 cp "${DUMP_FILE}" "s3://${S3_BUCKET}/mysql/${TIMESTAMP}/${MYSQL_DATABASE}.sql.gz" \
  --sse aws:kms

rm -f "${DUMP_FILE}"

echo "[$(date)] Backup completato: s3://${S3_BUCKET}/mysql/${TIMESTAMP}/${MYSQL_DATABASE}.sql.gz"

# -----------------------------------------------------------------------------
# Per schedulare questo script in Kubernetes si usa un CronJob che lo esegue periodicamente (es. ogni giorno alle 02:00 di mattina).
# Il manifest del CronJob monta lo script da una ConfigMap, inietta le credenziali da un Secret e
# usa un ServiceAccount con permesso s3:PutObject sul bucket di backup.
# -----------------------------------------------------------------------------
