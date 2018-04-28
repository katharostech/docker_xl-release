#!/usr/bin/bash

# Ensure secrets are visible only to root
chown root:root ${XLR_ENV}
chmod 700 ${XLR_ENV}

# Ensure license is visible to non-privileged
chown ${RUN_USER}:${RUN_GROUP} ${XLR_LIC}
chmod 744 ${XLR_LIC}

# Source the ENV file for secrets processing
. ${XLR_ENV}

# Build warning prompt for install
install_warning="###-STOP!!-###  Using the install option will destroy any existing data in the target databases.\n Are you sure you want to proceed [yes or no]: "

# Second and last warning
install_final_warning="###-ARE YOU SURE!!-###  Just sayin, once you choose yes, the target database, if not empty, will be purged and all data in it will be lost.\n Do you still want to proceed [yes or no]: "

# Setup config for XLR
/xlr-cfg.sh

# Remove files created by xlr-cfg with sensitive information
function clean-sensitive()
{
    rm -f /create_xl_dbs.sql
}

# Initialize XL Release
function initialize()
{
    printf "Initializing XL Release\n"
    # Initialize the cluster or stand-alone node
    su -s /usr/bin/bash "${RUN_USER}" -c "${XLR_BIN}/run.sh -setup -setup-defaults ${XLR_CONF}/xl-release-server.conf -reinitialize -force"
    # Clear directories
    rm -rf \
        ${XLR_LOG}/* \
        ${XLR_TMP}/*
}

# Evaluate commands
case ${1} in
install )
    printf "${install_warning}"
    read yno

    case $yno in
    [yY] | [yY][Ee][Ss] )
        printf "${install_final_warning}"
        read fyno

        case $fyno in
        [yY] | [yY][Ee][Ss] )
            printf "Installing XL Release\n"
            /db-cfg.sh
            /opt/mssql-tools/bin/sqlcmd -i /create_xl_dbs.sql
            clean-sensitive
            ;;
        [nN] | [n|N][O|o] )
            printf "Whew! That was close. Don't scare me like that again\n"
            exit 0
            ;;
        *)
            printf "Invalid input. Valid options: [yes or no]\n"
            exit 2
            ;;
        esac
        ;;
    [nN] | [n|N][O|o] )
        printf "Good choice! Think about this one a little longer\n";
        exit 0
        ;;
    *)
        printf "Invalid input. Valid optons: [yes or no]\n"
        exit 1
        ;;
    esac
    ;;
init )
    initialize
    ;;
run )
    printf "Starting XL Release\n"
    # Start XLR and save the PID
    su -c "${XLR_BIN}/run.sh" ${RUN_USER} &
    export XLR_PID=$!
    printf "The PID = ${XLR_PID}\n"

    # Trap the signals and
    # stop XLR gracefully...sort of
    trap "{ kill -9 ${XLR_PID}; exit $?; }" SIGTERM SIGINT

    # Tail the log until signal
    # Loop until signal
    printf "Going to loop until signal\n"
    while :
    do
        sleep 4
        # Die if XLR has shutdown
        ## Scan the last line of the log for shutdown verbiage
        tail -20 ${XLR_LOG}/xl-release.log | grep "XL Release has shut down."; xlr_shutdown_retcode=`echo $?`
        ## If we find the shutdown verbiage, then exit with non-zero
        if [[ ${xlr_shutdown_retcode} -eq 0 ]] ; then
            exit 4
        fi
    done
    ;;
* )
    printf "Usage\: ${0} \[install\|init\|run\]\n"
    exit 3
    ;;
esac
