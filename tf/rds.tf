/*
resource "aws_db_instance" "default" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t2.micro"
  name                 = "mydb"
  username             = "root"
  password             = var.db_pass
  parameter_group_name = aws_db_parameter_group.default.name // "default.mysql8.0"

  db_subnet_group_name = aws_db_subnet_group.default.id
  vpc_security_group_ids = [aws_security_group.rds.id]
}

resource "aws_db_parameter_group" "default" {
  name        = "opc-db-param-group"
  description = "opc parameter group for mysql8.0"
  family      = "mysql8.0"
  parameter {
    name  = "character_set_server"
    value = "utf8"
  }
  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
  parameter {
    name = "log_bin_trust_function_creators"
    value = "1"
  }
}

resource "aws_subnet" "db-subnet" {
  count = 2
  vpc_id = aws_vpc.aws-vpc.id
  cidr_block = cidrsubnet(var.dbCIDRblock, 2, count.index)
  availability_zone = data.aws_availability_zones.aws-az.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.app_name}-db-subnet-${count.index + 1}"
    Environment = var.app_environment
  }
}

resource "aws_db_subnet_group" "default" {

  subnet_ids = aws_subnet.db-subnet.*.id
}

resource "aws_security_group" "rds" {
  name        = "terraform_rds_security_group"
  description = "OPC RDS MySQL server"
  vpc_id      = aws_vpc.aws-vpc.id
  # Keep the instance private by only allowing traffic from the web server.
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    //security_groups = [aws_security_group.default.id]
  }

  ingress {
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    //security_groups = [aws_security_group.default.id]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
*/

/*
output "RDS_HOSTNAME" {
  value = aws_db_instance.default.address
}
*/
