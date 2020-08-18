#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

usage() {
    echo ""
    echo "  Usage: image.sh [name] [action] [engine] [port]"
    echo ""
    echo "   name: the (abbreviated) image name (modeler, acceptor, executor)"
    echo " action: can be one of... build, shell, run, kill"
    echo " engine: for build action, default is 'buildah'; for shell, run, or kill actions, default is 'podman'"
    echo "   port: default is 8080 for modeler or acceptor, otherwise empty"
    echo ""
    echo "Example: ./image.sh acceptor build"
    echo ""
}

main() {
    pushd "${SCRIPT_DIR}" &> /dev/null

    local name="${1}"
    local action="${2}"
    local engine="${3}"
    local port="${4}"

    # local version="latest"
    local version="0.1"

    if [ "${name}" = "" ]; then
        echo "name required"
        usage
        return 1
    elif [ "${port}" = "" ] ; then
        if [ "${name}" = "modeler" ] || [ "${name}" = "acceptor" ] ; then
            port="8080"
        fi
    fi

    name="daas-${name}-ubi8"
    if [[ ${name} =~ .*executor.* ]]; then
        name="${name}-s2i"
    fi
    local image="quay.io/kiegroup/${name}:${version}"

    local desc_file="${SCRIPT_DIR}/${name}.yaml"
    if [ ! -f "${desc_file}" ]; then
        echo "image descriptor file '${desc_file}' does not exist"
        usage
        return 1
    fi

    local target_dir="${SCRIPT_DIR}/target/${name}"
    mkdir -p "${target_dir}"

    if [ "${engine}" = "" ]; then
        if [ "${action}" = "build" ]; then
            engine="buildah"
        else
            engine="podman"
        fi
    fi

    local cmd=""
    if [ "${action}" = "build" ]; then
        cmd="cekit -v --descriptor ${desc_file} --target ${target_dir} build ${engine}"
    elif [ "${action}" = "shell" ]; then
        if [ "${port}" = "" ]; then
            cmd="${engine} run -it --rm ${image} /bin/bash"
        else
            cmd="${engine} run -it -p ${port}:${port} --rm ${image} /bin/bash"
        fi
    elif [ "${action}" = "run" ]; then
        mkdir -p "${target_dir}"
        if [ "${port}" = "" ]; then
            cmd="${engine} run -dit --rm ${image} > ${target_dir}/image.cid"
        else
            cmd="${engine} run -dit -p ${port}:${port} --rm ${image} > ${target_dir}/image.cid"
        fi
    elif [ "${action}" = "kill" ]; then
        if [ -f "${target_dir}/image.cid" ]; then
            cmd="${engine} kill $(cat ${target_dir}/image.cid)"
        else
            echo "container id file '${target_dir}/image.cid' for image '${image}' does not exist"
        fi
    fi
    if [ "x${cmd}" != "x" ]; then
        echo "${cmd}"
        eval "${cmd}"
    else
        echo "unrecognized action"
        usage
        return 1
    fi

    popd &> /dev/null
}

main ${@}

unset SCRIPT_DIR
