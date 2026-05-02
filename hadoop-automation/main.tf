provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "hadoop_sg" {
  name        = "hadoop_automated_sg"
  description = "Allow Hadoop web interfaces and internal traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9870
    to_port     = 9870
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "hadoop_master" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  key_name      = "vockey" 
  vpc_security_group_ids = [aws_security_group.hadoop_sg.id]

  root_block_device {
    volume_size = 10 
  }
  tags = { 
    Name = "Hadoop-Master"
    Role = "master"
  }
}

resource "aws_instance" "hadoop_workers" {
  count         = 3
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = "vockey" 
  vpc_security_group_ids = [aws_security_group.hadoop_sg.id]

  root_block_device {
    volume_size = 10 
  }
  tags = { 
    Name = "Hadoop-Worker-${count.index + 1}"
    Role = "worker"
  }
}
