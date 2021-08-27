#!/bin/bash

export acceptOTNLicenseAgreement="${1}"
export otnusername="${2}"
export otnpassword="${3}"
export jdkVersion="${4}"
export JAVA_HOME="${5}"
export TARGET_BINARY_FILE_NAME="${6}"
export TARGET_DOMAIN_FILE_NAME="${7}"
export ORACLE_HOME="${8}"
export DOMAIN_HOME="${9}"
export AZ_ACCOUNT_NAME="${10}"
export AZ_BLOB_CONTAINER="${11}"
export AZ_SAS_TOKEN="${12}"
export TMP_FILE_DIR="/u01/tmp"
export DOMAIN_ADMIN_USERNAME="${13}"
export DOMAIN_ADMIN_PASSWORD="${14}"
export SOURCE_HOST_NAME="${15}"
export TARGET_HOST_NAME="${16}"

function echo_stderr ()
{
    echo "$@" >&2
}

function validateInputs() {
    if [ -z "$acceptOTNLicenseAgreement" ]; then
        echo_stderr "acceptOTNLicenseAgreement is required. Value should be either Y/y or N/n"
        exit 1
    fi

    if [[ ! ${acceptOTNLicenseAgreement} =~ ^[Yy]$ ]]; then
        echo_stderr "acceptOTNLicenseAgreement value not specified as Y/y (yes). Exiting installation Weblogic Server process."
        exit 1
    fi

    if [[ -z "$otnusername" || -z "$otnpassword" ]]; then
        echo_stderr "otnusername or otnpassword is required. "
        exit 1
    fi

    if [ -z "$jdkVersion" ]; then
        echo_stderr "jdkVersion needs to be specified"
        exit 1
    fi

    if [ -z "$JAVA_HOME" ]; then
        echo_stderr "JAVA_HOME needs to be specified"
        exit 1
    fi

    if [ -z "$AZ_ACCOUNT_NAME" ]; then
        echo_stderr "AZ_ACCOUNT_NAME needs to be specified"
        exit 1
    fi

    if [ -z "$AZ_BLOB_CONTAINER" ]; then
        echo_stderr "AZ_BLOB_CONTAINER needs to be specified"
        exit 1
    fi

    if [ -z "$AZ_SAS_TOKEN" ]; then
        echo_stderr "AZ_SAS_TOKEN needs to be specified"
        exit 1
    fi

    if [ -z "$TARGET_DOMAIN_FILE_NAME" ]; then
        echo_stderr "TARGET_DOMAIN_FILE_NAME needs to be specified"
        exit 1
    fi

    if [ -z "$TARGET_BINARY_FILE_NAME" ]; then
        echo_stderr "TARGET_BINARY_FILE_NAME needs to be specified"
        exit 1
    fi

    if [ -z "$ORACLE_HOME" ]; then
        echo_stderr "ORACLE_HOME needs to be specified"
        exit 1
    fi

    if [ -z "$DOMAIN_HOME" ]; then
        echo_stderr "DOMAIN_HOME needs to be specified"
        exit 1
    fi
}

function addOracleGroupAndUser() {
    #add oracle group and user
    echo "Adding oracle user and group..."
    groupname="oracle"
    username="oracle"
    user_home_dir="/u01/oracle"
    USER_GROUP=${groupname}
    sudo groupadd $groupname
    sudo useradd -d ${user_home_dir} -g $groupname $username
}

function setupInstallPath() {
    export JDK_HOME=$(dirname "${JAVA_HOME}")
    export ORACLE_INSTALL_PATH=$(dirname $(dirname $(dirname ${ORACLE_HOME})))

    #create custom directory for setting up wls and jdk
    sudo mkdir -p $JDK_HOME
    sudo chown -R $username:$groupname $JDK_HOME
    sudo mkdir -p $ORACLE_INSTALL_PATH
    sudo chown -R $username:$groupname $ORACLE_INSTALL_PATH
    sudo mkdir -p $TMP_FILE_DIR
    sudo chown -R $username:$groupname $TMP_FILE_DIR

    sudo rm -rf $JDK_HOME/*
    sudo rm -rf $ORACLE_INSTALL_PATH/*
    sudo rm -rf $TMP_FILE_DIR/*
}

#Function to cleanup all temporary files
function cleanup() {
    echo "Cleaning up temporary files..."

    rm -f $TMP_FILE_DIR/jdk-11.0.9_linux-x64_bin.tar.gz

    rm -rf $JDK_HOME/jdk-11.0.9_linux-x64_bin.tar.gz

    
    rm -f ${TMP_FILE_DIR}/azcopy.tar.gz

    rm -rf ${TMP_FILE_DIR}/azcopy

    rm -f ${TMP_FILE_DIR}/${TARGET_DOMAIN_FILE_NAME}
    rm -f ${TMP_FILE_DIR}/${TARGET_BINARY_FILE_NAME}

    echo "Cleanup completed."
}

download_azcopy() {
    cd $TMP_FILE_DIR

    #URL reference from : https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10
    AZ_COPY_URL="https://aka.ms/downloadazcopy-v10-linux"

    if [ "$(uname)" == "Darwin" ]; then
        AZ_COPY_URL="https://aka.ms/downloadazcopy-v10-mac"
    fi

    # Some Linux machines will have curl, some will have wget; Some will have neither
    # Check which is available make download using the same
    if ! command -v wget &>/dev/null; then
        echo "Could not find wget; Trying with curl"

        if ! command -v curl &>/dev/null; then
            echo "No wget or curl found; Cannot download azcopy"
            exit
        else
            #important: always use -L to follow redirects; else curl will not download the file
            curl -L "${AZ_COPY_URL}" -o "${TMP_FILE_DIR}/azcopy.tar.gz"
        fi
    else
        echo "Found wget"
        wget "${AZ_COPY_URL}" -O "${TMP_FILE_DIR}/azcopy.tar.gz"
    fi

    mkdir ${TMP_FILE_DIR}/azcopy
    tar -xzvf "${TMP_FILE_DIR}/azcopy.tar.gz" --directory ${TMP_FILE_DIR}/azcopy

    cd ${TMP_FILE_DIR}/azcopy
    cd azcopy*

    AZ_COPY_PATH=$(pwd)
    cd $TMP_FILE_DIR
}

function installUtilities() {
    echo "Installing zip unzip wget vnc-server rng-tools"
    sudo yum install -y zip unzip wget vnc-server rng-tools

    #Setting up rngd utils
    sudo systemctl status rngd
    sudo systemctl start rngd
    sudo systemctl status rngd

    # Download & Install azcopy
    download_azcopy
}

#download jdk from OTN
function downloadJDK() {
    echo "Downloading jdk from OTN..."

    for in in {1..5}; do
        curl -s https://raw.githubusercontent.com/typekpb/oradown/master/oradown.sh | bash -s -- --cookie=accept-weblogicserver-server --username="${otnusername}" --password="${otnpassword}" https://download.oracle.com/otn/java/jdk/11.0.9+7/eec35ebefb3f4133bd045b891f05db94/jdk-11.0.9_linux-x64_bin.tar.gz
        tar -tzf $TMP_FILE_DIR/jdk-11.0.9_linux-x64_bin.tar.gz
        if [ $? != 0 ]; then
            echo "Download failed. Trying again..."
            rm -f $TMP_FILE_DIR/jdk-11.0.9_linux-x64_bin.tar.gz
        else
            echo "Downloaded JDK successfully"
            break
        fi
    done
}

function setupJDK() {
    echo "Setup JDK start"
    sudo cp $TMP_FILE_DIR/jdk-11.0.9_linux-x64_bin.tar.gz $JDK_HOME/jdk-11.0.9_linux-x64_bin.tar.gz

    echo "extracting and setting up jdk..."
    sudo tar -zxvf $JDK_HOME/jdk-11.0.9_linux-x64_bin.tar.gz --directory $JDK_HOME
    sudo chown -R $username:$groupname $JDK_HOME

    export PATH=$JAVA_HOME/bin:$PATH

    java -version

    if [ $? == 0 ]; then
        echo "JAVA HOME set succesfully."
    else
        echo_stderr "Failed to set JAVA_HOME. Please check logs and re-run the setup"
        exit 1
    fi
    echo "Setup JDK start"
}

function downloadMigrationData() {
    echo "Download migration data start"
    AZ_ACCOUNT_URI="https://$AZ_ACCOUNT_NAME.blob.core.windows.net"

    AZ_BLOB_TARGET="${AZ_ACCOUNT_URI}/${AZ_BLOB_CONTAINER}"

    AZ_DOMAIN_BLOB_SAS="${AZ_BLOB_TARGET}/${TARGET_DOMAIN_FILE_NAME}?${AZ_SAS_TOKEN}"
    AZ_BINARY_BLOB_SAS="${AZ_BLOB_TARGET}/${TARGET_BINARY_FILE_NAME}?${AZ_SAS_TOKEN}"

    echo "${AZ_BINARY_BLOB_SAS}"
    echo "${AZ_DOMAIN_BLOB_SAS}"
    echo "${TMP_FILE_DIR}/$TARGET_DOMAIN_FILE_NAME"
    echo "${TMP_FILE_DIR}/$TARGET_BINARY_FILE_NAME"

    $AZ_COPY_PATH/azcopy cp "${AZ_DOMAIN_BLOB_SAS}" "${TMP_FILE_DIR}/${TARGET_DOMAIN_FILE_NAME}"
    $AZ_COPY_PATH/azcopy cp "${AZ_BINARY_BLOB_SAS}" "${TMP_FILE_DIR}/${TARGET_BINARY_FILE_NAME}"
    echo "Download migration data end"
}

function create_oraInstloc()
{
    echo "creating Install Location Template..."

    cat <<EOF >$TMP_FILE_DIR/oraInst.loc.template
inventory_loc=[INSTALL_PATH]
inst_group=[GROUP]
EOF

    sed 's@\[INSTALL_PATH\]@'"$ORACLE_INSTALL_PATH"'@' ${TMP_FILE_DIR}/oraInst.loc.template > ${TMP_FILE_DIR}/oraInst.loc
    sed -i 's@\[GROUP\]@'"$USER_GROUP"'@' ${TMP_FILE_DIR}/oraInst.loc
}

function setupOracleBinaryAndDomain() 
{
    cmd="${JAVA_HOME}/bin/java -jar ${TMP_FILE_DIR}/${TARGET_BINARY_FILE_NAME} -targetOracleHomeLoc ${ORACLE_HOME} -invPtrLoc ${TMP_FILE_DIR}/oraInst.loc -javaHome ${JAVA_HOME}"
    echo "cmd to run: $cmd"
    sudo runuser -l oracle -c "${cmd}"
    sudo unzip ${TMP_FILE_DIR}/${TARGET_DOMAIN_FILE_NAME} -d $(dirname "${DOMAIN_HOME}")
}

function createInputFile() 
{
    echo "creating Install Location Template..."

    cat <<EOF >$TMP_FILE_DIR/inpute_file.template
[ARGUMENTS]

[SERVER_HOST_MAPPING]
#pattern source_host_name=target_host_name
[source_host_name]=[target_host_name]
EOF

    sed 's@\[source_host_name\]@'"$SOURCE_HOST_NAME"'@' ${TMP_FILE_DIR}/inpute_file.template > ${TMP_FILE_DIR}/inpute_file
    sed -i 's@\[target_host_name\]@'"$TARGET_HOST_NAME"'@' ${TMP_FILE_DIR}/inpute_file
}

function crateWalletDirectory()
{
    echo ${DOMAIN_ADMIN_PASSWORD} | sudo ${ORACLE_HOME}/oracle_common/common/bin/configWallet.sh -walletDir ${TMP_FILE_DIR} ${DOMAIN_ADMIN_USERNAME}
}

function runChangeHostCmd()
{
    .${ORACLE_HOME}/oracle_common/common/bin/chghost.sh -chgHostInputFile ${TMP_FILE_DIR}/inpute_file \
     -javaHome ${JAVA_HOME} \
     -domainLoc $(dirname "${DOMAIN_HOME}") \
     -domainAdminUserName ${DOMAIN_ADMIN_USERNAME} \
     -walletDir ${TMP_FILE_DIR} \
     -logDir ${TMP_FILE_DIR}
}

validateInputs

addOracleGroupAndUser

echo "step 1"
setupInstallPath

echo "step 2"
cleanup

echo "step 3"
installUtilities

echo "step 4"
downloadJDK

echo "step 5"
setupJDK

echo "step 6"
downloadMigrationData

echo "step 7"
create_oraInstloc

echo "step 8"
setupOracleBinaryAndDomain

echo "step 9"
createInputFile

echo "step 10"
crateWalletDirectory

echo "step 11"
runChangeHostCmd

echo "Weblogic Server Installation Completed succesfully."
