#!/bin/bash

OVPN_DATA_VOLUME_PREFIX="ovpn-data-"
OVPN_DATA_VOLUME_NAME="ansible"
OVPN_DATA=${OVPN_DATA_VOLUME_PREFIX}${OVPN_DATA_VOLUME_NAME}
# Change this to the DNS Name you will use
OVPN_DNS="vpn.example.com"
CLIENT_NAME="client"
CONTAINER_NAME="openvpn"
OVPN_OUTPUT_DIRECTORY="/etc/ovpn/"


# Only create container if it is not already running
if [ -z "$(docker ps -f "name=ovpn-${OVPN_DATA_VOLUME_NAME}" | grep ovpn-${OVPN_DATA_VOLUME_NAME})" ]
then
    # Create OpenVPN configuration
    docker volume create --name $OVPN_DATA
    docker run -v $OVPN_DATA:/etc/openvpn --log-driver=none --rm kylemanna/openvpn ovpn_genconfig -u udp://$OVPN_DNS
    docker run -e EASYRSA_BATCH=yes -e EASYRSA_REQ_CN=$OVPN_DNS -v $OVPN_DATA:/etc/openvpn --log-driver=none --rm kylemanna/openvpn ovpn_initpki nopass

    # Download systemd script and start service
    curl -L https://raw.githubusercontent.com/kylemanna/docker-openvpn/master/init/docker-openvpn%40.service > /etc/systemd/system/docker-openvpn@.service
    systemctl enable --now docker-openvpn@${OVPN_DATA_VOLUME_NAME}.service

    # Generate Client Certificate and output configuration file
    docker run -v $OVPN_DATA:/etc/openvpn --log-driver=none --rm kylemanna/openvpn easyrsa build-client-full $CLIENT_NAME nopass
    [[ -d $OVPN_OUTPUT_DIRECTORY ]] || mkdir -p $OVPN_OUTPUT_DIRECTORY
    docker run -v $OVPN_DATA:/etc/openvpn --log-driver=none --rm kylemanna/openvpn ovpn_getclient $CLIENT_NAME > ${OVPN_OUTPUT_DIRECTORY}${CLIENT_NAME}.ovpn
else
    # Always enable service in case it was somehow disabled
    systemctl enable --now docker-openvpn@${OVPN_DATA_VOLUME_NAME}.service
    echo "OpenVPN container already running"
fi
