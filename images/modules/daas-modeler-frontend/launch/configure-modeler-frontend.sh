#!/usr/bin/env bash

source "${DAAS_HOME}/launch/application-utils.sh"
source "${DAAS_HOME}/launch/kubernetes-client.sh"

configure() {
    local index_js="/var/www/html/index.js"
    if [ -f "${index_js}" ]; then

        local app_name=$(get_application_name)
        local k8s_ns=$(get_kubernetes_namespace)

        local acceptor_route_name=${DAAS_ACCEPTOR_ROUTE_NAME:-${app_name}-daas-acceptor}
        local acceptor_hostname_http=${DAAS_ACCEPTOR_HOSTNAME_HTTP:-${HOSTNAME:-localhost}}
        local modeler_server_backendurl=$(build_route_url "${acceptor_route_name}" "http" "${acceptor_hostname_http}" "80" "/modeler")

        sed -i "s,MODELER_SERVER_BACKENDURL,${modeler_server_backendurl},g" ${index_js}
        sed -i "s,MODELER_SERVER_PROJECTNAME,${app_name},g" ${index_js}
        # empty to save in root directory of the git repo
        sed -i "s,MODELER_SERVER_SAVEDIRECTORY,,g" ${index_js}

        local executor_route_name=${DAAS_EXECUTOR_ROUTE_NAME:-${app_name}-daas-executor}
        local executor_hostname_http=${DAAS_EXECUTOR_HOSTNAME_HTTP:-${HOSTNAME:-localhost}}
        local modeler_openapi_url=$(build_route_url "${executor_route_name}" "http" "${executor_hostname_http}" "80" "")

        sed -i "s,MODELER_OPENAPI_URL,${modeler_openapi_url},g" ${index_js}
        # below has to match the quarkus.smallrye-openapi.path property set in launch-executor.sh
        sed -i "s,MODELER_OPENAPI_SPECPATH,/openapi,g" ${index_js}

        # TODO: remove hardcoded sections of this url
        local workflow_publish_url="http://el-${app_name}-workflow-${k8s_ns}.apps-crc.testing"

        sed -i "s,MODELER_PUBLISH_URL,${workflow_publish_url},g" ${index_js}
        sed -i "s,MODELER_PUBLISH_APPNAME,${app_name},g" ${index_js}
        sed -i "s,MODELER_PUBLISH_ENVNAME,${k8s_ns},g" ${index_js}

    fi
}
