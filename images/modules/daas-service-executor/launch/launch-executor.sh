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
    ${DAAS_HOME}/launch/application-utils.sh
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

    source ${DAAS_HOME}/launch/application-utils.sh
    local app_dir=$(get_application_directory)
    local app_id=$(get_application_id)
    local app_name=$(get_application_name)
    local app_xmlns=$(get_application_xmlns)

    local app_parent_dir=$(dirname ${app_dir})
    if [ ! -d "${app_parent_dir}" ]; then
        mkdir -p ${app_parent_dir}
    fi
    cd ${app_parent_dir}

    local project_group_id="${APPLICATION_GROUP_ID:-org.kie.daas.application}"
    local project_artifact_id="${APPLICATION_ARTIFACT_ID:-${app_name}}"
    local project_version="${APPLICATION_VERSION:-1.0}"

    # local kogito_version="${KOGITO_VERSION:-0.15.0}"
    local kogito_version="${KOGITO_VERSION:-1.0.0-SNAPSHOT}"
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

    if [ "${app_parent_dir}/${project_artifact_id}" != "${app_dir}" ]; then
        mv "${app_parent_dir}/${project_artifact_id}" "${app_dir}"
    fi
    cd "${app_dir}"

    cat <<EOF > src/main/resources/${app_name}.dmn
<dmn:definitions
    xmlns:dmn="http://www.omg.org/spec/DMN/20180521/MODEL/"
    xmlns="${app_xmlns}"
    xmlns:di="http://www.omg.org/spec/DMN/20180521/DI/"
    xmlns:kie="http://www.drools.org/kie/dmn/1.2"
    xmlns:dmndi="http://www.omg.org/spec/DMN/20180521/DMNDI/"
    xmlns:dc="http://www.omg.org/spec/DMN/20180521/DC/"
    xmlns:feel="http://www.omg.org/spec/DMN/20180521/FEEL/"
    id="${app_id}"
    name="${app_name}"
    typeLanguage="http://www.omg.org/spec/DMN/20180521/FEEL/"
    namespace="${app_xmlns}">
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

        sed "s,<dependencies>,<dependencies>\n    <dependency><groupId>org.kie.kogito</groupId><artifactId>explainability-quarkus-addon</artifactId><version>${kogito_version}</version></dependency>," <pom.xml >pom.tmp
        mv pom.tmp pom.xml

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
        -DincludeScope=test \
        -Djacoco.skip=true \
        -Dmaven.javadoc.skip=true \
        -Dmaven.site.skip=true \
        -Dmaven.source.skip=true \
        -Dpmd.skip=true

    # quarkus.smallrye-openapi-path has to match what's in daas-modeler-frontent/launch/configure-modeler-frontend.sh
    cat <<EOF > src/main/resources/application.properties
kogito.decisions.stronglytyped=true
kogito.service.url=http://0.0.0.0:8080
quarkus.http.cors=true
quarkus.smallrye-openapi.path=/openapi
quarkus.swagger-ui.always-include=true
EOF
    mkdir -p src/test/resources
    cp -f src/main/resources/application.properties src/test/resources

    # stuff we don't need anymore
    rm -f src/main/resources/*.bpmn*
    rm -f src/main/resources/*.dmn
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

    source ${DAAS_HOME}/launch/application-utils.sh
    local app_dir=$(get_application_directory)

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
    exec mvn -e \
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
