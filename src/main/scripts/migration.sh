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
export DOMAIN_ADMIN_USERNAME="${13}"
export DOMAIN_ADMIN_PASSWORD="${14}"
export SOURCE_HOST_NAME="${15}"
export TARGET_HOST_NAME="${16}"
export RESOURCE_GROUP_NAME="${17}"
export ADMIN_VM_NAME="${18}"
export SCRIPT_LOCATION="${19}"

az vm extension set --name CustomScript \
    --extension-instance-name admin-weblogic-setup-script \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --vm-name ${ADMIN_VM_NAME} \
    --publisher Microsoft.Azure.Extensions \
    --version 2.0 \
    --settings "{\"fileUris\": [\"${SCRIPT_LOCATION}adminMigration.sh\"]}" \
    --protected-settings "{\"commandToExecute\":\"sh adminMigration.sh  ${acceptOTNLicenseAgreement} ${otnusername} ${otnpassword} ${jdkVersion} ${JAVA_HOME} ${TARGET_BINARY_FILE_NAME} ${TARGET_DOMAIN_FILE_NAME} ${ORACLE_HOME} ${DOMAIN_HOME} ${AZ_ACCOUNT_NAME} ${AZ_BLOB_CONTAINER} ${AZ_SAS_TOKEN} ${DOMAIN_ADMIN_USERNAME} ${DOMAIN_ADMIN_PASSWORD} ${SOURCE_HOST_NAME} ${TARGET_HOST_NAME}\"}"
    
function echo_stderr() {
    echo "$@" >&2
}