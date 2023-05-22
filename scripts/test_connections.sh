#!/bin/bash

# This script tests the connections between the docker container  vm and 
# the istio ingress gateway. It does this by sending a request to the
# envoy proxy, which then forwards the request to the istio ingress gateway.

#first we test using the certs and connecting to the istio ingress gateway using CURL
echo "Testing connection to istio ingress gateway using certs"
CERTS_DIR=../envoy_config/certs/vm
curl -v -k --cert ${CERTS_DIR}/cert.pem --key ${CERTS_DIR}/key.pem --cacert ${CERTS_DIR}/ca-cert.pem \
    --resolve outbound_.80_._.frontend.simple-app.svc.cluster.local:15443:127.0.0.1 \
    -H "Host: outbound_.80_._.frontend.simple-app.svc.cluster.local" \
        https://outbound_.80_._.frontend.simple-app.svc.cluster.local:15443/frontend


#--resolve example.com:443:192.168.0.100 --servername example.com https://example.com
#-H "Host: outbound_.80_._.frontend.simple-app.svc.cluster.local" 
    #--resolve outbound_.80_._.frontend.simple-app.svc.cluster.local:15443:127.0.0.1 \
#outbound_.80_._.frontend.simple-app.svc.cluster.local

openssl s_client -showcerts -msg -servername outbound_.80_._.frontend.simple-app.svc.cluster.local -connect 127.0.0.1:15443
