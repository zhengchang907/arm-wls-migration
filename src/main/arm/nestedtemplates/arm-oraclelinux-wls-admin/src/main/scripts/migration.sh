#!/bin/bash

export acceptOTNLicenseAgreement=$1
export otnCredentials=$2
export migrationStorage=$3
export sourceEnv=$4
export adminVMName=$5
export scriptLocation=$6
export resourceGroupName=$7
export targetHostname=$8

echo $@

echo $acceptOTNLicenseAgreement $otnCredentials $migrationStorage $sourceEnv $adminVMName $scriptLocation $resourceGroupName

export otnusername=$(echo $otnCredentials | jq -r '.otnAccountUsername')
export otnpassword=$(echo $otnCredentials | jq -r '.otnAccountPassword')
export jdkVersion=$(echo $sourceEnv | jq -r '.javaEnv.jdkVersion')
export JAVA_HOME=$(echo $sourceEnv | jq -r '.javaEnv.javaHome')
export ORACLE_HOME=$(echo $sourceEnv | jq -r '.ofmEnv.oracleHome')
export DOMAIN_HOME=$(echo $sourceEnv | jq -r '.domainEnv.domainHome')
export DOMAIN_ADMIN_USERNAME=$(echo $sourceEnv | jq -r '.domainEnv.adminCredentials.adminUsername')
export DOMAIN_ADMIN_PASSWORD=$(echo $sourceEnv | jq -r '.domainEnv.adminCredentials.adminPassword')
export AZ_ACCOUNT_NAME=$(echo $migrationStorage | jq -r '.migrationSaName')
export AZ_BLOB_CONTAINER=$(echo $migrationStorage | jq -r '.migrationConName')
export AZ_SAS_TOKEN=$(echo $migrationStorage | jq -r '.migrationSASToken')
export ADMIN_SOURCE_HOST_NAME=$(echo $sourceEnv | jq -r '.domainEnv.adminHostName')

echo $otnusername $otnpassword $jdkVersion $JAVA_HOME $ORACLE_HOME $DOMAIN_HOME $DOMAIN_ADMIN_USERNAME $DOMAIN_ADMIN_PASSWORD $AZ_ACCOUNT_NAME $AZ_BLOB_CONTAINER $AZ_SAS_TOKEN $ADMIN_SOURCE_HOST_NAME

input_file=$'[ARGUMENTS]\n[SERVER_HOST_MAPPING]'

function echo_stderr() {
    echo "$@" >&2
}

function createInputFile() {
    ## Add admin node
    input_file="$input_file"$'\n'${ADMIN_SOURCE_HOST_NAME}=${adminVMName}
    echo "$input_file"
}

function configureAdminNode() {
    ADMIN_TARGET_BINARY_FILE_NAME=$(echo $sourceEnv | jq -r '.nodeInfo[0].ofmBinaryFileName')
    ADMIN_TARGET_DOMAIN_FILE_NAME=$(echo $sourceEnv | jq -r '.nodeInfo[0].domainZipFileName')
    az vm extension set --name CustomScript \
        --resource-group ${resourceGroupName} \
        --vm-name ${adminVMName} \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --settings "{\"fileUris\": [\"${scriptLocation}adminMigration.sh\"]}" \
        --protected-settings "{\"commandToExecute\":\"bash adminMigration.sh  ${acceptOTNLicenseAgreement} ${otnusername} ${otnpassword} ${jdkVersion} ${JAVA_HOME} ${ADMIN_TARGET_BINARY_FILE_NAME} ${ADMIN_TARGET_DOMAIN_FILE_NAME} ${ORACLE_HOME} ${DOMAIN_HOME} ${AZ_ACCOUNT_NAME} ${AZ_BLOB_CONTAINER} ${az_sas_token_base64} ${DOMAIN_ADMIN_USERNAME} ${DOMAIN_ADMIN_PASSWORD} ${adminVMName} ${input_file_base64} ${targetHostname}\"}"
    # error exception
    echo $?
    echo "admin VM extension execution completed"
}

function encodeParameter() {
    apk add --update coreutils
    input_file_base64=$(echo $input_file | base64 -w0)
    az_sas_token_base64=$(echo $AZ_SAS_TOKEN | base64 -w0)
}

createInputFile

encodeParameter

configureAdminNode