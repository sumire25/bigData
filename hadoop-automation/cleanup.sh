#!/bin/bash
set -e

echo "Destroying AWS resources..."
terraform destroy -auto-approve

echo "Cleaning up temporary local files..."
rm -f /tmp/master_key.pub
# Remove the state files and the hidden .terraform folder
rm -f terraform.tfstate terraform.tfstate.backup
rm -rf .terraform/

echo "Infrastructure destroyed and local temporary keys cleaned."
