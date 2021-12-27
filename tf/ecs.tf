// TODO: multiple ecs cluster based on shards
resource "aws_ecs_cluster" "staging" {
  name = "opa-ecs-cluster"
}

resource "aws_security_group" "ecs_tasks" {
  name = "ecs-tasks-sg"
  description = "allow inbound access from the ALB only"
  vpc_id = aws_vpc.aws-vpc.id

  ingress {
    protocol = "tcp"
    from_port = 80
    to_port = 80
    security_groups = [aws_security_group.opa_lb_sg.id, aws_security_group.nat_with_ssh.id]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}


## S3
resource "aws_s3_bucket" "s3_data_bucket" {
  bucket = var.s3_opa_bundles_bucket
  acl = "private"

  tags = {
    Name = "OPA Bundle data"
  }
}

## ALB with account_no header based groups
resource "aws_security_group" "opa_lb_sg" {
  name = "OPA Smart ECS LB security group"
  vpc_id = aws_vpc.aws-vpc.id

  egress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = [
      var.vpcCIDRblock]
  }

  ingress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    security_groups = [
      aws_security_group.opa_vpc_link_sg.id,
      aws_security_group.nat_with_ssh.id]
  }
}

resource "aws_lb" "opa_ecs_lb" {
  name = "OPA-smart-LB"
  internal = true
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.opa_lb_sg.id]
  subnets = aws_subnet.nat_subnet.*.id
  enable_deletion_protection = true

  tags = {
    Environment = "dev"
  }
}

resource "aws_lb_listener" "opa_ecs_lb_listener" {
  load_balancer_arn = aws_lb.opa_ecs_lb.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "account not found"
      status_code = "404"
    }
  }
}

## Outputs for opc-accounts vars
output "listener_arn" {
  value = aws_lb_listener.opa_ecs_lb_listener.arn
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.staging.arn
}

output "ecs_cluster_subnets" {
  value = aws_subnet.nat_subnet.*.id
}

output "ecs_sg_id" {
  value = aws_security_group.ecs_tasks.id
}
