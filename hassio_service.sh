#!/bin/sh

export LANG=en_US.UTF8

# Package
PACKAGE="hassio"
DNAME="hassio"

# Others
PKG_DIR="/shares/Volume_1/Nas_Prog/${PACKAGE}"
INSTALL_DIR="${PKG_DIR}/${DNAME}"
PID_FILE="/var/run/hassio.pid"
CONTAINER_NAME="hassio_supervisor"

start_daemon ()
{
    %%HASSIO_BINARY%%
}

stop_daemon()
{
    %%DOCKER_BINARY%% stop ${CONTAINER_NAME}
}

daemon_status()
{
    docker ps | grep ${CONTAINER_NAME}
    return $?
}

case $1 in
    start)
        if daemon_status; then
                        echo ${DNAME} is already running
        else
                        echo Starting ${DNAME} ...
            start_daemon
        fi
        ;;
    stop)
        if daemon_status; then
                        echo Stopping ${DNAME} ...
            stop_daemon
        else
                        echo ${DNAME} is not running
        fi
        ;;
    status)
        if daemon_status; then
                        echo ${DNAME} is running
            exit 0
        else
                        echo ${DNAME} is not running
            exit 1
        fi
        ;;
    *)
        exit 1
        ;;
esac
