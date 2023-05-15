# Introduction 
This repo contains an demo environment for setting up a Kubernetes cluster with Istio service mesh that is connected to via an envoy proxy in a container with access to a demo application. The demo environment is intended to be used for testing and demonstration purposes only. It is not intended for production use.  The Demo is setup such that the Envoy container represents a VM connecting to an Istio Mesh on K8s.

# Prerequisites
This has only been tested on an intel MacOS computer.  You will need:
* Docker
* Docker-compose
* k3d
* istioctl
* kubectl
* openssl
* bash
* curl
* jq
* sed
* awk
* grep

# Setup
1. Clone this repo
2. Run `./build_environment.sh`
3. run `docker-compose up -d -f ./docker-compose.yml`

## build_environment.sh 
This is a bash script that automates the deployment of a Kubernetes cluster with Istio service mesh and a demo application. The script is intended to be used for testing and demonstration purposes only. It is not intended for production use.
* Check if necessary commands (docker, docker-compose, k3d, istioctl, kubectl, openssl) are installed and exit with an error code if not.
* Creates a Docker network to be used by the Kubernetes cluster.
* Creates a Kubernetes cluster using k3d with the configuration specified in the k3d-cluster.yaml file.
* Generates certificates required for the demo.
* Deploys the Istio service mesh to the cluster using the IstioOperator specification in istiooperator.yaml.
* Deploys an Istio gateway and the demo application to the Kubernetes cluster.
* Checks the health status of the demo application and exits with an error code if the application is not running.
* Deploys the fortune-teller application to the Kubernetes cluster and checks its health status.
* Starts a Docker container for Envoy sidecar proxy using docker-compose.
* Displays the listener configuration and status of the East-West gateway proxy using istioctl.

## clean_up_reset_environment.sh
This bash script is used to clean up the environment created by the build_environment.sh script. It is also used to reset the environment to its initial state after the demo has been run. The script is intended to be used for testing and demonstration purposes only. It is not intended for production use.

## docker-compose.yml
This file is used to start a Docker container for Envoy sidecar proxy. The container is started by the build_environment.sh script.

## fortune-teller.yaml
This file is used to deploy the fortune-teller application to the Kubernetes cluster. The application is deployed by the build_environment.sh script.

## istiooperator.yaml
This file is used to deploy the Istio service mesh to the Kubernetes cluster. The service mesh is deployed by the build_environment.sh script.


