provider "aws" {
  region = var.aws_region
}

# VPC Configuration
resource "aws_vpc" "carvilla_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "carvilla-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "carvilla_igw" {
  vpc_id = aws_vpc.carvilla_vpc.id

  tags = {
    Name = "carvilla-igw"
  }
}

# Public Subnet
resource "aws_subnet" "carvilla_public_subnet" {
  vpc_id                  = aws_vpc.carvilla_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "carvilla-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "carvilla_public_rt" {
  vpc_id = aws_vpc.carvilla_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.carvilla_igw.id
  }

  tags = {
    Name = "carvilla-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "carvilla_public_rt_assoc" {
  subnet_id      = aws_subnet.carvilla_public_subnet.id
  route_table_id = aws_route_table.carvilla_public_rt.id
}

# Security Group for Kubernetes Master
resource "aws_security_group" "k8s_master_sg" {
  name        = "k8s-master-sg"
  description = "Security group for Kubernetes master node"
  vpc_id      = aws_vpc.carvilla_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins web interface
  ingress {
    from_port   = 32000
    to_port     = 32000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # CarVilla application
  ingress {
    from_port   = 40000
    to_port     = 40000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Docker Registry
  ingress {
    from_port   = 30500
    to_port     = 30500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes NodePort range
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Flannel VXLAN
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # kube-scheduler
  ingress {
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # kube-controller-manager
  ingress {
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # etcd
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "k8s-master-sg"
  }
}

# Security Group for Kubernetes Worker
resource "aws_security_group" "k8s_worker_sg" {
  name        = "k8s-worker-sg"
  description = "Security group for Kubernetes worker node"
  vpc_id      = aws_vpc.carvilla_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes NodePort range
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic from master
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.k8s_master_sg.id]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Flannel VXLAN
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all traffic within VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "k8s-worker-sg"
  }
}

# EC2 Instance for Kubernetes Master
resource "aws_instance" "k8s_master" {
  ami                    = var.ami_id
  instance_type          = var.master_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k8s_master_sg.id]
  subnet_id              = aws_subnet.carvilla_public_subnet.id

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  tags = {
    Name = "k8s-master"
    Role = "master"
  }
}

# EC2 Instance for Kubernetes Worker
resource "aws_instance" "k8s_worker" {
  ami                    = var.ami_id
  instance_type          = var.worker_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k8s_worker_sg.id]
  subnet_id              = aws_subnet.carvilla_public_subnet.id

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  tags = {
    Name = "k8s-worker"
    Role = "worker"
  }
}

# Create a local inventory file for Ansible
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tmpl",
    {
      master_ip = aws_instance.k8s_master.public_ip,
      worker_ip = aws_instance.k8s_worker.public_ip
    }
  )
  filename = "../ansible/inventory/hosts.ini"
}

# Create Ansible variables file with EC2 instance IPs
resource "local_file" "ansible_vars" {
  content = templatefile("${path.module}/templates/vars.tmpl",
    {
      master_ip = aws_instance.k8s_master.public_ip,
      worker_ip = aws_instance.k8s_worker.public_ip,
      master_private_ip = aws_instance.k8s_master.private_ip,
      worker_private_ip = aws_instance.k8s_worker.private_ip
    }
  )
  filename = "../ansible/vars/ec2_instances.yml"
}

# Output the public IPs of the instances
output "master_public_ip" {
  value = aws_instance.k8s_master.public_ip
}

output "worker_public_ip" {
  value = aws_instance.k8s_worker.public_ip
}

output "master_private_ip" {
  value = aws_instance.k8s_master.private_ip
}

output "worker_private_ip" {
  value = aws_instance.k8s_worker.private_ip
}

output "jenkins_url" {
  value = "http://${aws_instance.k8s_master.public_ip}:32000"
}

output "carvilla_app_url" {
  value = "http://${aws_instance.k8s_master.public_ip}:40000"
}

output "docker_registry_url" {
  value = "${aws_instance.k8s_master.public_ip}:30500"
}
