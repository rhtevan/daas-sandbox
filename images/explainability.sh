#!/bin/sh

# Per instructions here: https://github.com/kostola/kogito-explainability-daas-poc

set -e

os_has_cmd() {
    local cmd=${1}
    if (which "${cmd}" > /dev/null 2>&1); then
        return 0
    else
        return 1
    fi
}

build_explainability_service() {
    git clone --recurse-submodules https://github.com/kostola/kogito-explainability-daas-poc.git
    cd kogito-explainability-daas-poc/kogito-apps/explainability/explainability-service-rest-daas
    mvn clean package -DskipTests -DskipITs
}

push_explainability_service() {
    local orig_name="org.kie.kogito/explainability-service-rest-daas:1.0.0-SNAPSHOT"

    local user_name="${USER:-${USERNAME}}"
    # hack
    if [ "${user_name}" = "dward" ]; then
        user_name="errantepiphany"
    fi
    local quay_name="quay.io/${user_name}/daas-explainability-ubi8:0.1"
    docker tag ${orig_name} ${quay_name}
    docker push ${quay_name}

    local crc_name="default-route-openshift-image-registry.apps-crc.testing/kiegroup/daas-explainability-ubi8:0.1"
    docker tag ${orig_name} ${crc_name}
    docker push ${crc_name}
}


main() {
    for cmd in git java mvn docker ; do
        if ! os_has_cmd ${cmd} ; then
            echo "Missing command: ${cmd}"
            return 1
        fi
    done

    pushd . &> /dev/null

    local build_dir="/tmp/explainability"
    if [ -d "${build_dir}" ]; then
        rm -rf ${build_dir}
    fi
    mkdir -p ${build_dir}
    cd ${build_dir}

    build_explainability_service
    push_explainability_service

    popd &> /dev/null
}

main ${@}
