#!/bin/bash

# Disable swap (required by Kubernetes)
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Install k3s
echo "Installing k3s..."
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --disable traefik

# Wait for k3s to start
echo "Waiting for k3s to start..."
for i in {1..40}; do
    if systemctl is-active --quiet k3s; then
        echo "k3s is up and running!"
        break
    fi
    echo "Waiting for k3s to be ready... (attempt $i)"
    sleep 5
done

# Check if k3s started successfully
if ! systemctl is-active --quiet k3s; then
    echo "k3s failed to start. Exiting..."
    exit 1
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Check if k3s server is ready
echo "Waiting for k3s API server to be ready..."
for i in {1..40}; do
    if kubectl get nodes &> /dev/null; then
        echo "k3s API server is ready"
        break
    fi
    echo "Waiting for k3s API server to be ready... (attempt $i)"
    sleep 5
done

# Check if k3s server is still not ready
if ! kubectl get nodes &> /dev/null; then
    echo "k3s API server failed to start. Exiting..."
    exit 1
fi

echo "Cluster Information:"
kubectl get nodes
