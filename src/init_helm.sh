#!/bin/bash

ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" ec2-user@"$SERVER_INSTANCE_IP"

# Install Helm.
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Wait for Helm installation
echo "Verifying Helm installation..."
for i in {1..20}; do
    if helm version; then
        echo "Helm installed successfully!"
        break
    fi
    echo "Waiting for Helm to be installed... (attempt $i)"
    sleep 5
done

# Check if Helm installed successfully
if ! helm version; then
    echo "Helm installation failed!"
    exit 1
fi

# Add the Bitnami Helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install Bitnami chart
helm install my-release oci://registry-1.docker.i/bitnamicharts/nginx

# Check Bitnami chart status
helm status my-release

# Uninstall Bitnami chart
helm uninstall my-release