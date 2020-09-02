#!/usr/bin/env bash

set -e

# import
source ${DAAS_HOME}/launch/logging.sh

# debug
if [ "${SCRIPT_DEBUG}" = "true" ] ; then
    set -x
    SHOW_JVM_SETTINGS="-XshowSettings:properties"
    log_info "Script debugging is enabled, allowing bash commands and their arguments to be printed as they are executed"
    log_info "JVM settings debug is enabled."
fi

# config (any configurations script that needs to run on image startup must be added here)
CONFIGURE_SCRIPTS=(
    ${DAAS_HOME}/launch/configure-user.sh
    ${DAAS_HOME}/launch/configure-maven.sh
    /opt/run-java/proxy-options
)
source ${DAAS_HOME}/launch/configure.sh

#############################################

# for JVM property settings please refer to this link:
# https://github.com/jboss-openshift/cct_module/blob/master/jboss/container/java/jvm/api/module.yaml
# source /usr/local/dynamic-resources/dynamic_resources.sh
# JAVA_OPTS="$(adjust_java_options ${JAVA_OPTS})"
# log_debug "exec ${JAVA_HOME}/bin/java ${SHOW_JVM_SETTINGS} ${JAVA_OPTS} ${JAVA_OPTS_APPEND} ${JAVA_PROXY_OPTIONS} ${DAAS_OPTS} -jar /path/to/todo.jar"

#############################################

assemble_executor() {
    log_info "Building executor..."

    local app_name="${APPLICATION_NAME:-myapp}"
    local app_dir=${APPLICATION_PATH:-${DAAS_HOME}/apps/${app_name}}

    local apps_dir=$(dirname ${app_dir})
    mkdir -p ${apps_dir}
    cd ${apps_dir}

    local project_group_id="${APPLICATION_GROUP_ID:-org.kie.daas.application}"
    local project_artifact_id="${APPLICATION_ARTIFACT_ID:-${app_name}}"
    local project_version="${APPLICATION_VERSION:-1.0}"

    local kogito_version="${KOGITO_VERSION:-0.12.0}"
    local m2_dir=${DAAS_HOME}/.m2

    mvn -e \
        archetype:generate \
        -s ${m2_dir}/settings.xml \
        --batch-mode \
        -DarchetypeGroupId=org.kie.kogito \
        -DarchetypeArtifactId=kogito-quarkus-archetype \
        -DarchetypeVersion=${kogito_version} \
        -DgroupId=${project_group_id} \
        -DartifactId=${project_artifact_id} \
        -Dversion=${project_version}

    if [ "${project_artifact_id}" != "${app_name}" ]; then
        mv "${project_artifact_id}" "${app_name}"
    fi
    cd ${app_name}

    local app_ns=$(uuidgen); app_ns=${app_ns^^}
    # local app_id=$(uuidgen); app_id=${app_id^^}
    local app_id=${app_name}
    cat <<EOF > src/main/resources/${app_name}.dmn
<dmn:definitions
    xmlns:dmn="http://www.omg.org/spec/DMN/20180521/MODEL/"
    xmlns="https://kiegroup.org/dmn/_${app_ns}"
    xmlns:di="http://www.omg.org/spec/DMN/20180521/DI/"
    xmlns:kie="http://www.drools.org/kie/dmn/1.2"
    xmlns:dmndi="http://www.omg.org/spec/DMN/20180521/DMNDI/"
    xmlns:dc="http://www.omg.org/spec/DMN/20180521/DC/"
    xmlns:feel="http://www.omg.org/spec/DMN/20180521/FEEL/"
    id="${app_id}"
    name="${app_name}"
    typeLanguage="http://www.omg.org/spec/DMN/20180521/FEEL/"
    namespace="https://kiegroup.org/dmn/_${app_ns}">
  <dmn:extensionElements/>
  <dmndi:DMNDI>
    <dmndi:DMNDiagram>
      <di:extension>
        <kie:ComponentsWidthsExtension/>
      </di:extension>
    </dmndi:DMNDiagram>
  </dmndi:DMNDI>
</dmn:definitions>
EOF
    
    mvn -e \
        dependency:resolve \
        dependency:resolve-plugins \
        dependency:go-offline \
        clean \
        compile \
        test \
        package \
        -f pom.xml \
        -s ${m2_dir}/settings.xml \
        --batch-mode \
        -Dcheckstyle.skip=true \
        -Dfabric8.skip=true \
        -Dfindbugs.skip=true \
        -Djacoco.skip=true \
        -DincludeScope=test \
        -Dmaven.javadoc.skip=true \
        -Dmaven.site.skip=true \
        -Dmaven.source.skip=true \
        -Dpmd.skip=true

    local app_props="src/main/resources/application.properties"
    sed -i 's/localhost/0.0.0.0/g' ${app_props}
    echo "\nkogito.decisions.stronglytyped=true" >> ${app_props}

    rm -f src/main/resources/*.bpmn*
    rm -rf src/test/java/*
    rm -rf /tmp/vertx-cache

    for D in ${app_dir} ${m2_dir} ; do
        chmod -R 777 ${D}
    done

    # NOTE: "resources" is the mount point, so move s2i items out of the way (see below)
    mv ${app_dir}/src/main/resources ${app_dir}/src/main/resources.s2i
}

run_executor() {
    log_info "Launching executor..."

    local app_name="${APPLICATION_NAME:-myapp}"
    local app_dir=${APPLICATION_PATH:-${DAAS_HOME}/apps/${app_name}}

    # NOTE: "resources" is the mount point, so move s2i items back if needed (see above)
    local res_dir=${app_dir}/src/main/resources
    local res_s2i_dir=${res_dir}.s2i
    cd ${res_s2i_dir}
    for R in $(ls) ; do
        if [ ! -e "${res_dir}/${R}" ]; then
            mv ${R} ${res_dir}
        fi
    done
    cd ${app_dir}
    rm -rf ${res_s2i_dir}

    cd ${app_dir}
    local m2_dir=${DAAS_HOME}/.m2
    exec mvn -e -o \
        clean \
        compile \
        quarkus:dev \
        -f pom.xml \
        -s ${m2_dir}/settings.xml \
        -Ddebug=false \
        -Dmaven.test.skip \
        -DnoDeps \
        -Dquarkus.http.host=0.0.0.0 \
        -Dquarkus.http.port=${HTTP_PORT:-8080} \
        -DskipTests

        # -Djava.library.path=${DAAS_HOME}/ssl-libs \
        # -Djavax.net.ssl.trustStore=${DAAS_HOME}/cacerts \
        # --no-transfer-progress
}

#############################################

# FIXME: not sure why I have to do this...
export PATH="${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}"

DAAS_EXECUTOR_ACTION="${1-run}"

if [ "${DAAS_EXECUTOR_ACTION}" = "assemble" ]; then
    assemble_executor
elif [ "${DAAS_EXECUTOR_ACTION}" = "run" ]; then
    run_executor
else
    log_error "Unrecognized DaaS Executor action: ${DAAS_EXECUTOR_ACTION}"
    exit 1
fi
