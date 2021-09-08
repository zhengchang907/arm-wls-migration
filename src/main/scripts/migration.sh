#!/bin/bash

export acceptOTNLicenseAgreement=$1
export otnCredentials=$2
export migrationStorage=$3
export sourceEnv=$4
export adminVMName=$5
export managedVMPrefix=$6
export numberOfInstances=$7
export scriptLocation=$8
export resourceGroupName=$9

echo $@

echo $acceptOTNLicenseAgreement $otnCredentials $migrationStorage $sourceEnv $adminVMName $managedVMPrefix $numberOfInstances $scriptLocation $resourceGroupName

export otnusername=$(echo $otnCredentials | jq -r '.otnAccountUsername')
export otnpassword=$(echo $otnCredentials | jq -r '.otnAccountPassword')
export jdkVersion=$(echo $sourceEnv | jq -r '.javaEnv.jdkVersion')
export JAVA_HOME=$(echo $sourceEnv | jq -r '.javaEnv.javaHome')
export TARGET_BINARY_FILE_NAME=$(echo $sourceEnv | jq -r '.adminNodeInfo.ofmBinaryFileName')
export TARGET_DOMAIN_FILE_NAME=$(echo $sourceEnv | jq -r '.adminNodeInfo.domainZipFileName')
export ORACLE_HOME=$(echo $sourceEnv | jq -r '.ofmEnv.oracleHome')
export DOMAIN_HOME=$(echo $sourceEnv | jq -r '.domainEnv.domainHome')
export DOMAIN_ADMIN_USERNAME=$(echo $sourceEnv | jq -r '.domainEnv.adminCredentials.adminUsername')
export DOMAIN_ADMIN_PASSWORD=$(echo $sourceEnv | jq -r '.domainEnv.adminCredentials.adminPassword')
export AZ_ACCOUNT_NAME=$(echo $migrationStorage | jq -r '.migrationSaName')
export AZ_BLOB_CONTAINER=$(echo $migrationStorage | jq -r '.migrationConName')
export AZ_SAS_TOKEN=$(echo $migrationStorage | jq -r '.migrationSASToken')
export ADMIN_SOURCE_HOST_NAME=$(echo $sourceEnv | jq -r '.adminNodeInfo.hostname')

echo $otnusername $otnpassword $jdkVersion $JAVA_HOME $TARGET_BINARY_FILE_NAME $TARGET_DOMAIN_FILE_NAME $ORACLE_HOME $DOMAIN_HOME $DOMAIN_ADMIN_USERNAME $DOMAIN_ADMIN_PASSWORD $AZ_ACCOUNT_NAME $AZ_BLOB_CONTAINER $AZ_SAS_TOKEN $ADMIN_SOURCE_HOST_NAME

input_file="[ARGUMENTS]"$'\n'"[SERVER_HOST_MAPPING]"

function echo_stderr() {
    echo "$@" >&2
}

function createInputFile() {
    ## Add admin node
    input_file="$input_file"$'\n'"${ADMIN_SOURCE_HOST_NAME}=${adminVMName}"
    ## Get all host names of source managed node
    managedNodeHostnames=$(az vm list --resource-group ${resourceGroupName} --query "[?name!='${adminVMName}'].name")
    echo $managedNodeHostnames
    ## Concat managed node
    for ((i = 0; i < numberOfInstances - 1; i++)); do
        srcHostname=$(echo $sourceEnv | jq ".managedNodeInfo" | jq -r ".[$i] | .hostname")
        targetHostname=$(echo $managedNodeHostnames | jq -r ".[$i]")
        input_file="$input_file"$'\n'"${srcHostname}=${targetHostname}"
    done
}

createInputFile

echo "$input_file"

az vm extension set --name CustomScript \
    --extension-instance-name admin-weblogic-setup-script \
    --resource-group ${resourceGroupName} \
    --vm-name ${adminVMName} \
    --publisher Microsoft.Azure.Extensions \
    --version 2.0 \
    --settings "{\"fileUris\": [\"${scriptLocation}adminMigration.sh\"]}" \
    --protected-settings "{\"commandToExecute\":\"sh adminMigration.sh  ${acceptOTNLicenseAgreement} ${otnusername} ${otnpassword} ${jdkVersion} ${JAVA_HOME} ${TARGET_BINARY_FILE_NAME} ${TARGET_DOMAIN_FILE_NAME} ${ORACLE_HOME} ${DOMAIN_HOME} ${AZ_ACCOUNT_NAME} ${AZ_BLOB_CONTAINER} ${AZ_SAS_TOKEN} ${DOMAIN_ADMIN_USERNAME} ${DOMAIN_ADMIN_PASSWORD} ${ADMIN_SOURCE_HOST_NAME} ${adminVMName} ${input_file}\"}"

managedNodeHostnames=$(az vm list --resource-group ${resourceGroupName} --query "[?name!='${adminVMName}'].name")

echo "$managedNodeHostnames"

for ((i = 0; i < numberOfInstances - 1; i++)); do
    srcHostname=$(echo $sourceEnv | jq ".managedNodeInfo" | jq -r ".[$i] | .hostname")
    targetHostname=$(echo $managedNodeHostnames | jq -r ".[$i]")
    az vm extension set --name CustomScript \
    --extension-instance-name admin-weblogic-setup-script \
    --resource-group ${resourceGroupName} \
    --vm-name ${adminVMName} \
    --publisher Microsoft.Azure.Extensions \
    --version 2.0 \
    --settings "{\"fileUris\": [\"${scriptLocation}managedMigrate.sh\"]}" \
    --protected-settings "{\"commandToExecute\":\"sh managedMigrate.sh  ${acceptOTNLicenseAgreement} ${otnusername} ${otnpassword} ${jdkVersion} ${JAVA_HOME} ${TARGET_BINARY_FILE_NAME} ${TARGET_DOMAIN_FILE_NAME} ${ORACLE_HOME} ${DOMAIN_HOME} ${AZ_ACCOUNT_NAME} ${AZ_BLOB_CONTAINER} ${AZ_SAS_TOKEN} ${DOMAIN_ADMIN_USERNAME} ${DOMAIN_ADMIN_PASSWORD} ${srcHostname} ${targetHostname} ${input_file}\"}"
done
