resource "aws_vpc" "aws-vpc" {
  cidr_block = var.vpcCIDRblock
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "OPA SaaS VPC"
  }
}

data "aws_availability_zones" "aws-az" {
  state = "available"
}

# https://docs.aws.amazon.com/quickstart/latest/vpc/architecture.html

resource "aws_subnet" "private_subnet" {
  count = var.opa_az_count
  vpc_id = aws_vpc.aws-vpc.id
  cidr_block = cidrsubnet(var.privateCIDRblock, 2, count.index)
  availability_zone = data.aws_availability_zones.aws-az.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.app_name}-private-${count.index + 1}"
    Environment = var.app_environment
  }
}

resource "aws_subnet" "public_subnet" {
  count = var.public_az_count
  vpc_id = aws_vpc.aws-vpc.id
  cidr_block = cidrsubnet(var.publicCIDRblock, 2, count.index)
  availability_zone = data.aws_availability_zones.aws-az.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.app_name}-public-${count.index + 1}"
    Environment = var.app_environment
  }
}

resource "aws_subnet" "nat_subnet" {
  count = var.opa_az_count
  vpc_id = aws_vpc.aws-vpc.id
  cidr_block = cidrsubnet(var.natCIDRblock, 2, count.index)
  availability_zone = data.aws_availability_zones.aws-az.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.app_name}-nat-${count.index + 1}"
    Environment = var.app_environment
  }
}


/*
resource "aws_subnet" "nat_unused" {
  count = 1
  vpc_id = aws_vpc.aws-vpc.id
  cidr_block = cidrsubnet(var.natCIDRblock, 2, count.index + 1)
  availability_zone = data.aws_availability_zones.aws-az.names[1]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.app_name}-nat-unused-${count.index + 1}"
    Environment = var.app_environment
  }
}
*/

/*
resource "aws_subnet" "private_unused" {
  count = 1
  vpc_id = aws_vpc.aws-vpc.id
  cidr_block = cidrsubnet(var.privateCIDRblock, 2, count.index + 1)
  availability_zone = data.aws_availability_zones.aws-az.names[1]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.app_name}-private-unused-${count.index + 1}"
    Environment = var.app_environment
  }
}
*/

/*
data "aws_subnet_ids" "default" {
  vpc_id = aws_vpc.aws-vpc.id
  filter {
    name = "tag:Name"
    values = [
      "${var.app_name}-subnet-*"]
  }
}

data "aws_subnet_ids" "db" {
  vpc_id = aws_vpc.aws-vpc.id
  filter {
    name = "tag:Name"
    values = [
      "${var.app_name}-db-subnet-*"]
  }
}
*/

## EIP & NAT Gateway
resource "aws_eip" "nat_eip" {
  vpc = true
  depends_on = [
    aws_internet_gateway.aws-igw]
}

/*
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.public_subnet[0].id
  tags = {
    Name = "${var.app_name}-nat"
    Environment = var.app_environment
  }
}
*/

# create internet gateway
resource "aws_internet_gateway" "aws-igw" {
  vpc_id = aws_vpc.aws-vpc.id
  tags = {
    Name = "${var.app_name}-igw"
    Environment = var.app_environment
  }
}

# create routes
resource "aws_route_table" "aws-route-table" {
  vpc_id = aws_vpc.aws-vpc.id
  tags = {
    Name = "${var.app_name}-route-table"
    Environment = var.app_environment
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.aws-vpc.id
  tags = {
    Name        = "${var.app_name}-public-route-table"
    Environment = var.app_name
  }
}

resource "aws_route_table" "nat" {
  vpc_id = aws_vpc.aws-vpc.id
  tags = {
    Name        = "${var.app_name}-nat-route-table"
    Environment = var.app_name
  }
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.aws-igw.id
}

resource "aws_route_table_association" "public" {
  count          = var.public_az_count
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "nat_route" {
  route_table_id         = aws_route_table.nat.id
  destination_cidr_block = "0.0.0.0/0"
  //nat_gateway_id         = aws_nat_gateway.nat.id
  instance_id            = aws_instance.nat_instance.id
}

resource "aws_route_table_association" "nat" {
  count          = var.opa_az_count// length(var.publicCIDRblock)
  subnet_id      = element(aws_subnet.nat_subnet.*.id, count.index)
  route_table_id = aws_route_table.nat.id
}

resource "aws_main_route_table_association" "aws-route-table-association" {
  vpc_id = aws_vpc.aws-vpc.id
  route_table_id = aws_route_table.aws-route-table.id
}

resource "aws_route_table_association" "subnet" {
  route_table_id = aws_route_table.aws-route-table.id
  subnet_id = aws_subnet.private_subnet[0].id
}

resource "aws_security_group" "lb" {
  name        = "lb-sg"
  description = "controls access to the Application Load Balancer (ALB)"
  vpc_id = aws_vpc.aws-vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## ECR
resource "aws_ecr_repository" "repo" {
  name = "myopa"
}

resource "aws_ecr_lifecycle_policy" "repo-policy" {
  repository = aws_ecr_repository.repo.name
  policy = file("./ecr-policy.json")
}

/*
resource "aws_s3_bucket_object" "discovery_bundle" {
  bucket = aws_s3_bucket.s3_data_bucket.bucket
  key = "discovery/discovery.tar.gz"
  source = var.discovery_file
  etag   = filemd5(var.discovery_file)
}

resource "aws_s3_bucket_object" "p1_bundle" {
  bucket = aws_s3_bucket.s3_data_bucket.bucket
  key = "bundle/bundle.tar.gz"
  source = var.bundle_file_p1
  etag   = filemd5(var.bundle_file_p1)
}
*/

## vpc endpoints
/*
resource "aws_vpc_endpoint" "ecr-dkr" {
  vpc_id = aws_vpc.aws-vpc.id
  service_name = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = aws_subnet.nat_subnet.*.id
  security_group_ids = [
    aws_security_group.vpce.id]

  tags = {
    Name = "dkr-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr-api" {
  vpc_id = aws_vpc.aws-vpc.id
  service_name = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = aws_subnet.nat_subnet.*.id
  security_group_ids = [
    aws_security_group.vpce.id]
  tags = {
    Name = "ecr-endpoint"
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id = aws_vpc.aws-vpc.id
  service_name = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = aws_subnet.nat_subnet.*.id
  security_group_ids = [
    aws_security_group.vpce.id]
  tags = {
    Name = "logs-endpoint"
  }
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id = aws_vpc.aws-vpc.id
  service_name = "com.amazonaws.${var.region}.sqs"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = aws_subnet.nat_subnet.*.id
  security_group_ids = [
    aws_security_group.vpce.id]
  tags = {
    Name = "sqs-endpoint"
  }
}
*/

/*
resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.aws-vpc.id
  service_name = "com.amazonaws.${var.region}.s3"

  tags = {
    Name = "s3-endpoint"
  }
}

output "s3_vpce_id" {
  value = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint_route_table_association" "s3" {
  route_table_id = aws_route_table.nat.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_security_group" "vpce" {
  name = "inbound-https"
  description = "allow inbound https"
  vpc_id = aws_vpc.aws-vpc.id

  ingress {
    description = "outbound HTTPS"
    from_port = 443
    protocol = "tcp"
    to_port = 443
    cidr_blocks = [
      aws_vpc.aws-vpc.cidr_block]
  }
}

resource "aws_vpc_endpoint" "api-gateway" {
  vpc_id = aws_vpc.aws-vpc.id
  service_name = "com.amazonaws.${var.region}.execute-api"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids = aws_subnet.nat_subnet.*.id ## TODO this is insecure
  security_group_ids = [
    aws_security_group.vpce.id]
  tags = {
    Name = "api-gateway-endpoint"
  }
}
*/


## NAT instance
resource "aws_security_group" "nat_with_ssh" {
  name = "nat_with_ssh"
  description = "Allow inbound SSH traffic from my IP. NAT outgoing"
  vpc_id = aws_vpc.aws-vpc.id

  ingress {
    from_port = -1
    protocol = "icmp"
    to_port = -1
    cidr_blocks = [ var.natCIDRblock ]
  }

  ingress {
    from_port = 443
    protocol = "tcp"
    to_port = 443
    cidr_blocks = [ var.natCIDRblock ]
  }

  ingress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = [ var.natCIDRblock ]
  }

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
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}


resource "aws_instance" "nat_instance" {
  ami = var.jump-ami
  instance_type = "t2.micro"
  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name
  vpc_security_group_ids = [
    aws_security_group.nat_with_ssh.id]
  subnet_id = aws_subnet.public_subnet[0].id
  source_dest_check = false

  user_data = <<EOF
#!/bin/bash
sysctl -w net.ipv4.ip_forward=1
/sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
EOF

  tags = {
    Name = "nat"
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.nat_instance.id
  allocation_id = aws_eip.nat_eip.id
}

resource "aws_key_pair" "ssh-key" {
  key_name = "ssh-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC5DDDwmTDLK206b1ls0IGccZZlbyXVt2fVHI3pDHMIfYHhmpoqYA2NZL/D33yW7IdNKHIUOzQKROSjZgOZzgfu/v2RTr9LCJqlL55vqRuYovFTK53GBC8b7+i2NmOUGqHCB7YibPaDXsZFE2e1mAWqmXWCvfWZ3YIBSFPsgS3Fku7vgWFEVHw4M/7Dk5QHYahm7RHyRPvpl5nghLWgkjK7DxfV+hS0eUEAZD5mV4ctsVQfHChusrJ82i9YECyy+PTXvEjepSa0k8h7ScVO9ygMfqju7ArFlVqNrP2E1fRO1m1lX1PEa4BFJ7ybHpID7b2W37wJeDhOTMMlEeZViVS5"
}

output "NAT" {
  value = aws_instance.nat_instance.public_ip
}
