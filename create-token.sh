#!/bin/bash

# Create kubeapps namespace
kubectl create namespace kubeapps --dry-run=client -o yaml | kubectl apply -f -

# Create service account in kubeapps namespace
kubectl create serviceaccount kubeapps-dev -n kubeapps --dry-run=client -o yaml | kubectl apply -f -

# Create cluster role binding
kubectl create clusterrolebinding kubeapps-dev --clusterrole=cluster-admin --serviceaccount=kubeapps:kubeapps-dev --dry-run=client -o yaml | kubectl apply -f -

# Create token and display it
kubectl create token kubeapps-dev -n kubeapps