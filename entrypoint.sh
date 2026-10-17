#!/bin/sh

set -e

BACKUP_SCRIPT=/usr/local/bin/backup.sh

RUN_CMD="sh $BACKUP_SCRIPT"

# If DOPPLER_TOKEN is set, the backup runs under `doppler run`: secrets from the
# token's project/config (S3_* etc.) are injected into the environment. The CLI
# resolves project and config from the scoped service token itself.
# POSTGRES_* variables from the local .env always take precedence over Doppler
# (--preserve-env), and S3_* in .env remain only as a fallback for secrets
# that do not exist in the Doppler config.
if [ -n "${DOPPLER_TOKEN:-}" ]; then
  echo "DOPPLER_TOKEN is set: running under 'doppler run'..."
  echo "Local POSTGRES_* variables take precedence over Doppler secrets."
  RUN_CMD="doppler run --no-check-version --preserve-env POSTGRES_HOST,POSTGRES_PORT,POSTGRES_DATABASE,POSTGRES_USER,POSTGRES_PASSWORD -- sh $BACKUP_SCRIPT"
fi

if [ "${BACKUP_SCHEDULE:-}" = "" ]; then
  sh -c "$RUN_CMD"
else
  echo "$BACKUP_SCHEDULE $RUN_CMD" > /etc/crontabs/root
  sh -c "$RUN_CMD"
  exec crond -l 2 -f
fi
