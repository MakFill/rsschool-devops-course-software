#!/bin/bash

ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" ec2-user@"$SERVER_INSTANCE_IP"

# Disable swap (required by Kubernetes)
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Install k3s with Local Path Provisioner for Persistent Volumes
echo "Installing k3s..."
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --disable traefik

# Wait for k3s to start
echo "Waiting for k3s to start..."
for i in {1..30}; do
    if sudo systemctl is-active --quiet k3s; then
        echo "k3s is up and running!"
        break
    fi
    echo "Waiting for k3s to be ready... (attempt $i)"
    sleep 2
done

# Check if k3s started successfully
if ! sudo systemctl is-active --quiet k3s; then
    echo "k3s failed to start. Exiting..."
    exit 1
fi

# Create a Persistent Volume Claim (PVC)
echo "Creating a Persistent Volume Claim..."
kubectl create -f volume_config/pvc.yml

# Create a pod
echo "Creating a pod..."
kubectl create -f volume_config/pod.yml

# Show k3s cluster information
echo "Cluster Information:"
kubectl get nodes
kubectl get pv
kubectl get pvc
kubectl get storageclass