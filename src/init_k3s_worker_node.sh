#!/bin/bash

ssh -i "$SSH_KEY_PATH" ec2-user@"$WORKER_INSTANCE_IP"

# Update system packages
echo "Updating system packages..."
yum update -y

# Disable swap (required by Kubernetes)
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Fetch the k3s node token from the server node
echo "Fetching the k3s node token from the server..."
NODE_TOKEN=$(ssh -o StrictHostKeyChecking=no ec2-user@"$SERVER_INSTANCE_IP" 'cat /tmp/k3s_node_token.txt')

# Check if NODE_TOKEN was retrieved successfully
if [ -z "$NODE_TOKEN" ]; then
    echo "Failed to retrieve node token from the server. Exiting..."
    exit 1
fi

# Install k3s and join the existing cluster
echo "Joining k3s cluster at "$SERVER_INSTANCE_IP"..."
curl -sfL https://get.k3s.io | K3S_URL=https://"$SERVER_INSTANCE_IP":6443 K3S_TOKEN=${NODE_TOKEN} sh -

# Wait for k3s to start
echo "Waiting for k3s to start on worker node..."
for i in {1..30}; do
    if kubectl get nodes &> /dev/null; then
        echo "Worker node is now part of the k3s cluster!"
        break
    fi
    echo "Waiting for k3s to be ready on worker node... (attempt $i)"
    sleep 2
done

# Verification
echo "Verifying k3s setup on worker node..."
kubectl get nodes