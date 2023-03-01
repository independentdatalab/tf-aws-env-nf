////////////////////////////////////////////////////////////////////////////////
// Base AMI for AWS Batch (Nextflow)
////////////////////////////////////////////////////////////////////////////////

// Batch image with 1000G root storage for NF

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_security_group" "allow_ssh_batch" {
  name        = "allow_ssh_batch"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_default_vpc.default.id 

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "allow_ssh_batch"
  }
}
resource "aws_network_interface" "base_batch" {
  subnet_id   = aws_default_subnet.default.id
  security_groups = [aws_security_group.allow_ssh_batch.id]
  tags = {
    Name = "default_network_interface"
  }
}

// Get the latest ECS optimized AMI
data "aws_ami" "ecs_ami" {
  most_recent      = true
  owners           = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*"]
  }

  filter {
    name = "architecture"
    values = ["x86_64"]
  }

}

// we need to create an instance from ami to add 1000 ebs and to install awscli, 
// which is required by Nextflow
resource "aws_instance" "base_batch_nf" {
  ami           = data.aws_ami.ecs_ami.id
  instance_type = "t2.medium"
  key_name      = "<KEY.PAIR>"

  //install awscli via miniconda as per Nextflow documentation
  user_data = <<-EOL
#!/bin/bash -xe
yum update -y
yum install -y bzip2 wget
export HOME=/home/ec2-user
cd $HOME
wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -f -p $HOME/miniconda
$HOME/miniconda/bin/conda install -c conda-forge -y awscli
rm Miniconda3-latest-Linux-x86_64.sh  

EOL

  tags = {
    Name = "base-batch-ami"
  }

  network_interface {
    network_interface_id = aws_network_interface.base_batch.id
    device_index = 0
  }

  root_block_device {
    volume_size = 1000
  }
}

/* 
//UNCOMMENT AFTER THE INSTANCE ABOVE CREATED
// and now we create ami from the instance above
resource "aws_ami_from_instance" "base_batch_nf_ami" {
  name               = "base_batch_nf_ami"
  source_instance_id = aws_instance.base_batch_nf.id
}
//UNCOMMENT AFTER THE INSTANCE ABOVE CREATED
*/ 
