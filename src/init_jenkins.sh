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

kubectl wait --for=condition=Bound pvc/jenkins-pv -n jenkins --timeout=60s

echo "Describe pod - $(kubectl get pods -n jenkins --show-labels)"

# Install Jenkins
echo "Install Jenkins"
chart=jenkinsci/jenkins
helm install jenkins -n jenkins -f yml_configs/jenkins_values.yml $chart

jsonpath="{.data.jenkins-admin-password}"
secret=$(kubectl get secret -n jenkins jenkins -o jsonpath=$jsonpath)
echo "Admin user password: $(echo $secret | base64 --decode)"

# sleep 10

# echo "Labels - $(kubectl get pods -n jenkins --show-labels)"
# echo "Nodes - $(kubectl get nodes)"
# # echo "Describe nodes - $(kubectl describe nodes)"
# POD_NAME=$(kubectl get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
# echo "pod name - $POD_NAME"
# echo "pod - $(kubectl describe pod $POD_NAME -n jenkins)"

# Wait for Jenkins pod to be in Running status
echo "Waiting for Jenkins pod to be in Running status..."
while true; do
  POD_NAME=$(kubectl get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  POD_STATUS=$(kubectl get pod "$POD_NAME" -n jenkins -o jsonpath='{.status.phase}' 2>/dev/null)

  if [[ "$POD_STATUS" == "Running" ]]; then
    echo "Jenkins pod is now running: $POD_NAME"
    break
  fi
  
  echo "Waiting for pod ($POD_NAME - $POD_STATUS) to start..."
  echo "Labels - $(kubectl get pods -n jenkins --show-labels)"
  sleep 5  
done

# Set up port forwarding
kubectl -n jenkins port-forward pod/$POD_NAME 8080:8080