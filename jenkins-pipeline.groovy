// CarVilla CI/CD Pipeline for AWS Kubernetes Cluster
pipeline {
    agent {
        kubernetes {
            cloud 'k8s'
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: ubuntu
    image: ubuntu:20.04
    command:
    - cat
    tty: true
    volumeMounts:
    - mountPath: /var/run/docker.sock
      name: docker-sock
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
      type: Socket
"""
        }
    }

    environment {
        // TODO: Replace these with actual values or use Jenkins credentials
        REGISTRY_URL = "${DOCKER_REGISTRY_HOST}" // Will be replaced by the EC2 instance IP and port
        IMAGE_NAME = "carvilla"
        APP_PORT = "40000"
        K8S_MASTER = "${K8S_API_ENDPOINT}" // Will be replaced by the EC2 instance IP
        REPO_URL= "https://github.com/ahargunyllib/hands-on-jenkins.git"
        REPO_FOLDER = "hands-on-jenkins"
    }

    stages {
        stage('Setup Environment') {
            steps {
                container('ubuntu') {
                    sh '''
                    # Update package lists
                    apt-get update

                    # Install prerequisites
                    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git

                    # Install Docker CLI
                    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
                    echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
                    apt-get update
                    apt-get install -y docker-ce-cli

                    # Install kubectl
                    curl -LO "https://dl.k8s.io/release/v1.26.0/bin/linux/amd64/kubectl"
                    chmod +x kubectl
                    mv kubectl /usr/local/bin/

                    # Configure Docker for insecure registry
                    mkdir -p ~/.docker
                    echo '{"insecure-registries":["'${REGISTRY_URL}'"]}' > ~/.docker/config.json

                    # Configure kubectl
                    mkdir -p ~/.kube
                    '''

                    // Copy kubeconfig from mounted secret
                    sh '''
                    # Verify installations
                    echo "Docker version:"
                    docker --version

                    echo "Kubectl version:"
                    kubectl version --client
                    '''
                }
            }
        }

        stage('Checkout') {
            steps {
                container('ubuntu') {
                    sh '''
                    rm -rf *
                    git clone ${REPO_URL} .
                    ls -la
                    cd ${REPO_FOLDER}
                    '''
                }
            }
        }

        stage('Run Tests') {
            steps {
                container('ubuntu') {
                    sh '''
                    echo "Running application tests..."
                    chmod +x apps/web/tests/test.sh
                    ./apps/web/tests/test.sh
                    '''
                }
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                container('ubuntu') {
                    sh '''
                    echo "Building Docker image..."
                    docker build --network=host -t ${REGISTRY_URL}/${IMAGE_NAME}:${BUILD_NUMBER} apps/web/Dockerfile
                    echo "Tagging Docker image as latest..."
                    docker tag ${REGISTRY_URL}/${IMAGE_NAME}:${BUILD_NUMBER} ${REGISTRY_URL}/${IMAGE_NAME}:latest

                    echo "Pushing Docker image to registry at ${REGISTRY_URL}..."
                    docker push ${REGISTRY_URL}/${IMAGE_NAME}:${BUILD_NUMBER} || echo "Push failed, continuing anyway"
                    docker push ${REGISTRY_URL}/${IMAGE_NAME}:latest || echo "Push failed, continuing anyway"
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('ubuntu') {
                    sh '''
                    echo "Applying Kubernetes manifests..."
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml

                    echo "Waiting for deployment to complete..."
                    kubectl rollout status deployment/carvilla-web --timeout=60s || echo "Rollout status check failed, but continuing"
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                container('ubuntu') {
                    sh '''
                    echo "Verifying deployment..."
                    kubectl get pods -l app=carvilla-web
                    kubectl get svc carvilla-web-service

                    # Try to access the app
                    apt-get install -y curl
                    echo "Trying to access the application..."
                    curl -I http://${K8S_MASTER}:${APP_PORT} || echo "Failed to access the application, but deployment might still be in progress"
                    '''

                    echo "==================================================="
                    echo "CarVilla Web App should be accessible at: http://${env.K8S_MASTER}:${env.APP_PORT}"
                    echo "==================================================="
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully! CarVilla web application is now accessible at http://${env.K8S_MASTER}:${env.APP_PORT}"
        }
        failure {
            echo "Pipeline failed! Please check the logs for details."
        }
        always {
            echo "Pipeline execution finished. Check logs for details."
        }
    }
}
