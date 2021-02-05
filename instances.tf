///////////////////////////////////////////////////////////////////////////////
// basic instance to download files and run analyses pipelines
///////////////////////////////////////////////////////////////////////////////

data "aws_ami" "ubuntu_2004" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Canonical
  owners = ["099720109477"]
}

resource "aws_instance" "basic" {
  ami = data.aws_ami.ubuntu_2004.id 
  instance_type = "t2.micro"

  # needed for ssh connection (who will connect)
  key_name      = "<KEY.PAIR>"
  # needed for ssh connection (allow inbound traffic)
  security_groups = [aws_security_group.allow_ssh.name]

  root_block_device {
    volume_size = 30 
  }

  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_size = 100
    volume_type = "standard"
  }

  tags = {
    Name = "basic"
  }
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
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
    Name = "allow_ssh"
  }
}

