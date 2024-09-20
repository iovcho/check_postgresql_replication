#!/bin/bash
## This script must be running on slave host via cronjob for example. 
## Version 1.0 . tested on PostgreSQL 11.2
## Set your correct settings bellow
PG_HOST="localhost"
PG_PORT="5432"
PG_USER="CHANGEME"
PG_PASSWORD="CHANGEME"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/CHANGEME_TO_YOUR_WEBHOOK"
## Lag tolerance - for example the slave server have a running backup scripts and when are running replication - 0 for no tolerance.
MAX_LAG_SECONDS=60

## Start the script

check_postgres_service() {
  if ! pg_isready -h $PG_HOST -p $PG_PORT > /dev/null 2>&1; then
    return 1
  else
    return 0
  fi
}

check_replication() {
  last_replay_time=$(PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d postgres -c "SELECT EXTRACT(EPOCH FROM now() - pg_last_xact_replay_timestamp()) AS lag;" -tA)

  if (( $(echo "$last_replay_time > $MAX_LAG_SECONDS" | bc -l) )); then
    return 1
  else
    return 0
  fi
}

send_slack_notification() {
  local message=$1
  payload=$(cat <<EOF
{
  "text": "$message"
}
EOF
)

  curl -X POST -H 'Content-type: application/json' --data "$payload" $SLACK_WEBHOOK_URL
}

# Check the services and replication
if ! check_postgres_service; then
  send_slack_notification "PostgreSQL service on slave $HOSTNAME is down on the server!"
elif ! check_replication; then
  send_slack_notification "PostgreSQL replication is down or behind the master on the slave $HOSTNAME server - $last_replay_time seconds behind master!"
else
  echo "PostgreSQL service is running and replication is working properly."
fi
