/*
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}


resource "aws_vpc_peering_connection" "peer" {
  peer_vpc_id = aws_default_vpc.default.id
  vpc_id = aws_vpc.aws-vpc.id

  tags = {
    Name : "OPC to Default VPC Peer"
  }
}

data "aws_ami" "amazon-linux-2-ami" {
  owners = [
    "amazon"]
  most_recent = true

  filter {
    name = "name"
    values = [
      "amzn2-ami-hvm*"]
  }

  filter {
    name = "architecture"
    values = [
      "x86_64"]
  }
}

resource "aws_instance" "opc-jump-box" {
  ami = var.jump-ami
  instance_type = "t2.micro"
  associate_public_ip_address = true
  key_name = aws_key_pair.imac-ssh-key.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "jump01"
  }
}

resource "aws_security_group" "allow_ssh" {
  name = "bastion-ssh"
  description = "Allow inbound SSH traffic from my IP"
  vpc_id = aws_default_vpc.default.id

  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = [
      "${var.home_ip}/32"]
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "imac-ssh-key" {
  key_name = "imac-ssh-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCne0eOrylbS2RaE3vV+ATK2gghzuMN9PxhVmN5CLMOaOw3TluLHtH0/NUUxLWV6eMK5Q1Qm9XyvVOE0AtGJ0xo3TAxwGfsBwEAk/BwVPbPHVucacFvy5cRMvZG1916OZmbteszr7uSh111E6wCJCGZA1QePAWV4W9LLeqhPFCB1kveLGEo5UAoj28kH6OFZwxAzYYIJc/49t0gmwdRVuTL4v0+qRPpXdQbEKv5lWXNIk0fP9HB1XPPQcxaity/bl4OiJUHrZXYTG4cPOAfRgfgX2K8uviFEa5uE2I1SYpkeAcLzHUgK+QvIcz9G3m4hrrfpoARmUieCUa8ITXdWIj+7l7fNOJc59YwmHPdA/6QOlD4AERM8YhJeSd+8xQJwVPQOxJ9GtO19oMar09gZxsOJkGuKiP61isXb6Dm57quSCvwFOFcYe2xVDeb0bW0lCdYW1a6UcFTFA9QCs0g37NIYgbT4uOsL82EzkKgWrVKijogrDza10s1FPwAR34ioseDf/Um2kSubiyNphryKs97x+hGzW1Y4MliMfWFdDV9XVI5r2uWdKKU2o6nm+u3U6/HFHh87ujkZou8w/EaJDHMPcsI0Q+ym1Xc5fel52OSB1T6mwuVGl7g6AS6dAGyeDKicYzb04WAyNXkoI6pvRes4sSIkZLknHqZOdXqE/N/Pw== a.abbaspour@gmail.com"
}

output "jump-box" {
  value = aws_instance.opc-jump-box.public_ip
}


resource "aws_route" "main-to-opc" {
  destination_cidr_block = var.vpcCIDRblock
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  route_table_id = aws_default_vpc.default.default_route_table_id
}

resource "aws_route" "opc-to-main" {
  destination_cidr_block = aws_default_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  route_table_id = aws_vpc.aws-vpc.default_route_table_id
}

*/
