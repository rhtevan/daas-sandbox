#!/bin/sh

set -e

SCRIPT_DIR=$(dirname $0)

install_module() {
    # ----------------------------------------------------------------
    # launch scripts

    mkdir -p ${DAAS_HOME}/launch
    cp -v -r ${SCRIPT_DIR}/launch/* ${DAAS_HOME}/launch

    # ----------------------------------------------------------------
    # shared httpd config

    local http_conf="/etc/httpd/conf/httpd.conf"
    # local http_host="${HTTP_HOST:-localhost}"
    local http_port="${HTTP_PORT:-8080}"

    sed -i "s/Listen 80/Listen 0.0.0.0:${http_port}/g" "${http_conf}"
    sed -i "s/#User apache/User daas/g" "${http_conf}"
    sed -i "s/#Group apache/Group root/g" "${http_conf}"
    # sed -i "s/#ServerName www.example.com:80/ServerName ${http_host}:${http_port}/g" "${http_conf}"

    # ----------------------------------------------------------------
    # acceptor frontend (stub html)

    mkdir -p /var/www/html
    cp -v -r ${SCRIPT_DIR}/www/html/* /var/www/html

    # ----------------------------------------------------------------
    # accept via: kogito-tooling online-editor-backend

    echo 'ProxyPass "/modeler" "http://127.0.0.1:9090"' >> "${http_conf}"

    # ----------------------------------------------------------------
    # accept via: git webhook

    mkdir -p /var/www/cgi-bin
    cp -v -r ${SCRIPT_DIR}/www/cgi-bin/* /var/www/cgi-bin

    # ----------------------------------------------------------------
    # accept via: webdav

    mkdir -p /etc/httpd/conf.d
    cp -v -r ${SCRIPT_DIR}/conf.d/* /etc/httpd/conf.d

    # ----------------------------------------------------------------
    # permissions

    for ch_dir in /etc/httpd /var/www /var/log/httpd /var/run/httpd /run/httpd ; do
        chown -R 1001:0 ${ch_dir} && chmod -R ug+rwx ${ch_dir}
    done
}

install_module ${@}
