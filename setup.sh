#!/usr/bin/env bash

FQDN=$1
CA_LOCATION=$2

kubectl create -n kube-system secret generic registry-pem --from-file=cert.crt=$2 -o yaml --dry-run=client > registry-pem-secret.yaml
sed "s/registry.example.com/$FQDN/" load-certs-cm-example.yaml > load-certs-cm.yaml

echo "Generated Secret to store the cert in registry-pem-secret.yaml"
echo "Please review the file contents below"
echo "------------------------------------------"
cat registry-pem-secret.yaml
echo "------------------------------------------"

echo "Generated ConfigMap to store the script to load $FQDN cert onto GKE nodes in the file load-certs-cm.yaml"
echo "Please review the file contents below"
echo "------------------------------------------"
cat load-certs-cm.yaml
echo "------------------------------------------"

echo "You can now install the CA loader as a DaemonSet by running the following commands (use at your own risk)"
echo "kubectl apply -f load-certs-cm.yaml"
echo "kubectl apply -f registry-pem-secret.yaml"
echo "kubectl apply -f daemonset.yaml"






