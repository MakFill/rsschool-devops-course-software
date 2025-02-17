#!/bin/bash

ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" ec2-user@"$SERVER_INSTANCE_IP"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "Add the Jenkins repo"
helm repo add jenkinsci https://charts.jenkins.io
helm repo update

# Create a Namespace for the Jenkins.
kubectl create namespace jenkins

# Create a Persistent Volume (PV)
echo "Creating a Persistent Volume..."
kubectl apply -f yml_configs/jenkins_volume.yml

sudo mkdir -p /data/jenkins-volume/
sudo chown -R 1000:1000 /data/jenkins-volume/

kubectl get pv
kubectl get storageclass

# Create a service account
kubectl apply -f yml_configs/jenkins_sa.yml


# Install Jenkins
echo "Install Jenkins"
chart=jenkinsci/jenkins
helm install jenkins -n jenkins -f yml_configs/jenkins_values.yml $chart


jsonpath="{.data.jenkins-admin-password}"
secret=$(kubectl get secret -n jenkins jenkins -o jsonpath=$jsonpath)
echo "Admin user password: $(echo $secret | base64 --decode)"

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
  INIT_CONTAINER_STATUS=$(kubectl get pod $POD_NAME -n jenkins -o jsonpath='{.status.initContainerStatuses[*]}')

  for status in $INIT_CONTAINER_STATUS; do
    name=$(echo $status | jq -r '.name')
    state=$(echo $status | jq -r '.state')
    echo "Init Container: $name, Status: $state"

    terminated_state=$(echo $state | jq -r '.terminated')
    if [[ "$terminated_state" != "null" ]]; then
        exit_code=$(echo $terminated_state | jq -r '.exitCode')
        if [[ "$exit_code" -ne 0 ]]; then
          echo "Init Container: $name has failed with exit code $exit_code. Fetching logs..."
          kubectl logs $POD_NAME -n jenkins -c $name
        fi
    fi
  done
  sleep 5  
done

echo "PODS $(kubectl get pods -n jenkins)"
echo "SERVICES $(kubectl get services -n jenkins)"