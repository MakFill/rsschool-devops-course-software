#!/bin/bash

ssh -i "$SSH_KEY_PATH" ec2-user@"$SERVER_INSTANCE_IP"

curl -sfL https://get.k3s.io | sh -

# Update system packages
echo "Updating system packages..."
yum update -y

# Disable swap (required by Kubernetes)
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Install k3s with Local Path Provisioner for Persistent Volumes
echo "Installing k3s..."
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --disable traefik

# Wait for k3s to start
echo "Waiting for k3s to start..."
for i in {1..30}; do
    if kubectl get nodes &> /dev/null; then
        echo "k3s is up and running!"
        break
    fi
    echo "Waiting for k3s to be ready... (attempt $i)"
    sleep 2
done

# Check if k3s started successfully
if ! kubectl get nodes &> /dev/null; then
    echo "k3s failed to start. Exiting..."
    exit 1
fi

# Get the node token for joining
NODE_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
echo "Node token for joining worker nodes: ${NODE_TOKEN}"

# Save the node token to a file for later retrieval
echo ${NODE_TOKEN} > /tmp/k3s_node_token.txt

# Deploy Local Path Provisioner
echo "Deploying Local Path Provisioner..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-provisioner.yaml

# Create a Persistent Volume (PV)
echo "Creating a Persistent Volume..."
kubectl apply -f volume_config/pv.yml

# Create a Persistent Volume Claim (PVC)
echo "Creating a Persistent Volume Claim..."
kubectl apply -f volume_config/pvc.yml

# Show k3s cluster information
echo "Cluster Information:"
kubectl get nodes
kubectl get pv
kubectl get pvc
kubectl get storageclass