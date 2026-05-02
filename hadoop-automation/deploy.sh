#!/bin/bash
# Stop the script if any command fails
set -e

echo "Initializing Terraform..."
terraform init

echo "Building AWS Infrastructure..."
terraform apply -auto-approve

echo "Infrastructure built! Handing over to Ansible for dynamic connection polling..."
ansible-playbook setup-hadoop.yml

echo "Deployment and Health Checks Complete!"
