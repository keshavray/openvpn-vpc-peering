provider "aws" {
  region     = "ap-south-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "bar" {
  cidr_block = "10.2.0.0/16"
}

resource "aws_subnet" "subnet-1" {

  cidr_block = "10.2.1.0/24"
  vpc_id     = aws_vpc.bar.id
}


resource "aws_vpc" "foo" {
  cidr_block = var.cidr_block
}

resource "aws_subnet" "subnet-11" {

  cidr_block = "10.1.1.0/24"
  vpc_id     = aws_vpc.foo.id
  availability_zone = "ap-south-1a"
}

resource "aws_vpc_peering_connection" "foovpc" {
  peer_vpc_id   = aws_vpc.bar.id
  vpc_id        = aws_vpc.foo.id
  auto_accept   = true

  tags = {
    Name = "VPC Peering between foo and bar"
  }
}

resource "aws_route" "route-foo" {
  route_table_id = aws_vpc.foo.default_route_table_id
  destination_cidr_block = "10.2.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.foovpc.id
}

resource "aws_route" "route-bar" {
  route_table_id = aws_vpc.bar.default_route_table_id
  destination_cidr_block = "10.1.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.foovpc.id
}

resource "aws_route" "route-foo-igw" {
  route_table_id = aws_vpc.foo.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gateway1.id
}

resource "aws_internet_gateway" "gateway1" {
  vpc_id = aws_vpc.foo.id
}

resource "aws_instance" "openvpn" {
  ami           = var.ami
  instance_type = var.instance_type
  ebs_optimized = false
  key_name      = var.key_name
  subnet_id     = aws_subnet.subnet-11.id
  vpc_security_group_ids = [
    aws_security_group.openvpn-sg.id
  ]
  user_data = <<-EOF
              #!/bin/bash
              admin_user=${var.openvpn_username}
              admin_pw=${var.openvpn_password}
              EOF

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 15
    delete_on_termination = false
  }

  tags = {
    Name = "Openvpn"
  }
}

resource "aws_security_group" "openvpn-sg" {
  name        = "openvpn-sg"
  description = "Security Group for openvpn"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  
  }

  ingress {
    from_port   = 943
    to_port     = 943
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.foo.id

  tags = {
    Name = "openvpn-SG"
  }
}

resource "aws_eip" "openvpn-eip" {
  instance = aws_instance.openvpn.id
  vpc      = true
  tags = {
    "Name" = "openvpn-eip"
  }
}
