#!/bin/sh

set -e

SCRIPT_DIR=$(dirname $0)

install_module() {
    # ----------------------------------------------------------------
    # launch scripts

    mkdir -p ${DAAS_HOME}/launch
    cp -v -r ${SCRIPT_DIR}/launch/* ${DAAS_HOME}/launch

    # ----------------------------------------------------------------
    # basic httpd config

    local http_conf="/etc/httpd/conf/httpd.conf"
    # local http_host="${HTTP_HOST:-localhost}"
    local http_port="${HTTP_PORT:-8080}"

    sed -i "s/Listen 80/Listen 0.0.0.0:${http_port}/g" "${http_conf}"
    sed -i "s/#User apache/User daas/g" "${http_conf}"
    sed -i "s/#Group apache/Group root/g" "${http_conf}"
    # sed -i "s/#ServerName www.example.com:80/ServerName ${http_host}:${http_port}/g" "${http_conf}"

    # ----------------------------------------------------------------
    # modeler frontend

    mkdir -p /var/www/html

    local modeler_frontend_dir=${DAAS_HOME}/modeler/frontend
    if [ -d "${modeler_frontend_dir}" ]; then
        cp -r ${modeler_frontend_dir}/dist/* /var/www/html
        rm -rf "${modeler_frontend_dir}"
    else
        # (stub html)
        cp -v -r ${SCRIPT_DIR}/www/html/* /var/www/html
    fi

    # ----------------------------------------------------------------
    # permissions

    for ch_dir in /etc/httpd /var/www /var/log/httpd /var/run/httpd /run/httpd ; do
        chown -R 1001:0 ${ch_dir} && chmod -R ug+rwx ${ch_dir}
    done
}

install_module ${@}
