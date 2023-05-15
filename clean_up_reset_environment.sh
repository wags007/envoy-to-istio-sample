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
rm -rf ${DIR}/${certs_dir}
rm -rf ${DIR}/envoy_config/certs/vm/*

#------------------------------------------------------------------------
# delete old cluster
k3d cluster delete --config ${conf_dir}/k3d-cluster.yaml || true

#------------------------------------------------------------------------
# stop envoy container/vm
docker-compose rm --stop --force
