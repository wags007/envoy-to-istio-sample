#!/usr/bin/env bash
if [[ "$1" = "debug" ]]; then
  set -o xtrace
fi
set -o errexit
set -o nounset
set -o pipefail
certs_dir="certs"
conf_dir="istio_config"
network="vm-network"
DIR=$(cd "$(dirname "$0")" || exit; pwd )

function check_command () {
    if ! [[ -x $(command -v $1) ]] ; then
        echo "$1 not installed"
        exit 1234
    fi
}

check_command docker
check_command docker-compose
check_command k3d
check_command istioctl
check_command kubectl
check_command openssl


#------------------------------------------------------------------------
# remove old certs
echo "Removing old certs"
rm -rf ${DIR}/${certs_dir}
rm -rf ${DIR}/envoy_config/certs/vm/*
rm -rf ${DIR}/envoy_config/certs
echo "Old certs removed"

#------------------------------------------------------------------------
# delete old cluster
echo "Deleting old cluster"
if [ $(k3d cluster delete --config ${conf_dir}/k3d-cluster.yaml 2>&1 > /dev/null || true) ]; then
  echo "Cluster deleted"
else
  echo "Cluster does not exist"
fi
echo "Old cluster deleted"
#------------------------------------------------------------------------
# stop envoy container/vm
echo "Stopping of envoy container simulating as a vm"
if [ $(docker-compose rm --stop --force || true ) ]
then
  echo "Envoy container stopped and removed"
else
  echo "Envoy container does not exist or another error occured"
fi

#------------------------------------------------------------------------
# remove old VM Network in docker
echo "Removing old VM Network in docker"
if [ $(docker network rm ${network} || true) ]; then
  echo "VM Network removed"
else
  echo "VM Network does not exist or another error occured"
fi
