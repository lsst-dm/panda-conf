#!/bin/bash

rootDir=$1
myDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function log() {
    dt=$(date --utc +"%Y-%m-%d %H:%M:%S,%3N [PilotEnv]")
    echo "$dt $@"
}


function install_conda () {
    echo "installing PanDA conda env at $rootDir/conda"
    export PANDA_PILOT_CONDA_DIR=$rootDir/conda/install
    if [[ -d ${PANDA_PILOT_CONDA_DIR} ]]; then
        log "Found conda installed at: ${PANDA_PILOT_CONDA_DIR}"
    else
        mkdir -p $rootDir/conda
        if [[ -d $rootDir/conda ]]; then
            cd $rootDir/conda
            rm -f Miniconda3-latest-Linux-x86_64.sh
            wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
            chmod +x Miniconda3-latest-Linux-x86_64.sh
            log bash Miniconda3-latest-Linux-x86_64.sh -b -f -p ${PANDA_PILOT_CONDA_DIR}
            bash Miniconda3-latest-Linux-x86_64.sh -b -f -p ${PANDA_PILOT_CONDA_DIR}
            log "Installed conda at ${PANDA_PILOT_CONDA_DIR}"
        else
            log "Directory doesn't exist: $rootDir/conda"
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
        else
            log "${PANDA_PILOT_ENV_DIR} already existed"
            source ${PANDA_PILOT_CONDA_DIR}/bin/activate
            source activate pilot
            conda env update --file $myDir/pilot_environments.yaml
            conda install -y --name pilot --file pilot_requirements.txt
        fi
    else
        log "${PANDA_PILOT_CONDA_DIR} doesn't exist"
    fi
}


function setup_pilot_env () {
    echo "Setup PanDA pilot env"
    if [[ -d ${PANDA_PILOT_ENV_DIR} ]]; then
        source ${PANDA_PILOT_CONDA_DIR}/bin/activate
        source activate pilot
    else
        log "${PANDA_PILOT_ENV_DIR} doesn't exist"
    fi
}


function install_ca_certificates () {
    echo "Installing CA certificates"
    export PANDA_PILOT_CA_DIR=$rootDir/certificates

    mkdir -p ${PANDA_PILOT_CA_DIR}

    TMPDIR=`mktemp -d`
    cd $TMPDIR

    wget -l1 -r -np -nH --cut-dirs=7 http://repository.egi.eu/sw/production/cas/1/current/tgz/

    for tgz in $(ls *.tar.gz);
    do
        tar xzf ./$tgz --strip-components=1 -C ${PANDA_PILOT_CA_DIR}
    done

    cd -
    rm -rf $TMPDIR

    mkdir $rootDir/tools
    cd $rootDir/tools
    rm -f $rootDir/tools/fetch-crl
    wget https://dl.igtf.net/distribution/util/fetch-crl/fetch-crl
    chmod +x $rootDir/tools/fetch-crl

    cat <<- EOF > $rootDir/tools/fetch-crl.cron
20 4-23/6 * * * $rootDir/tools/fetch-crl --infodir ${PANDA_PILOT_CA_DIR}
EOF

    cd -

}


function install_panda_setup () {
    cat <<- EOF > $rootDir/setup_panda.sh
export PANDA_CONFIG_ROOT=$HOME
export PANDA_URL_SSL=https://pandaserver-doma.cern.ch:25443/server/panda
export PANDA_URL=http://pandaserver-doma.cern.ch:25080/server/panda
export PANDA_AUTH=oidc
export PANDA_VERIFY_HOST=off
export PANDA_AUTH_VO=Rubin
export IDDS_CONFIG=/cvmfs/sw.lsst.eu/linux-x86_64/lsst_distrib/w_2022_17/conda/envs/lsst-scipipe-3.0.0/etc/idds/idds.cfg.client.template
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
                unlink pilot3.tar.gz
                ln -s ${pilot_name} pilot3.tar.gz
            else
                log "Failed to install pilot: ${pilot_url}"
            fi
            cd -
        else
            log "Pilot already installed: ${dest_pilot}"
        fi
    else
        log "Pilot directory doesn't exist: ${PANDA_PILOT_DIR}"
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
                unlink runpilot3_wrapper.sh
                chmod +x ${pilot_wrapper_name}
                ln -s ${pilot_wrapper_name} runpilot3_wrapper.sh
            else
                log "Failed to install pilot wrapper: ${pilot_wrapper_url}"
            fi
            cd -
        else
            log "Pilot wrapper already installed: ${dest_wrapper_pilot}"
        fi
    else
        log "Pilot wrapper directory doesn't exist: ${PANDA_PILOT_WRAPPER_DIR}"
    fi
}

function main () {
    install_conda

    install_pilot_env

    setup_pilot_env

    install_ca_certificates

    install_pilot

    install_pilot_wrapper

    install_panda_setup
}


main
