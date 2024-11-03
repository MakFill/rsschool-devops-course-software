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
helm install jenkins -n jenkins -f yml_configs/jenkins_values.yml $chart

jsonpath="{.data.jenkins-admin-password}"
secret=$(kubectl get secret -n jenkins jenkins -o jsonpath=$jsonpath)
echo "Admin user password: $(echo $secret | base64 --decode)"

echo "Get pods: $(kubectl get pods -n jenkins -w)"

# Set up port forwarding
kubectl -n jenkins port-forward svc/jenkins 8080:8080