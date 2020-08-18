#!/usr/bin/env bash

set -e

# import
source ${DAAS_HOME}/launch/logging.sh

# debug
if [ "${SCRIPT_DEBUG}" = "true" ] ; then
    set -x
    log_debug "Script debugging is enabled, allowing bash commands and their arguments to be printed as they are executed"
fi

# config (any configurations script that needs to run on image startup must be added here)
CONFIGURE_SCRIPTS=(
    ${DAAS_HOME}/launch/configure-user.sh
)
source ${DAAS_HOME}/launch/configure.sh
#############################################

log_info "Launching acceptor..."

# sourced by www/cgi-bin/webhook
env > ${DAAS_HOME}/env

exec /usr/sbin/httpd -DFOREGROUND
