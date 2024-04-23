terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  profile = "iamadmin"
}

terraform {
  backend "s3" {
    bucket  = "tfstate-bucket-observe-with-grafana"
    key     = "build/terraform.tfstate"
    region  = "us-east-1"
  }
}


data "aws_key_pair" "ansible_labsetup_kp" {
  key_name           = "ansible_labsetup_kp"
}


resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = "tfstate-bucket-observe-with-grafana"
  lifecycle {
    prevent_destroy = true
  }
}

# vpc 
resource "aws_default_vpc" "default_vpc" {

  tags = {
    Name = "default vpc"
  }
}
# use data source to get all avalablility zones in region
data "aws_availability_zones" "available_zones" {}

## create default subnet if one does not exit
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name = "default subnet 1"
  }
}
resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.available_zones.names[1]

  tags = {
    Name = "default subnet 2"
  }
}

# create security group for the ansible machine
resource "aws_security_group" "ec2_sg" {
  name        = "ec2 security group controller"
  description = "allow access on ports 80 and 22"
  vpc_id      =  aws_default_vpc.default_vpc.id

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["176.176.113.80/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-controller-sg"
  }
}

resource "aws_security_group" "ec2_sg_Nodes" {
  name        = "ec2 security group nodes"
  description = "allow access on ports 80 and 22 on server Nodes"
  vpc_id      = aws_default_vpc.default_vpc.id

  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups =  [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-nodes-sg"
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "controller_instance" {
  ami           = data.aws_ami.amazon_linux_2023.id # replace with your AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name = data.aws_key_pair.ansible_labsetup_kp.key_name
  user_data = file("setupController.sh")
  tags = {
    Name = "controller_instance"
  }
}

resource "aws_instance" "node_instances" {
  ami           = data.aws_ami.amazon_linux_2023.id # replace with your AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_default_subnet.default_az2.id
  vpc_security_group_ids = [aws_security_group.ec2_sg_Nodes.id]
  count = 2
  #key_name = data.aws_key_pair.ansible_labsetup_kp.key_name

  tags = {
    Name = "node_instances"
  }
}

output "ec2_controller_public_ipv4" {
  value = aws_instance.controller_instance.public_ip
}

output "ec2_nodes_private_ipv4_1" {
  value = aws_instance.node_instances[0].private_ip
}
output "ec2_nodes_private_ipv4_2" {
  value = aws_instance.node_instances[1].private_ip
}