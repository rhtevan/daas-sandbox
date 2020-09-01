#!/bin/sh

set -e

SCRIPT_DIR=$(dirname $0)

install_module() {
    mkdir -p ${DAAS_HOME}/launch
    cp -v -r ${SCRIPT_DIR}/launch/* ${DAAS_HOME}/launch

    # can't install nodejs via dnf, since it's too old of a version
    tar --strip-components=1 -xvf /tmp/artifacts/node-v*-linux-x64.tar.xz --directory /usr/local

    local modeler_backend_dir=${DAAS_HOME}/modeler/backend
    mkdir -p ${modeler_backend_dir}
    unzip -q /tmp/artifacts/kogito-tooling_online-editor-backend.zip -d ${modeler_backend_dir}
}

install_module ${@}

unset SCRIPT_DIR
