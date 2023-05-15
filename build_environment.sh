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

#------------------------------------------------------------------------
# Get the directory of this script
DIR=$(cd "$(dirname "$0")" || exit; pwd )

#------------------------------------------------------------------------
# Check if a command is installed
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
# sets up docker for use by vm and k3d.
echo "Creating docker network"
	docker network create ${network} || true > /dev/null 2>&1
echo "Docker network ${network} created"
#------------------------------------------------------------------------
#creates k3d cluster.
CLUSTERNAME=$(grep 'name:' ${conf_dir}/k3d-cluster.yaml|awk '{ print $2 }')
echo "Creating k3d cluster ${CLUSTERNAME}" 
k3d cluster create --config ${conf_dir}/k3d-cluster.yaml && sleep 10
echo "K3d cluster ${CLUSTERNAME} created"

#------------------------------------------------------------------------
# Create the certs we will need for the demo
echo "Creating certs"
./scripts/gen-certs.sh
echo "Certs created"



#------------------------------------------------------------------------
# Deploy istio to cluster using IstioOperator spec.
echo "Deploying istio operator to cluster"
istioctl install -f ${conf_dir}/istio/istiooperator.yaml -y
echo "Istio operator deployed"
echo "installing istio gateway"
kubectl apply -f ${conf_dir}/istio/gateway.yaml 
echo "istio gateway installed"
echo "installing apps"
kubectl apply -f ${conf_dir}/app.yaml
AppName=$(grep -m 1 'name:' ${conf_dir}/app.yaml|awk '{ print $2 }') 
echo "app ${AppName} installed"
echo "checking app status"
kubectl port-forward -n simple-app  deployment/frontend 8080:8080 >/dev/null 2>&1 &

if [ $(curl -s -f http://localhost:8080/health | grep '"code": 200'|wc -l) -eq 0 ]
then 
  kill %1
else
  echo "app is not running"
  kill %1
  exit 1234
fi
echo "app is running"


echo "installing fortune-teller"
kubectl apply -f ${conf_dir}/fortune-teller/app.yaml
echo "fortune-teller installed"
echo "checking app status"
kubectl port-forward -n fortune-teller  deployment/fortune-teller 8080:8080 >/dev/null 2>&1 &

if [ $(curl -s -f http://localhost:8080/health | grep '"code": 200'|wc -l) -eq 0 ]
then 
  kill %1
else
  echo "fortune-teller is not running"
  kill %1
  exit 1234
fi
echo "fortune-teller is running"

echo "starting docker-compose VM for envoy"
docker-compose up -d
echo "docker-compose VM for envoy started"

#------------------------------------------------------------------------

GATEWAYPOD=$(kubectl get pods -n istio-system |grep eastwestgateway|awk '{ print $1 }')
istioctl proxy-config listener -n istio-system ${GATEWAYPOD} 
istioctl proxy-status -n istio-system

