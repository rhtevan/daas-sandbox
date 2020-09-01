#!/usr/bin/env bash

source "${DAAS_HOME}/launch/kubernetes-client.sh"

configure() {
    local index_js="/var/www/html/index.js"
    if [ -f "${index_js}" ]; then

        local app_name="${APPLICATION_NAME:-myapp}"

        local acceptor_route_name=${DAAS_ACCEPTOR_ROUTE_NAME:-${app_name}-daas-acceptor}
        local acceptor_hostname_http=${DAAS_ACCEPTOR_HOSTNAME_HTTP:-${HOSTNAME:-localhost}}
        local acceptor_backend_url=$(build_route_url "${acceptor_route_name}" "http" "${acceptor_hostname_http}" "80" "/modeler")

        sed -i "s,MODELER_BACKEND_URL,${acceptor_backend_url}," ${index_js}
        sed -i "s,MODELER_PROJECT_NAME,${app_name}," ${index_js}
        sed -i "s,MODELER_SAVE_DIRECTORY,src/main/resources," ${index_js}

        local executor_route_name=${DAAS_EXECUTOR_ROUTE_NAME:-${app_name}-daas-executor}
        local executor_hostname_http=${DAAS_EXECUTOR_HOSTNAME_HTTP:-${HOSTNAME:-localhost}}
        local executor_url=$(build_route_url "${executor_route_name}" "http" "${executor_hostname_http}" "80" "/docs/openapi.json")
        sed -i "s,EXECUTOR_URL,${executor_url}," ${index_js}

        # TODO: remove once the online-modeler code removes hardcoding of path
        sed -i "s, + \"/openapi\",," ${index_js}

    fi
}
