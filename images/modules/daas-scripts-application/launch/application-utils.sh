#!/bin/bash

get_daas_home() {
    local daas_home=${DAAS_HOME:-/home/daas}
    if [ ! -d ${daas_home} ]; then
        # just for script testing
        daas_home="/tmp/daas"
    fi
    echo ${daas_home}
}

get_kubernetes_namespace() {
    local k8s_ns_file="/var/run/secrets/kubernetes.io/serviceaccount/namespace"
    if [ -f ${k8s_ns_file} ]; then
        cat ${k8s_ns_file}
    else
        # just for script testing
        echo "testns"
    fi
}

get_application_name() {
    echo ${APPLICATION_NAME:-${1:-DaaS}}
}

get_application_id() {
    # local uuid=$(uuidgen); uuid=${uuid^^}
    local k8s_ns=$(get_kubernetes_namespace)
    local app_name=$(get_application_name "${1}")
    local app_id="_${k8s_ns^^}-${app_name^^}"
    echo ${app_id}
}

get_application_directory() {
    local app_dir=${APPLICATION_PATH:-$(get_daas_home)/app}
    echo ${app_dir}
}

get_application_xmlns() {
    local app_id=$(get_application_id "${1}")
    local app_xmlns="https://github.com/kiegroup/drools/kie-dmn/${app_id}"
    echo "${app_xmlns}"
}

# replace_application_xmlns_in_file() {
#     local xml_file="${1}"
#     local app_xmlns=$(get_application_xmlns "${2}")
#     sed -i "s,xmlns=\"[^\"]*\",xmlns=\"${app_xmlns}\",g" "${xml_file}"
#     sed -i "s,namespace=\"[^\"]*\",namespace=\"${app_xmlns}\",g" "${xml_file}"
# }

# replace_application_xmlns_in_dir() {
#     local dir="${1}"
#     find "${dir}" -maxdepth 1 -name '*.dmn' -print0 | 
#     while IFS= read -r -d '' file; do
#         replace_application_xmlns_in_file "${file}"
#     done
# }
