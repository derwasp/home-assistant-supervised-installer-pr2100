#!/bin/sh

export LANG=en_US.UTF8

DNAME="hassio"
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
