#!/usr/bin/env bash
set -e

function info { echo -e "[Info] $*"; }
function error { echo -e "[Error] $*"; exit 1; }
function warn  { echo -e "[Warning] $*"; }

ARCH=$(uname -m)
DOCKER_BINARY=/sbin/docker
DOCKER_REPO=homeassistant
DOCKER_DAEMON_CONFIG=/etc/docker/daemon.json
URL_VERSION="https://version.home-assistant.io/stable.json"
URL_HA="https://raw.githubusercontent.com/home-assistant/supervised-installer/master/files/ha"
URL_BIN_HASSIO="https://raw.githubusercontent.com/derwasp/home-assistant-supervised-installer-pr2100/master/hassio-supervisor"
URL_SERVICE_HASSIO="https://raw.githubusercontent.com/derwasp/home-assistant-supervised-installer-pr2100/master/hassio_service.sh"

# Check env
command -v docker > /dev/null 2>&1 || error "Please install docker first"
command -v jq > /dev/null 2>&1 || error "Please install jq first"
command -v curl > /dev/null 2>&1 || error "Please install curl first"
command -v avahi-daemon > /dev/null 2>&1 || error "Please install avahi first"
command -v dbus-daemon > /dev/null 2>&1 || error "Please install dbus first"

# Define the path for the docker package folder, as I don't know how to get it
APKG_PATH="/mnt/HD/HD_a2/Nas_Prog/docker"

# Detect wrong docker logger config
if [ ! -f "$DOCKER_DAEMON_CONFIG" ]; then
  # Write default configuration
  info "Creating default docker deamon configuration $DOCKER_DAEMON_CONFIG"
  cat > "$DOCKER_DAEMON_CONFIG" <<- EOF
    {
        "log-driver": "journald",
        "storage-driver": "overlay2"
    }
EOF
  # Restart Docker service
  info "Restarting docker service"
  "${APKG_PATH}/daemon.sh" stop
  sleep 3
  "${APKG_PATH}/daemon.sh" start
else
  STORRAGE_DRIVER=$(docker info -f "{{json .}}" | jq -r -e .Driver)
  LOGGING_DRIVER=$(docker info -f "{{json .}}" | jq -r -e .LoggingDriver)
  if [[ "$STORRAGE_DRIVER" != "overlay2" ]]; then
    warn "Docker is using $STORRAGE_DRIVER and not 'overlay2' as the storrage driver, this is not supported."
  fi
  if [[ "$LOGGING_DRIVER"  != "journald" ]]; then
    warn "Docker is using $LOGGING_DRIVER and not 'journald' as the logging driver, this is not supported."
  fi
fi

# Check dmesg access
if [[ "$(sysctl --values kernel.dmesg_restrict)" != "0" ]]; then
    info "Fix kernel dmesg restriction"
    echo 0 > /proc/sys/kernel/dmesg_restrict
    echo "kernel.dmesg_restrict=0" >> /etc/sysctl.conf
fi

# Parse command line parameters
while [[ $# -gt 0 ]]; do
    arg="$1"

    case $arg in
        -m|--machine)
            MACHINE=$2
            shift
            ;;
        -d|--data-share)
            DATA_SHARE=$2
            shift
            ;;
        -p|--prefix)
            PREFIX=$2
            shift
            ;;
        -s|--sysconfdir)
            SYSCONFDIR=$2
            shift
            ;;
        *)
            error "Unrecognized option $1"
            ;;
    esac
    shift
done

PREFIX=${PREFIX:-/mnt/HD/HD_a2/usr}
SYSCONFDIR=${SYSCONFDIR:-/opt/etc}
DATA_SHARE=${DATA_SHARE:-$PREFIX/share/hassio}
CONFIG=$SYSCONFDIR/hassio.json

# Generate hardware options
case $ARCH in
    "i386" | "i686")
        MACHINE=${MACHINE:=qemux86}
        HASSIO_DOCKER="$DOCKER_REPO/i386-hassio-supervisor"
    ;;
    "x86_64")
        MACHINE=${MACHINE:=qemux86-64}
        HASSIO_DOCKER="$DOCKER_REPO/amd64-hassio-supervisor"
    ;;
    "arm" |"armv6l")
        if [ -z $MACHINE ]; then
            error "Please set machine for $ARCH"
        fi
        HASSIO_DOCKER="$DOCKER_REPO/armhf-hassio-supervisor"
    ;;
    "armv7l")
        if [ -z $MACHINE ]; then
            error "Please set machine for $ARCH"
        fi
        HASSIO_DOCKER="$DOCKER_REPO/armv7-hassio-supervisor"
    ;;
    "aarch64")
        if [ -z $MACHINE ]; then
            error "Please set machine for $ARCH"
        fi
        HASSIO_DOCKER="$DOCKER_REPO/aarch64-hassio-supervisor"
    ;;
    *)
        error "$ARCH unknown"
    ;;
esac

if [[ ! "intel-nuc odroid-c2 odroid-n2 odroid-xu qemuarm qemuarm-64 qemux86 qemux86-64 raspberrypi raspberrypi2 raspberrypi3 raspberrypi4 raspberrypi3-64 raspberrypi4-64 tinker" = *"${MACHINE}"* ]]; then
    error "Unknown machine type ${MACHINE}"
fi

### Main

# Init folders
if [ ! -d "$DATA_SHARE" ]; then
    mkdir -p "$DATA_SHARE"
fi

# Read infos from web
HASSIO_VERSION=$(curl -s $URL_VERSION | jq -e -r '.supervisor')

##
# Write configuration
cat > "$CONFIG" <<- EOF
{
    "supervisor": "${HASSIO_DOCKER}",
    "homeassistant": "${HOMEASSISTANT_DOCKER}",
    "data": "${DATA_SHARE}"
}
EOF

##
# Pull supervisor image
info "Install supervisor Docker container"
docker pull "$HASSIO_DOCKER:$HASSIO_VERSION" > /dev/null
docker tag "$HASSIO_DOCKER:$HASSIO_VERSION" "$HASSIO_DOCKER:latest" > /dev/null

##
# Install Hass.io Supervisor
info "Install supervisor startup scripts"
curl -sL ${URL_BIN_HASSIO} > "/opt/sbin/hassio-supervisor"
curl -sL ${URL_SERVICE_HASSIO} > "${SYSCONFDIR}/init.d/S99hassio.sh"

sed -i "s,%%HASSIO_CONFIG%%,${CONFIG},g" /opt/sbin/hassio-supervisor
sed -i -e "s,%%DOCKER_BINARY%%,${DOCKER_BINARY},g" \
       -e "s,%%HASSIO_BINARY%%,/opt/sbin/hassio-supervisor,g" \
       "${SYSCONFDIR}/init.d/S99hassio.sh"

chmod a+x "/opt/sbin/hassio-supervisor"
chmod a+x "${SYSCONFDIR}/init.d/S99hassio.sh"

info "Run Hass.io"
command ${SYSCONFDIR}/init.d/S99hassio.sh start

##
# Setup CLI
info "Install cli 'ha'"
curl -sL ${URL_HA} > "/opt/sbin/ha"
chmod a+x "/opt/sbin/ha"