#!/usr/bin/env bash

configure() {
    local index_js="${DAAS_HOME}/modeler/backend/dist/index.js"
    if [ -f "${index_js}" ]; then

        local modeler_hooks_dir="${MODELER_HOOKS_DIR:-${DAAS_HOME}/modeler/hooks}"
        mkdir -p ${modeler_hooks_dir}
        sed -i "s,MODELER_HOOKS_DIR,${modeler_hooks_dir}/," ${index_js}

        local modeler_projects_dir="${MODELER_PROJECTS_DIR:-${DAAS_HOME}/modeler/projects}"
        mkdir -p ${modeler_projects_dir}
        sed -i "s,MODELER_PROJECTS_DIR,${modeler_projects_dir}/," ${index_js}

        sed -i "s,MODELER_PORT,9090," ${index_js}

        local app_name="${APPLICATION_NAME:-myapp}"
        local app_dir="${APPLICATION_PATH:-${DAAS_HOME}/apps/${app_name}}"
        local git_repo_dir="${modeler_projects_dir}/${app_name}.git"

        if [ ! -d "${git_repo_dir}" ]; then
            pushd . &> /dev/null

            mkdir -p ${git_repo_dir}
            cd ${git_repo_dir}

            git config --global user.email "daas@kiegroup.org"
            git config --global user.name "DaaS"

            # init the repo
            git init --bare
            # add git hook
            cat <<EOF > hooks/post-receive
#!/bin/sh
unset GIT_INDEX_FILE
export GIT_WORK_TREE="${app_dir}/"
export GIT_DIR="${git_repo_dir}"
git checkout -f
EOF
            chmod 775 hooks/post-receive

            # we need to add at least one file to it
            local git_temp_dir="/tmp/git_${app_name}"
            git clone "${git_repo_dir}" "${git_temp_dir}"
            cd ${git_temp_dir}
            mkdir -p src/main/resources
            touch src/main/resources/.gitkeep
            git add src/main/resources/.gitkeep
            git commit -m 'Initial commit'
            git push
            cd ..
            rm -rf ${git_temp_dir}

            popd &> /dev/null
        fi
    fi
}
