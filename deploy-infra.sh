#!/bin/bash
# Master deployment script for CarVilla CI/CD Pipeline

set -e

echo "===================================================="
echo "CarVilla CI/CD Pipeline Deployment on AWS"
echo "===================================================="

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found. Please install it first."
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform not found. Please install it first."
    exit 1
fi

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    echo "Ansible not found. Please install it first."
    exit 1
fi

# Ensure AWS credentials are set
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "AWS credentials not set. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables."
    exit 1
fi

# Ensure SSH key exists
KEY_NAME="carvilla-key"
KEY_FILE="$HOME/.ssh/${KEY_NAME}.pem"

if [ ! -f "$KEY_FILE" ]; then
    echo "Creating SSH key pair for AWS..."
    aws ec2 create-key-pair --key-name ${KEY_NAME} --query 'KeyMaterial' --output text > ${KEY_FILE}
    chmod 400 ${KEY_FILE}
    echo "SSH key pair created: ${KEY_FILE}"
else
    echo "Using existing SSH key: ${KEY_FILE}"
fi

# Create necessary directories
mkdir -p terraform ansible/inventory ansible/vars

# Copy terraform configuration
echo "Copying Terraform configurations..."
cp terraform-files/*.tf terraform/
cp -r terraform-files/templates terraform/

# Copy ansible playbooks
echo "Copying Ansible configurations..."
cp -r ansible-files/playbooks ansible/
cp ansible-files/main.yml ansible/

echo "Starting Terraform infrastructure deployment..."
# Initialize and apply Terraform
cd terraform
terraform init
terraform apply -auto-approve

# Grab outputs for use in Ansible
MASTER_IP=$(terraform output -raw master_public_ip)
WORKER_IP=$(terraform output -raw worker_public_ip)
MASTER_PRIVATE_IP=$(terraform output -raw master_private_ip)
WORKER_PRIVATE_IP=$(terraform output -raw worker_private_ip)

cd ..

echo "===================================================="
echo "Infrastructure provisioned successfully!"
echo "Master Node: $MASTER_IP"
echo "Worker Node: $WORKER_IP"
echo "===================================================="

# Wait for SSH to be available
echo "Waiting for SSH to become available on instances..."
until ssh -o StrictHostKeyChecking=no -i $KEY_FILE ubuntu@$MASTER_IP "echo SSH to master is up"; do
    echo "Waiting for SSH on master..."
    sleep 10
done

until ssh -o StrictHostKeyChecking=no -i $KEY_FILE ubuntu@$WORKER_IP "echo SSH to worker is up"; do
    echo "Waiting for SSH on worker..."
    sleep 10
done

echo "Starting Ansible configuration..."
cd ansible

# Run the main Ansible playbook
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory/hosts.ini main.yml

echo "===================================================="
echo "Deployment Complete!"
echo "===================================================="
echo "Master Node: $MASTER_IP"
echo "Worker Node: $WORKER_IP"
echo "===================================================="
