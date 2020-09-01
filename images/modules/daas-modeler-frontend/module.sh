#!/bin/sh

set -e

SCRIPT_DIR=$(dirname $0)

install_module() {
    mkdir -p ${DAAS_HOME}/launch
    cp -v -r ${SCRIPT_DIR}/launch/* ${DAAS_HOME}/launch

    local modeler_frontend_dir=${DAAS_HOME}/modeler/frontend
    mkdir -p ${modeler_frontend_dir}
    unzip -q /tmp/artifacts/kogito-tooling_online-editor.zip -d ${modeler_frontend_dir}
}

install_module ${@}

unset SCRIPT_DIR
