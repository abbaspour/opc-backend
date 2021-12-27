data "aws_iam_policy_document" "ecs_task_execution_role" {
  version = "2012-10-17"
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs-staging-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

resource "aws_iam_role" "ecs_task_role" {
  name = "role-name-task"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_ecs_task_definition" "ssh-service" {
  family                   = "ssh-app-staging"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
  container_definitions    = templatefile("./ssh-task-def.json.tpl",
    {
      aws_ecr_repository = aws_ecr_repository.repo.repository_url
      tag                = "latest"
      aws_region         = var.region
      ecs_ssh_user       = var.ecs_ssh_user
      ecs_ssh_pass       = var.ecs_ssh_pass
    }
  )

  tags = {
    Environment = "staging"
    Application = "SSH"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_service" "ssh" {
  name            = "ssh"
  cluster         = aws_ecs_cluster.staging.id
  task_definition = aws_ecs_task_definition.ssh-service.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    security_groups  = [aws_security_group.ssh_tasks_sg.id]
    //subnets          = aws_subnet.aws-subnet.*.id
    subnets          = aws_subnet.nat_subnet.*.id
    assign_public_ip = false
  }

  /*
  load_balancer {
    target_group_arn = aws_lb_target_group.staging.arn
    container_name   = "ssh-task"
    container_port   = 2222
  }
  */

  depends_on = [
    //aws_lb_listener.https_forward,
    aws_iam_role_policy_attachment.ecs_task_execution_role,
    aws_cloudwatch_log_group.ssh-log-group
  ]

  tags = {
    Environment = var.app_environment
    Application = var.app_name
  }

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }
}

resource "aws_cloudwatch_log_group" "ssh-log-group" {
  name = "awslogs-ssh"
  retention_in_days = 3

  tags = {
    Environment = var.app_environment
    Application = "SSH"
  }
}

resource "aws_security_group" "ssh_tasks_sg" {
  name        = "ssh_tasks_sg"
  description = "allow inbound access from the ALB only"
  vpc_id = aws_vpc.aws-vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = 2222
    to_port         = 2222
    cidr_blocks     = ["0.0.0.0/0"]
    #security_groups = [aws_security_group.lb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

}
