#!/bin/bash
kubectl logs -f -n istio-system -l app=istio-eastwestgateway &
kubectl logs -f -n simple-app -l app=frontend &
