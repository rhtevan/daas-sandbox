#!/bin/sh

set -e

SCRIPT_DIR=$(dirname $0)

install_module() {
    mkdir -p ${DAAS_HOME}/launch
    cp -v -r ${SCRIPT_DIR}/launch/* ${DAAS_HOME}/launch

    mkdir -p /var/www/html
    cp -v -r ${SCRIPT_DIR}/www/html/* /var/www/html

    mkdir -p /var/www/cgi-bin
    cp -v -r ${SCRIPT_DIR}/www/cgi-bin/* /var/www/cgi-bin

    local webdav_mount_path=${WEBDAV_MOUNT_PATH:-/var/www/webdav}
    mkdir -p ${webdav_mount_path}

    mkdir -p /etc/httpd/conf.d
    cp -v -r ${SCRIPT_DIR}/conf.d/* /etc/httpd/conf.d

    for ch_dir in /etc/httpd /var/www /var/log/httpd /var/run/httpd /run/httpd ${webdav_mount_path} ; do
        chown -R 1001:0 ${ch_dir} && chmod -R ug+rwx ${ch_dir}
    done

    # local http_host="${HTTP_HOST:-localhost}"
    local http_port="${HTTP_PORT:-8080}"
    local http_conf="/etc/httpd/conf/httpd.conf"

    sed -i "s/Listen 80/Listen 0.0.0.0:${http_port}/g" "${http_conf}"
    sed -i "s/#User apache/User daas/g" "${http_conf}"
    sed -i "s/#Group apache/Group root/g" "${http_conf}"
    # sed -i "s/#ServerName www.example.com:80/ServerName ${http_host}:${http_port}/g" "${http_conf}"

    local webdav_conf="/etc/httpd/conf.d/webdav.conf"
    sed -i "s,WEBDAV_MOUNT_PATH,${webdav_mount_path},g" "${webdav_conf}"
}

install_module ${@}
