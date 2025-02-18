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
    # setup panda
    cat <<- EOF > $rootDir/setup_panda.sh
#!/bin/bash

echo "Setup BPS USDF PanDA (at SLAC K8S) environment"

# setup PanDA env. Will be a simple step when the deployment of PanDA is fully done.
export PANDA_CONFIG_ROOT=\$HOME/.panda
export PANDA_URL_SSL=https://usdf-panda-server.slac.stanford.edu:8443/server/panda
export PANDA_URL=https://usdf-panda-server.slac.stanford.edu:8443/server/panda
export PANDACACHE_URL=\$PANDA_URL_SSL
export PANDAMON_URL=https://usdf-panda-bigmon.slac.stanford.edu:8443/
export PANDA_AUTH=oidc
export PANDA_VERIFY_HOST=off
export PANDA_AUTH_VO=Rubin

export PANDA_BEHIND_REAL_LB=true

# IDDS_CONFIG path depends on the weekly version
export PANDA_SYS=\$CONDA_PREFIX
export IDDS_CONFIG=\${PANDA_SYS}/etc/idds/idds.cfg.client.template

export IDDS_MAX_NAME_LENGTH=30000

# WMS plugin
export BPS_WMS_SERVICE_CLASS=lsst.ctrl.bps.panda.PanDAService
EOF
    chmod +x $rootDir/setup_panda.sh

    cat <<- EOF > $rootDir/setup_panda_cern.sh
#!/bin/bash

echo "Setup BPS DOMA PanDA (at CERN) environment"
# setup PanDA env. Will be a simple step when the deployment of PanDA is fully done.
export PANDA_CONFIG_ROOT=\$HOME/.panda
export PANDA_URL_SSL=https://pandaserver-doma.cern.ch:25443/server/panda
export PANDA_URL=http://pandaserver-doma.cern.ch:25080/server/panda
export PANDACACHE_URL=\$PANDA_URL_SSL
export PANDAMON_URL=https://panda-doma.cern.ch
export PANDA_AUTH=oidc
export PANDA_VERIFY_HOST=off
export PANDA_AUTH_VO=Rubin

# IDDS_CONFIG path depends on the weekly version
export PANDA_SYS=\$CONDA_PREFIX
export IDDS_CONFIG=\${PANDA_SYS}/etc/idds/idds.cfg.client.template

export IDDS_MAX_NAME_LENGTH=4000

# WMS plugin
export BPS_WMS_SERVICE_CLASS=lsst.ctrl.bps.panda.PanDAService
EOF
    chmod +x $rootDir/setup_panda_cern.sh

    cat <<- EOF > $rootDir/setup_panda_usdf.sh
#!/bin/bash

echo "Setup BPS USDF PanDA (at SLAC K8S) environment"

# setup PanDA env. Will be a simple step when the deployment of PanDA is fully done.
export PANDA_CONFIG_ROOT=\$HOME/.panda
export PANDA_URL_SSL=https://usdf-panda-server.slac.stanford.edu:8443/server/panda
export PANDA_URL=https://usdf-panda-server.slac.stanford.edu:8443/server/panda
export PANDACACHE_URL=\$PANDA_URL_SSL
export PANDAMON_URL=https://usdf-panda-bigmon.slac.stanford.edu:8443/
export PANDA_AUTH=oidc
export PANDA_VERIFY_HOST=off
export PANDA_AUTH_VO=Rubin

export PANDA_BEHIND_REAL_LB=true

# IDDS_CONFIG path depends on the weekly version
export PANDA_SYS=\$CONDA_PREFIX
export IDDS_CONFIG=\${PANDA_SYS}/etc/idds/idds.cfg.client.template

export IDDS_MAX_NAME_LENGTH=30000

# WMS plugin
export BPS_WMS_SERVICE_CLASS=lsst.ctrl.bps.panda.PanDAService
EOF
    chmod +x $rootDir/setup_panda_usdf.sh

    cat <<- EOF > $rootDir/setup_panda_usdf_dev.sh
#!/bin/bash

echo "Setup BPS USDF DEV PanDA (at SLAC K8S) environment."
echo "It's for PanDA system development and tests."

# setup PanDA env. Will be a simple step when the deployment of PanDA is fully done.
export PANDA_CONFIG_ROOT=\$HOME/.panda_usdf_dev
export PANDA_URL_SSL=https://rubin-panda-server-dev.slac.stanford.edu:8443/server/panda
export PANDA_URL=https://rubin-panda-server-dev.slac.stanford.edu:8443/server/panda
export PANDACACHE_URL=\$PANDA_URL_SSL
export PANDAMON_URL=https://rubin-panda-bigmon-dev.slac.stanford.edu:8443/
export PANDA_AUTH=oidc
export PANDA_VERIFY_HOST=off
export PANDA_AUTH_VO=Rubin

export PANDA_BEHIND_REAL_LB=true

# IDDS_CONFIG path depends on the weekly version
export PANDA_SYS=\$CONDA_PREFIX
export IDDS_CONFIG=\${PANDA_SYS}/etc/idds/idds.cfg.client.template

export IDDS_MAX_NAME_LENGTH=30000

# WMS plugin
export BPS_WMS_SERVICE_CLASS=lsst.ctrl.bps.panda.PanDAService
EOF
    chmod +x $rootDir/setup_panda_usdf_dev.sh
}


function install_lsst_setup () {
    # setup panda
    cat <<- EOF > $rootDir/setup_lsst.sh
#!/bin/bash
if [ "\$#" -ne 1 ]; then
    echo "lsst_distrib version is required."
    echo "example: source setup_panda.sh w_2022_35"
else
    # setup Rubin env
    # export LSST_VERSION=w_2022_35
    export LSST_VERSION=\$1
    echo "setup lsst_distrib to \${LSST_VERSION}"

    if [ -n "\$LSST_ARCH" ]; then
        LSST_ARCH_TEMP=\${LSST_ARCH}
        echo "LSST_ARCH is already set to \${LSST_ARCH_TEMP}."
    elif [[ "\$LSST_VERSION" < "w_2025_01" ]]; then
        export LSST_ARCH_TEMP="linux-x86_64"
        echo "LSST_VERSION is lower than w_2025_01, setting LSST_ARCH to \${LSST_ARCH_TEMP}"
    else
        export LSST_ARCH_TEMP="almalinux-x86_64"
        echo "LSST_VERSION is greater than or equal to w_2025_01, setting LSST_ARCH to \${LSST_ARCH_TEMP}"
    fi

    # Load LSST environment
    LSST_SETUP_PATH="/cvmfs/sw.lsst.eu/\${LSST_ARCH_TEMP}/lsst_distrib/\${LSST_VERSION}/loadLSST.bash"

    unset LSST_ARCH_TEMP

    if [ -f "\$LSST_SETUP_PATH" ]; then
        source "\$LSST_SETUP_PATH"
        setup lsst_distrib
    else
        echo "Error: LSST setup script not found at \${LSST_SETUP_PATH}"
        return 1
    fi
fi
EOF
    chmod +x $rootDir/setup_lsst.sh
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

    echo "Installing pilot default config"
    cp $myDir/pilot_default.cfg ${PANDA_PILOT_DIR}
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

function install_bps () {
    echo "Installing ctrl_bps and ctrl_bps_panda, tickets/DM-38138"
    export BPS_DIR=${rootDir}/bps
    mkdir -p ${BPS_DIR}

    # tarfile=https://github.com/zhaoyuyoung/shared_files/raw/main/DM-38138.tar.gz
    tarfile=https://github.com/wguanicedew/share_files/raw/main/DM-38138.tar.gz
    if [[ -d ${BPS_DIR} ]]; then
    	cd $BPS_DIR
        wget $tarfile
        tar -xzf DM-38138.tar.gz
        mv DM-38138/* .
        rm -rf DM-38138*
        cd -
    else
        log "<<<<<<ERROR>>>>>>: BPS directory doesn't exist: ${BPS_DIR}. exit."
        exit 1
    fi

    echo "ctrl_bps and ctrl_bps_panda has been installed to $BPS_DIR"
}

function install_bps_setup () {
    # setup bps
    cat <<- EOF > $rootDir/setup_bps.sh
#!/bin/bash

# no need local bps version anymore
# setup -j -r $rootDir/bps/ctrl_bps
# setup -j -r $rootDir/bps/ctrl_bps_panda

EOF
chmod +x $rootDir/setup_bps.sh
}

function install_cric () {
    echo "Installing cric panda queues and ddm endpoints on cvmfs"
    export CRIC_DIR=${rootDir}/cric
    mkdir -p ${CRIC_DIR}
    cd ${CRIC_DIR}
    wget --no-check-certificate https://datalake-cric.cern.ch/api/atlas/ddmendpoint/query/?json -O datalake-cric-ddm.json
    wget --no-check-certificate https://datalake-cric.cern.ch/api/atlas/pandaqueue/query/?json -O datalake-cric-pandaqueue.json
    cd -
    echo "cric panda queues and ddm endpoints installed on cvmfs"
}

function install_rucio () {
    echo "Installing rucio config files on cvmfs"
    export RUCIO_DIR=${rootDir}/rucio
    mkdir -p ${RUCIO_DIR}
    cd ${RUCIO_DIR}

    cp $myDir/rucio.cfg ${RUCIO_DIR}/
    cp $myDir/rucio-rubin.cfg ${RUCIO_DIR}/
    cp $myDir/rucio-rubin-dev.cfg ${RUCIO_DIR}/

    cd -
    echo "rucio config installed on cvmfs"
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

    install_lsst_setup

    # install_bps

    install_bps_setup

    install_cric

    install_rucio

    exit 0
}


main
