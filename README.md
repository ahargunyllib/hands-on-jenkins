# CarVilla CI/CD Pipeline

This guide will help you implement a complete CI/CD pipeline for the CarVilla web application using AWS, Terraform, Ansible, Kubernetes, Jenkins, and Docker.

> This repository is an improved version of the original setup, where the Kubernetes cluster creation is automated. However, the Jenkins implementation will be performed manually.

## Architecture Overview

This setup includes:

1. AWS infrastructure managed by Terraform
2. Configuration automated with Ansible
3. Kubernetes cluster with master and worker nodes
4. Jenkins for CI/CD pipeline management
5. Private Docker registry

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI installed and configured
- Terraform (version 0.14+)
- Ansible (version 2.9+)
- kubectl client
- Git

## 0. Getting Started

### Step 1: AWS Configuration

1. Ensure your AWS credentials are set up:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_SESSION_TOKEN="your-session-token"  # Optional, if using temporary credentials
```

Verify your AWS CLI configuration:

```bash
aws sts get-caller-identity
```

2. Check if you have an SSH key named `carvilla-key` or create one:

```bash
# Create a key pair if needed
aws ec2 create-key-pair --key-name carvilla-key --query 'KeyMaterial' --output text > ~/.ssh/carvilla-key.pem
chmod 400 ~/.ssh/carvilla-key.pem
```

### Step 2: Run the Deployment

The entire deployment can be run using a single script:

```bash
chmod +x deploy-infra.sh
./deploy-infra.sh
```

This will:
1. Check for prerequisites
2. Provision AWS infrastructure with Terraform
3. Configure the instances with Ansible
4. Set up Kubernetes cluster
5. Deploy Docker registry

#### Customization Options

##### 1. AWS Region and Instance Types

Edit `terraform-files/variables.tf` to change:
- AWS region
- EC2 instance types
- AMI ID (if needed for a different region)

##### 2. Network Configuration

Edit `terraform-files/main.tf` to modify:
- VPC CIDR block
- Subnet CIDR block
- Security group rules

##### 3. Kubernetes Configuration

Edit `ansible-files/playbooks/01-k8s-master.yml` to change:
- Kubernetes version
- Network plugin
- Pod CIDR range

##### 4. Jenkins Pipeline

Edit `jenkins-pipeline.groovy` to modify:
- GitHub repository URL (currently set to "https://github.com/ahargunyllib/hands-on-jenkins.git")
- Test procedures
- Deployment configurations

## 1. Jenkins Installation

Run the following commands on the `master node` to set up Jenkins
```bash
ssh -i ~/.ssh/carvilla-key.pem ubuntu@[master-ip]
```

### Step 1: Create a Namespace for DevOps Tools

```bash
kubectl create namespace devops-tools
```

### Step 2: Create a Persistent Volume for Jenkins Data

```bash
sudo mkdir -p /mnt/jenkins-data
sudo chmod 777 /mnt/jenkins-data
kubectl apply -f ~/hands-on-jenkins/k8s/jenkins-volume.yaml
```

### Step 3: Create Service Account for Jenkins

```bash
kubectl apply -f ~/hands-on-jenkins/k8s/jenkins-sa.yaml
```

### Step 4: Create Jenkins Deployment and Service

```bash
kubectl apply -f ~/hands-on-jenkins/k8s/jenkins-deployment.yaml
```

### Step 5: Wait for Jenkins to Start
```bash
kubectl get pods -n devops-tools -w
```

### Step 6: Create kubeconfig Secret for Jenkins
This step ensures Jenkins has proper access to the Kubernetes API:
```bash
# Create kubeconfig secret for Jenkins
kubectl create secret generic jenkins-kubeconfig \
  --from-file=config=/home/ubuntu/.kube/config \
  -n devops-tools || true
```

### Step 7: Get Jenkins Admin Password

#### Get the Jenkins pod name

```bash
JENKINS_POD=$(kubectl get pods -n devops-tools -l app=jenkins -o jsonpath="{.items[0].metadata.name}")
```
#### Get the initial admin password

```bash
kubectl exec -it $JENKINS_POD -n devops-tools -- cat /var/jenkins_home/secrets/initialAdminPassword
```

### Step 8: Access and Configure Jenkins
1. Access Jenkins at http://{MASTER_IP}:32000/
2. Enter the admin password obtained in the previous step
3. Install suggested plugins
4. Create an admin user when prompted:
5. Username: admin
6. Password: (choose a secure password)
7. Full name: Jenkins Admin
8. Email: your-email@example.com
9. Click "Save and Continue"
10. On the Instance Configuration page, confirm the Jenkins URL: http://{MASTER_IP}:32000/
11. Click "Save and Finish"

### Step 9: Install Required Plugins
1. Go to "Manage Jenkins" > "Manage Plugins" > "Available" tab
2. Search for and select the following plugins
- Kubernetes
- Docker Pipeline
- Pipeline: Kubernetes
- Git
- GitHub Integration
3. Click "Install without restart"
4. Check "Restart Jenkins when installation is complete and no jobs are running"

### Step 10: Configure Kubernetes Cloud
After Jenkins restarts:

1. Go to "Manage Jenkins" > "Manage Nodes and Clouds" > "Configure Clouds"
2. Click "Add a new cloud" > "Kubernetes"
3. Configure as follows:
- Name: k8s
- Kubernetes URL: https://{MASTER_IP}:6443
- Kubernetes Namespace: devops-tools
- Check "Disable HTTPS certificate check"
- Jenkins URL: http://jenkins.devops-tools.svc.cluster.local:8080
4. Click "Test Connection" to verify - you should see "Connection test successful"
5. Under "Pod Templates" > "Add Pod Template":
- Name: jenkins-agent
- Namespace: devops-tools
- Labels: jenkins-agent
6. Under "Container Templates" > "Add Container":
- Name: jnlp
- Docker image: jenkins/inbound-agent:latest
7. Click "Save"


### Step 11: Configure Docker Registry Access
Go to "Manage Jenkins" > "Manage Credentials" > "Jenkins" > "Global credentials" > "Add Credentials"
Configure as follows:
Kind: Username with password
Scope: Global
Username: (your registry username if needed, or leave blank for anonymous)
Password: (your registry password if needed, or leave blank for anonymous)
ID: docker-registry
Description: Docker Registry Credentials
Click "OK"

## 2. Pipeline Implementation

#### Step 1: Create the Jenkins Pipeline

1. Login to Jenkins at http://{MASTER_IP}:32000/
2. Click on "New Item" in the left menu
3. Enter "carvilla-pipeline" as the name and select "Pipeline"
4. Click "OK"
5. In the configuration page, scroll down to the "Pipeline" section
6. Choose "Pipeline script" and enter the following script from `jenkins-pipeline.groovy`
7. Click "Save"

#### Step 2: Triggering the Pipeline Manually

1. In Jenkins, navigate to the "carvilla-pipeline" project
2. Click "Build Now" in the left sidebar

This will start the pipeline execution, which will:
- Check out the code
- Run the tests
- Build a Docker image
- Push the image to your registry
- Deploy to Kubernetes
- Verify the deployment

#### Step 3: Setting Up Automatic Triggering (Optional)

To have the pipeline automatically triggered when code changes are pushed to the repository:

1. In Jenkins, go to "carvilla-pipeline" > "Configure"
2. Under "Build Triggers", select "GitHub hook trigger for GITScm polling"
3. Click "Save"

Then in your GitHub repository:
1. Go to Settings > Webhooks
2. Click "Add webhook"
3. Set the Payload URL to: `http://{MASTER_IP}:32000/github-webhook/`
4. Content type: application/json
5. Select "Just the push event"
6. Click "Add webhook"

## 3. Testing the Application

After successful deployment, you can access the CarVilla web application by visiting:

**URL:** http://{MASTER_IP}:40000

### Simple Test Commands

**On the master node ({MASTER_IP}):**

```bash
# Check if the service is running
kubectl get svc carvilla-web-service

# Check if the pods are running properly
kubectl get pods -l app=carvilla-web

# Test if the application is accessible
curl -I http://{MASTER_IP}:40000
```

## 4. Monitoring with Prometheus

Since Prometheus is already installed, you can set up basic monitoring for the application.

**On the master node ({MASTER_IP}):**

```bash
kubectl apply -f ~/hands-on-jenkins/k8s/service-monitor.yaml
```

## 5. Troubleshooting

### Terraform Deployment Issues

If Terraform fails to deploy:
```bash
# Clean up and try again
cd terraform
terraform destroy
terraform apply
```

### Ansible Configuration Issues

If an Ansible playbook fails:
```bash
# Run specific playbook with verbose output
cd ansible
ansible-playbook -vvv -i inventory/hosts.ini playbooks/[playbook-name].yml
```

### Kubernetes Issues

Check cluster status:
```bash
ssh -i ~/.ssh/carvilla-key.pem ubuntu@[master-ip]
kubectl get nodes
kubectl get pods --all-namespaces
```

### Jenkins Issues

Check Jenkins logs:
```bash
ssh -i ~/.ssh/carvilla-key.pem ubuntu@[master-ip]
kubectl logs -n devops-tools -l app=jenkins
```

### Problem: Image Pull Errors
- **Solution**: Ensure registry is accessible from worker nodes

**On the worker node ({WORKER_NODE}):**

```bash
curl -X GET http://{WORKER_NODE}:30500/v2/_catalog
```

### Problem: Website Not Loading
- **Solution**: Check if pods are running correctly

**On the master node ({MASTER_IP}):**

```bash
kubectl describe pods -l app=carvilla-web
kubectl logs -l app=carvilla-web
```

### Problem: Pipeline Fails at the Docker Build Stage
- **Solution**: Ensure Docker socket is accessible

**On the master node ({MASTER_IP}):**

```bash
ls -la /var/run/docker.sock
chmod 666 /var/run/docker.sock  # If needed
```

## 6. Pipeline Explanation

1. **Checkout Stage**: Retrieves the code from the Git repository
2. **Test Stage**: Runs the test script to ensure all required files are present
3. **Build and Push Stage**: Creates a Docker image and pushes it to your registry
4. **Deploy Stage**: Applies Kubernetes manifests to create/update the deployment and service
5. **Verify Stage**: Confirms the application is running correctly and accessible

## 7. Scaling the Application

If you need to handle more traffic, you can scale the application:

**On the master node ({MASTER_IP}):**

```bash
kubectl scale deployment carvilla-web --replicas=4
```

## 8. Conclusion

This CI/CD pipeline provides a complete workflow for deploying the CarVilla web application to your Kubernetes cluster. By following this module, you can:

1. Automatically test your application
2. Build and containerize it using Docker
3. Deploy it to Kubernetes with high availability
4. Make it accessible to users via a consistent URL
5. Monitor it using Prometheus

## 9. Additional Resources

### Cleanup

To destroy all resources when you're done:

```bash
cd terraform
terraform destroy

cd ..
rm -rf terraform/
rm -rf ansible/
```

### Cost Consideration

This deployment uses t3.medium instances which are charged by the hour. Make sure to clean up resources when they're not needed to avoid unnecessary expenses.
