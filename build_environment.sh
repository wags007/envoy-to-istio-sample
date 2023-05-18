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
#creates k3d cluster.
CLUSTERNAME=$(grep 'name:' ${conf_dir}/k3d-cluster.yaml|awk '{ print $2 }')
if [ $(k3d cluster list | grep ${CLUSTERNAME} | wc -l) -gt 0 ]
then
  echo "Cluster ${CLUSTERNAME} already exists"
else
  echo "Creating k3d cluster ${CLUSTERNAME}" 
  k3d cluster create --config ${conf_dir}/k3d-cluster.yaml && sleep 10
  echo "K3d cluster ${CLUSTERNAME} created"
fi

if [ $(k3d cluster list | grep ${CLUSTERNAME} | wc -l) -lt 1 ]
then
  echo "Cluster ${CLUSTERNAME} does not exist"
  exit 1234
fi

#------------------------------------------------------------------------
# Create the certs we will need for the demo

if [ $(kubectl create namespace cert-manager 2>&1|egrep '(already exists|created)'|wc -l) -gt 0  ]
then
  echo "Namespace cert-manager created"
else
  echo "Namespace cert-manager was not created"
  exit 1234
fi

if [ $(kubectl create namespace istio-system 2>&1|egrep '(already exists|created)'|wc -l) -gt 0 ]
then
  echo "Namespace istio-system created"
else
  echo "Namespace istio-system already exists"
  exit 1234
fi

kubectl apply -f istio_config/cert-manager.yaml --wait

while [ $(kubectl get deployments -n cert-manager -o json | jq '.items[].status.availableReplicas'|grep 1|wc -l) -lt 3 ] 
do
  echo "Waiting for cert-manager to be ready"
  sleep 5
done
echo "Creating and deploying root certs"
if [ -s ${certs_dir}/root/istio-root-ca.crt ] && [ -s ${certs_dir}/root/istio-root-ca.key ]
then
  echo "Root Certs already exist"
else
  echo "root certs do not exist, creating"
  mkdir -p ${certs_dir}/root
  openssl req -new -newkey rsa:4096 -x509 -sha256 \
          -days 3650 -nodes -out ${certs_dir}/root/istio-root-ca.crt -keyout ${certs_dir}/root/istio-root-ca.key \
          -config istio_config/istio/istio-root-ca.conf
  sleep 5
  if [ -s ${certs_dir}/root/istio-root-ca.crt ] && [ -s ${certs_dir}/root/istio-root-ca.key ]
  then
    echo "Root CA created"
  else 
    echo "Root CA failed to create"
    exit 1234
  fi
fi
if [ $(kubectl get secret istio-root-ca -n cert-manager -o json 2>/dev/null|jq ".data"|wc -l) -gt 0 ]
then
  echo "istio-root-ca secret already exists"
else
  echo "Creating secret for istio-root-ca"
  if [ $( kubectl create secret generic istio-root-ca \
        --from-file=tls.key=${certs_dir}/root/istio-root-ca.key \
        --from-file=tls.crt=${certs_dir}/root/istio-root-ca.crt \
        --namespace cert-manager 2>&1|egrep '(already exists|created)'|wc -l) -gt 0 ]
  then
    echo "Root CA secret created"
  else
    echo "Root CA secret failed to create"
    exit 1234
  fi
fi

kubectl apply -f istio_config/deploy_certs.yaml --wait

if [ $(kubectl apply -f istio_config/deploy_certs.yaml --wait 2>&1|egrep '(configured|unchanged)'|wc -l) -gt 0 ]
then
  echo "certs deployed"
else
  echo "certs failed to deploy"
  exit 1234
fi

CLUSTER_DIR=${certs_dir}/cluster1
mkdir -p $CLUSTER_DIR

# We need to build the cert files outselves including the chain so the secret can be in the correct format
if [ -s $CLUSTER_DIR/ca-cert.pem ]
then
  echo "$CLUSTER_DIR/ca-cert.pem already exists"
else
  kubectl get secret cluster1-cacerts -n istio-system -o json | jq '.data."tls.crt"' -r | base64 --decode > $CLUSTER_DIR/ca-cert.pem
fi

if [ -s $CLUSTER_DIR/ca-key.pem ]
then
  echo "$CLUSTER_DIR/ca-key.pem already exists"
else
  kubectl get secret cluster1-cacerts -n istio-system -o json | jq '.data."tls.key"' -r | base64 --decode > $CLUSTER_DIR/ca-key.pem
fi

if [ -s $CLUSTER_DIR/root-cert.pem ]
then
  echo "$CLUSTER_DIR/root-cert.pem already exists"
else
  kubectl get secret cluster1-cacerts -n istio-system -o json | jq '.data."ca.crt"' -r | base64 --decode > $CLUSTER_DIR/root-cert.pem
fi

if [ -s $CLUSTER_DIR/cert-chain.pem ]
then
  echo "$CLUSTER_DIR/cert-chain.pem already exists"
else
  kubectl get secret cluster1-cacerts -n istio-system -o json | jq '.data."tls.crt"' -r | base64 --decode > $CLUSTER_DIR/cert-chain.pem
  kubectl get secret cluster1-cacerts -n istio-system -o json | jq '.data."ca.crt"' -r | base64 --decode >> $CLUSTER_DIR/cert-chain.pem
fi

VM_DIR=envoy_config/certs/vm
mkdir -p $VM_DIR

if [ -s $VM_DIR/cert.pem ]
then
  echo "$VM_DIR/cert.pem already exists"
else
  kubectl get secret vm-proxy -n istio-system -o json | jq '.data."tls.crt"' -r | base64 --decode > $VM_DIR/cert.pem
  if [ -s $VM_DIR/cert.pem ]
  then
    echo "$VM_DIR/cert.pem now exists"
  else
    echo "Failed to create $VM_DIR/cert.pem"
    exit 1234
  fi
fi

if [ -s $VM_DIR/key.pem ]
then
  echo "$VM_DIR/key.pem already exists"
else
  kubectl get secret vm-proxy -n istio-system -o json | jq '.data."tls.key"' -r | base64 --decode > $VM_DIR/key.pem
fi

if [ -s $VM_DIR/ca-cert.pem ]
then
  echo "$VM_DIR/ca-cert.pem already exists"
else
  kubectl get secret vm-proxy -n istio-system -o json | jq '.data."ca.crt"' -r | base64 --decode > $VM_DIR/ca-cert.pem
fi

if [ $(kubectl create secret generic cacerts -n istio-system \
      --from-file=$CLUSTER_DIR/ca-cert.pem \
      --from-file=$CLUSTER_DIR/ca-key.pem \
      --from-file=$CLUSTER_DIR/root-cert.pem \
      --from-file=$CLUSTER_DIR/cert-chain.pem 2>&1|egrep '(already exists|created)'|wc -l) -gt 0 ]
then
  echo "cacerts secret created"
else
  echo "cacerts secret failed to create"
  exit 1234
fi
echo "completed deploying cert-manager and certs"

#------------------------------------------------------------------------
# Deploy istio to cluster using IstioOperator spec.
if [ $(kubectl get istiooperators -n istio-system|grep installed|wc -l) -gt 0 ]
then
  echo "Istio operator already installed"
else
  echo "Deploying istio operator to cluster"
  istioctl install -f ${conf_dir}/istio/istiooperator.yaml -y
  echo "Istio operator deployed"
fi

if [ $(kubectl get gateway -n istio-system|grep istio-eastwestgateway|wc -l) ]
then
  echo "Istio gateway already installed"
else
  echo "Deploying istio gateway to cluster"
  kubectl apply -f ${conf_dir}/istio/gateway.yaml
  echo "Istio gateway deployed"
fi

#------------------------------------------------------------------------
# Deploy simple app to cluster
AppName=$(grep -m 1 'name:' ${conf_dir}/app.yaml|awk '{ print $2 }') 

if [ $(kubectl get pods -n ${AppName}|grep frontend|wc -l) -gt 0 ]
then
  echo "Simple app already installed"
else
  echo "Deploying simple app to cluster"
  kubectl apply -f ${conf_dir}/app.yaml --wait
  echo "Simple app deployed"
fi

#------------------------------------------------------------------------
# Verify deployment of simple app
echo "checking app status"
if [ $(kubectl get pods -n ${AppName}|grep ${AppName}|wc -l) ]
then
  while [ $(kubectl get pods -n ${AppName}|grep frontend|awk '{ print $2 }'|grep -v "1/1"|wc -l) -lt 1 ]
  do
    echo "Simple app is not ready yet.  Sleeping 10 seconds"
    sleep 10
  done
  echo "checking app status"
  kubectl port-forward -n ${AppName}  deployment/frontend 8080:8080 >/dev/null 2>&1 &

  if [ $(curl -s -f http://localhost:8080/health | grep '"code": 200'|wc -l) -eq 0 ]
  then 
    kill %1 2>&1 >/dev/null
  else
    echo "app is not functional"
    kill %1 2>&1 >/dev/null
    exit 1234
  fi
else
  echo "Simple app is not installed.  Exiting"
  exit 1234
fi


echo "app ${AppName} installed and running"

echo "starting docker-compose VM for envoy"
docker-compose up -d 
sleep 2
if [ $(docker-compose ls|grep envoy|awk '{ print $2 }'|grep running|wc -l) -gt 0 ]
then  
  echo "docker-compose VM for envoy already running"
else
  echo "Docker-compose VM for envoy failed to start"
  exit 1234
fi


#------------------------------------------------------------------------
# Display the status of the istio configuration
echo "Displaying istio configuration"
GATEWAYPOD=$(kubectl get pods -n istio-system |grep eastwestgateway|awk '{ print $1 }')
istioctl proxy-config listener -n istio-system ${GATEWAYPOD} 
echo "Displaying istio status"
istioctl proxy-status -n istio-system


