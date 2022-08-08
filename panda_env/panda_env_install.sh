#!/bin/bash

rootDir=$1
myDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


if [[ -z ${rootDir} ]]; then
    echo "<<<<<<ERROR>>>>>>: root dir is not defined. run this script with 'bash panda_env_install.sh <rootDir>'. exit"
    exit
fi


function log() {
    dt=$(date --utc +"%Y-%m-%d %H:%M:%S,%3N [PilotEnv]")
    echo "$dt $@"
}


function check_wget() {
    if ! command -v wget &> /dev/null
    then
        echo "<<<<<<ERROR>>>>>>: wget could not be found. exit"
        exit 1
    fi

}

function install_conda () {
    echo "installing PanDA conda env at $rootDir/conda"
    export PANDA_PILOT_CONDA_DIR=$rootDir/conda/install
    if [[ -d ${PANDA_PILOT_CONDA_DIR} ]]; then
        log "<<<<<<WARN>>>>>>: Found conda installed at: ${PANDA_PILOT_CONDA_DIR}, not install anymore."
    else
        mkdir -p $rootDir/conda
        if [[ -d $rootDir/conda ]]; then
            cd $rootDir/conda
            rm -f Miniconda3-latest-Linux-x86_64.sh
            wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
            chmod +x Miniconda3-latest-Linux-x86_64.sh
            log bash Miniconda3-latest-Linux-x86_64.sh -b -f -p ${PANDA_PILOT_CONDA_DIR}
            bash Miniconda3-latest-Linux-x86_64.sh -b -f -p ${PANDA_PILOT_CONDA_DIR}
	    if [[ $? -ne 0 ]]; then
                log "<<<<<<ERROR>>>>>>: Failed to install conda. exit"
		exit 1
            fi
            log "Installed conda at ${PANDA_PILOT_CONDA_DIR}"
	    rm -f Miniconda3-latest-Linux-x86_64.sh
        else
            log "<<<<<<ERROR>>>>>>: Failed to create directory $rootDir/conda. exit."
	    exit 1
        fi
    fi
}


function install_pilot_env () {
    echo "installing PanDA pilot env"
    export PANDA_PILOT_ENV_DIR=${PANDA_PILOT_CONDA_DIR}/envs/pilot
    if [[ -d ${PANDA_PILOT_CONDA_DIR} ]]; then
        if ! [[ -d ${PANDA_PILOT_ENV_DIR} ]]; then
            source ${PANDA_PILOT_CONDA_DIR}/bin/activate
            conda config --add channels conda-forge
            conda env create -f $myDir/pilot_environments.yaml
	    if [[ $? -ne 0 ]]; then
                log "<<<<<<ERROR>>>>>>: Failed to install pilot env. exit"
                exit 1
            fi
        else
            log "${PANDA_PILOT_ENV_DIR} already existed"
            source ${PANDA_PILOT_CONDA_DIR}/bin/activate
            source activate pilot
            conda env update --file $myDir/pilot_environments.yaml
            conda install -y --name pilot --file pilot_requirements.txt
	    if [[ $? -ne 0 ]]; then
                log "<<<<<<ERROR>>>>>>: Failed to install pilot env. exit"
                exit 1
            fi
        fi
    else
        log "<<<<<<ERROR>>>>>>: ${PANDA_PILOT_CONDA_DIR} doesn't exist. conda is not installed. exit"
	exit 1
    fi
}


function setup_pilot_env () {
    echo "Setup PanDA pilot env"
    if [[ -d ${PANDA_PILOT_ENV_DIR} ]]; then
        source ${PANDA_PILOT_CONDA_DIR}/bin/activate
        source activate pilot
	if [[ $? -ne 0 ]]; then
            log "<<<<<<ERROR>>>>>>: Failed to setup pilot env. exit"
            exit 1
        fi
    else
        log "<<<<<<ERROR>>>>>>: ${PANDA_PILOT_ENV_DIR} doesn't exist. exit"
	exit 1
    fi
}


function install_panda_setup () {
    cat <<- EOF > $rootDir/setup_panda.sh
export PANDA_CONFIG_ROOT=\$HOME
export PANDA_URL_SSL=https://pandaserver-doma.cern.ch:25443/server/panda
export PANDA_URL=http://pandaserver-doma.cern.ch:25080/server/panda
export PANDA_AUTH=oidc
export PANDA_VERIFY_HOST=off
export PANDA_AUTH_VO=Rubin
EOF
    chmod +x $rootDir/setup_panda.sh
}


function install_pilot () {
    echo "Installing pilot.tar.gz"
    pilot_url=`cat $myDir/pilot_version.txt`
    export PANDA_PILOT_DIR=${rootDir}/pilot
    mkdir -p ${PANDA_PILOT_DIR}

    pilot_name="$(basename -- ${pilot_url})"
    dest_pilot=${PANDA_PILOT_DIR}/${pilot_name}
    if [[ -d ${PANDA_PILOT_DIR} ]]; then
        if ! [[ -f ${dest_pilot} ]]; then
            cd ${PANDA_PILOT_DIR}
            wget ${pilot_url}
            if [[ $? -eq 0 ]] && [[ -f ${dest_pilot} ]]; then
		if [ -f "pilot3.tar.gz" ]; then
                    unlink pilot3.tar.gz
                fi
                ln -s ${pilot_name} pilot3.tar.gz
		if [[ $? -ne 0 ]]; then
                    log "<<<<<<ERROR>>>>>>: Failed to install pilto. exit"
                    exit 1
                fi
            else
                log "<<<<<<ERROR>>>>>>: Failed to install pilot: ${pilot_url}. exit."
		exit 1
            fi
            cd -
        else
            log "<<<<<<WARN>>>>>>: Pilot already installed: ${dest_pilot}"
        fi
    else
        log "<<<<<<ERROR>>>>>>: Pilot directory doesn't exist: ${PANDA_PILOT_DIR}. exit."
	exit 1
    fi
}


function install_pilot_wrapper () {
    echo "Installing pilot wrapper"
    pilot_wrapper_url=`cat $myDir/pilot_wrapper.txt`
    export PANDA_PILOT_WRAPPER_DIR=${rootDir}/pilot/wrapper
    mkdir -p ${PANDA_PILOT_WRAPPER_DIR}

    pilot_wrapper_name="$(basename -- ${pilot_wrapper_url})"
    dest_wrapper_pilot=${PANDA_PILOT_WRAPPER_DIR}/${pilot_wrapper_name}
    if [[ -d ${PANDA_PILOT_WRAPPER_DIR} ]]; then
        if ! [[ -f ${dest_wrapper_pilot} ]]; then
            cd ${PANDA_PILOT_WRAPPER_DIR}
            wget ${pilot_wrapper_url}
            if [[ $? -eq 0 ]] && [[ -f ${dest_wrapper_pilot} ]]; then
		if [ -f "runpilot3_wrapper.sh" ]; then
                    unlink runpilot3_wrapper.sh
                fi
                chmod +x ${pilot_wrapper_name}
                ln -s ${pilot_wrapper_name} runpilot3_wrapper.sh
		if [[ $? -ne 0 ]]; then
                    log "<<<<<<ERROR>>>>>>: Failed to install pilto wrapper. exit"
                    exit 1
                fi
            else
                log "<<<<<<ERROR>>>>>>: Failed to install pilot wrapper: ${pilot_wrapper_url}.exit."
		exit 1
            fi
            cd -
        else
            log "<<<<<<WARN>>>>>>: Pilot wrapper already installed: ${dest_wrapper_pilot}"
        fi
    else
        log "<<<<<<ERROR>>>>>>: Pilot wrapper directory doesn't exist: ${PANDA_PILOT_WRAPPER_DIR}. exit."
	exit
    fi
}

function main () {
    check_wget

    install_conda

    install_pilot_env

    setup_pilot_env

    # install_ca_certificates

    install_pilot

    install_pilot_wrapper

    install_panda_setup
}


main
