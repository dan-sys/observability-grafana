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


#data "aws_key_pair" "ansible_labsetup_kp" {
#  key_name           = "ansible_labsetup_kp"
#}

#resource "tls_private_key" "sample" {
#  algorithm = "RSA"
#  rsa_bits  = 2048
#}
#
#resource "aws_key_pair" "deployer" {
#  key_name   = "deployer-key"
#  public_key = tls_private_key.sample.public_key_openssh
#}

#resource "local_file" "private_key" {
#  sensitive_content = tls_private_key.example.private_key_pem
#  filename          = "${path.module}/private_key.pem"
#  file_permission   = "0600"
#}

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

locals {
  cloud_config_config = <<-END
    #cloud-config
    ${jsonencode({
      write_files = [
        {
          path        = "home/ec2-user/.ssh/"
          permissions = "0644"
          owner       = "ec2-user:ec2-user"
          encoding    = "b64"
          content     = filebase64("${path.module}/")
        },
      ]
    })}
  END
}
#
data "cloudinit_config" "samplecfg" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    filename     = "cloud-config.yaml"
    content      =  local.cloud_config_config
  }

  part {
    content_type = "text/x-shellscript"
    filename     = "setupController.sh"
    content = file("${path.module}/setupController.sh")
  }
  
}
#
resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.ini", {
    ip_addrs = [for i in aws_instance.node_instances:i.public_ip]
  })
  filename = "inventory.ini"
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
  #  local.cloud_config_config  data.cloudinit_config.samplecfg.rendered
  #
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



#
#output "private_key_pem" {
#  description = "The private key data in PEM format"
#  value       = tls_private_key.sample.private_key_pem
#  sensitive = true
#}
#
#output "public_key_pem" {
#  description = "The public key data in PEM format"
#  value       = tls_private_key.sample.public_key_pem
#}
#
#output "public_key_openssh" {
#  description = "The public key data in OpenSSH authorized_keys format"
#  value       = tls_private_key.sample.public_key_openssh
#}
#
output "ec2_controller_public_ipv4" {
  value = aws_instance.controller_instance.public_ip
}

output "ec2_nodes_private_ipv4_1" {
  value = aws_instance.node_instances[0].private_ip
}
output "ec2_nodes_private_ipv4_2" {
  value = aws_instance.node_instances[1].private_ip
}