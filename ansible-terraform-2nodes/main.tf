# Configure the AWS provider
provider "aws" {
  region = "us-east-1"  # Change to your desired AWS region
}

# Create a security group to allow SSH and HTTP access
resource "aws_security_group" "allow_ssh_http" {
  name_prefix = "allow_ssh_http"

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}

# Define EC2 instance for node1
resource "aws_instance" "node1" {
  ami           = "ami-066784287e358dad1"  # ec2-user 18.04 LTS AMI, update as needed
  instance_type = "t2.micro"
  key_name      = "Your-pem-key"
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]

  tags = {
    Name = "node1"
  }

  # Get the private IP address for the inventory file
  provisioner "local-exec" {
    command = "echo ${self.private_ip} > node1_ip.txt"
  }
}

# Define EC2 instance for node2
resource "aws_instance" "node2" {
  ami           = "ami-066784287e358dad1"  # ec2-user 18.04 LTS AMI, update as needed
  instance_type = "t2.micro"
  key_name      = "Your-pem-key"
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]

  tags = {
    Name = "node2"
  }

  # Get the private IP address for the inventory file
  provisioner "local-exec" {
    command = "echo ${self.private_ip} > node2_ip.txt"
  }
}

# Define EC2 instance for control plane
resource "aws_instance" "controlplane" {
  ami           = "ami-066784287e358dad1"  # ec2-user 18.04 LTS AMI, update as needed
  instance_type = "t2.micro"
  key_name      = "Your-pem-key"
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]

  tags = {
    Name = "controlplane"
  }

  # Copy the PEM file to control plane instance and set permissions
  provisioner "file" {
    source      = "~/.ssh/Your-pem-key"
    destination = "/home/ec2-user/Your-pem-key"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/Your-pem-key")
      host        = self.public_ip
    }
  }

  # Set the correct permissions for the PEM file
  provisioner "remote-exec" {
    inline = [
      "chmod 400 /home/ec2-user/Your-pem-key"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/Your-pem-key")
      host        = self.public_ip
    }
  }

  
  provisioner "file" {
    source      = "node1_ip.txt"
    destination = "/home/ec2-user/node1_ip.txt"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/Your-pem-key")
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "node2_ip.txt"
    destination = "/home/ec2-user/node2_ip.txt"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/Your-pem-key")
      host        = self.public_ip
    }
  }

  # Create the inventory file and ansible.cfg on control plane
  provisioner "remote-exec" {
    inline = [
       # Create the Ansible inventory file on the control plane
      "echo '[node1]' > /home/ec2-user/inventory",
      "echo 'node1_host ansible_host=$(cat node1_ip.txt) ansible_user=ec2-user' >> /home/ec2-user/inventory",
      "echo '[node2]' >> /home/ec2-user/inventory",
      "echo 'node2_host ansible_host=$(cat node2_ip.txt) ansible_user=ec2-user' >> /home/ec2-user/inventory",
      "echo '[controlplane]' >> /home/ec2-user/inventory",
      "echo 'controlplane_host ansible_host=${self.private_ip} ansible_user=ec2-user' >> /home/ec2-user/inventory",

      "echo '[defaults]' > /home/ec2-user/ansible.cfg",
      "echo 'host_key_checking = False' >> /home/ec2-user/ansible.cfg",
      "echo 'inventory = /home/ec2-user/inventory' >> /home/ec2-user/ansible.cfg",
      "echo 'deprecation_warnings=False' >> /home/ec2-user/ansible.cfg",
      "echo 'private_key_file = /home/ec2-user/Your-pem-key' >> /home/ec2-user/ansible.cfg",
      "echo 'remote_user = ec2-user' >> /home/ec2-user/ansible.cfg"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/Your-pem-key")
      host        = self.public_ip
    }
  }
}
