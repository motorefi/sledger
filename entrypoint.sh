#!/bin/bash

### ENVIRONMENT VARIABLES USED ###
# ISTIO_ENABLED - when set to true, waits for the Istio sidecar proxy to be up
#                 before running sledger
##################################

export PGPASSWORD=$DATABASE_MIGRATION_PASSWORD

function wait_for_db() {
   # before doing anything, wait for our sidecar to be up
   time_spent=0
   while [ "$time_spent" -lt "$DATABASE_PING_TIMEOUT" ] && ! pg_isready -h $DATABASE_HOST -p $DATABASE_PORT
   do
      time_spent=$((time_spent+1))
      >&2 echo "$(date) - waiting for database to start"
      sleep 1
   done   
}

function run_sledger() {
   # run sledger and capture exit code to exit with later
   /sledger
   result=$?
   
   # after sledger runs, kill the proxy
   if [ $(pgrep cloud_sql_proxy) ] && [ ${result} -eq 0 ]
   then
      pkill cloud_sql_proxy
   fi

   # kill command to terminate istio envoy proxy
   # this may fail silently if the Istio sidecar proxy is not there
   curl -fsI -X POST http://localhost:15000/quitquitquit

   exit $result
}

function wait_for_istio() {
   while ! curl -fsI http://localhost:15021/healthz/ready
   do
      echo "Waiting for Istio sidecar proxy..."
      sleep 1
   done
}

if [[ $# -gt 0 ]]; then
   exec $@
else
   wait_for_db
   if [ "$ISTIO_ENABLED" = true ]
   then
      wait_for_istio
   fi
   run_sledger
fi
