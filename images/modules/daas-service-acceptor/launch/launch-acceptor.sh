#!/usr/bin/env bash

set -e

# import
source ${DAAS_HOME}/launch/logging.sh
source ${DAAS_HOME}/launch/application-utils.sh

# debug
if [ "${SCRIPT_DEBUG}" = "true" ] ; then
    set -x
    log_debug "Script debugging is enabled, allowing bash commands and their arguments to be printed as they are executed"
fi

# config (any configurations script that needs to run on image startup must be added here)
CONFIGURE_SCRIPTS=(
    ${DAAS_HOME}/launch/configure-user.sh
    ${DAAS_HOME}/launch/configure-modeler-backend.sh
)
source ${DAAS_HOME}/launch/configure.sh
#############################################

log_info "Launching acceptor..."

# sourced by www/cgi-bin/webhook
env > ${DAAS_HOME}/env

MODELS_DIR="$(get_application_directory)/src/main/resources"
mkdir -p ${MODELS_DIR}

WEBDAV_CONF="/etc/httpd/conf.d/webdav.conf"
if [ -f "${WEBDAV_CONF}" ]; then
    sed -i "s,MODELS_DIR,${MODELS_DIR},g" "${WEBDAV_CONF}"
fi

BACKEND_DIR="${DAAS_HOME}/modeler/backend"
if [ -d "${BACKEND_DIR}" ]; then
    # run apache in background
    /usr/sbin/httpd
    # run node in foreground
    cd ${BACKEND_DIR}
    exec node dist/index.js 2>&1
else
    # run apache in foreground
    exec /usr/sbin/httpd -DFOREGROUND
fi
