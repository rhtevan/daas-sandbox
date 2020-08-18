#!/bin/sh

set -e

SCRIPT_DIR=$(dirname $0)

install_module() {
    mkdir -p ${DAAS_HOME}/launch
    cp -v -r ${SCRIPT_DIR}/launch/* ${DAAS_HOME}/launch

    mkdir -p /var/www/html
    # cp -v -r ${SCRIPT_DIR}/www/html/* /var/www/html

    # kogito online modeler
    git clone --single-branch --branch gh-pages https://github.com/kiegroup/kogito-online.git
    mv kogito-online/* /var/www/html
    rm -rf kogito-online

    for ch_dir in /etc/httpd /var/www /var/log/httpd /var/run/httpd /run/httpd ; do
        chown -R 1001:0 ${ch_dir} && chmod -R ug+rwx ${ch_dir}
    done

    # local http_host="${HTTP_HOST:-localhost}"
    local http_port="${HTTP_PORT:-8080}"
    local http_conf="/etc/httpd/conf/httpd.conf"

    sed -i "s/Listen 80/Listen 0.0.0.0:${http_port}/g" "${http_conf}"
    sed -i "s/#User apache/User daas/g" "${http_conf}"
    sed -i "s/#Group apache/Group root/g" "${http_conf}"
    # sed -i "s/#ServerName www.example.com:80/ServerName ${http_host}:${http_port}/g" "${http_conf}"
}

install_module ${@}
