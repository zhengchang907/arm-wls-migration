#!/bin/bash

export groupname="oracle"
export username="oracle"
export ORACLE_HOME="${1}"
export DOMAIN_HOME="${2}"
export DOMAIN_PATH=$(dirname "${DOMAIN_HOME}")
export TARGET_HOST_NAME="${3}"


function start_managed() {
    echo "Starting managed server $TARGET_HOST_NAME"
    sudo chown -R $username:$groupname $DOMAIN_PATH
    runuser -l oracle -c ". $ORACLE_HOME/oracle_common/common/bin/setWlstEnv.sh; java weblogic.WLST $DOMAIN_PATH/start-server.py"
    if [[ $? != 0 ]]; then
        echo "Error : Failed in starting managed server $TARGET_HOST_NAME"
        exit 1
    fi
}


start_managed