#!/bin/bash

ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" ec2-user@"$SERVER_INSTANCE_IP"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Create a Namespace for the Jenkins.
kubectl create namespace jenkins

echo "Add the Jenkins repo"
helm repo add jenkinsci https://charts.jenkins.io
helm repo update

# Create a persistent volume for the Jenkins controller pod
kubectl apply -f yml_configs/jenkins_volume.yml

# Create a service account
kubectl apply -f yml_configs/jenkins_sa.yml

# Install Jenkins
echo "Install Jenkins"
chart=jenkinsci/jenkins
helm install jenkins -n jenkins -f jenkins_values.yml $chart

jsonpath="{.data.jenkins-admin-password}"
secret=$(kubectl get secret -n jenkins jenkins -o jsonpath=$jsonpath)
echo $(echo $secret | base64 --decode)