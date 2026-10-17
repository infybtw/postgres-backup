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
# NOTE: --preserve-env requires the value to be passed with an equals sign
# (--preserve-env="FOO,BAR"); a space-separated value is silently treated as
# "true" and the variable list becomes the command to execute.
if [ -n "${DOPPLER_TOKEN:-}" ]; then
  echo "DOPPLER_TOKEN is set: running under 'doppler run'..."
  echo "Local POSTGRES_* variables take precedence over Doppler secrets."
  RUN_CMD="doppler run --no-check-version --preserve-env=POSTGRES_HOST,POSTGRES_PORT,POSTGRES_DATABASE,POSTGRES_USER,POSTGRES_PASSWORD -- sh $BACKUP_SCRIPT"
fi

if [ "${BACKUP_SCHEDULE:-}" = "" ]; then
  sh -c "$RUN_CMD"
else
  CRON_CMD="$RUN_CMD"
  if [ -n "${DOPPLER_TOKEN:-}" ]; then
    # crond runs jobs with a minimal environment, so the token must be
    # exported inline for scheduled runs to be able to reach Doppler.
    ESCAPED_TOKEN=$(printf '%s' "$DOPPLER_TOKEN" | sed "s/'/'\\\\''/g")
    CRON_CMD="export DOPPLER_TOKEN='$ESCAPED_TOKEN'; $RUN_CMD"
  fi
  echo "$BACKUP_SCHEDULE $CRON_CMD" > /etc/crontabs/root
  sh -c "$RUN_CMD"
  exec crond -l 2 -f
fi
