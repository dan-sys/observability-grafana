!#/usr/bin/env bash

#fail if any error encountered
set -eu

#change hostname
sudo hostnamectl set-hostname controller

sudo yum update -y
sudo amazon-linux-extras install ansible2 -y
wget 
echo ansible --version

ssh-keygen -t rsa -b 2048 -f /home/ec2-user/.ssh/id_rsa -q -P ""


cd .ssh















