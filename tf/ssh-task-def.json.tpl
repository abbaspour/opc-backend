[
  {
    "name": "ssh-task",
    "image": "linuxserver/openssh-server",
    "essential": true,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "${aws_region}",
        "awslogs-stream-prefix": "ssh-task",
        "awslogs-group": "awslogs-ssh"
      }
    },
    "portMappings": [
      {
        "containerPort": 2222,
        "hostPort": 2222,
        "protocol": "tcp"
      }
    ],
    "cpu": 1,
    "environment": [
      {
        "name": "PUID",
        "value": "1000"
      },
      {
        "name": "PGID",
        "value": "1000"
      },
      {
        "name": "TZ",
        "value": "Australia/Sydney"
      },
      {
        "name": "PUBLIC_KEY",
        "value": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC5DDDwmTDLK206b1ls0IGccZZlbyXVt2fVHI3pDHMIfYHhmpoqYA2NZL/D33yW7IdNKHIUOzQKROSjZgOZzgfu/v2RTr9LCJqlL55vqRuYovFTK53GBC8b7+i2NmOUGqHCB7YibPaDXsZFE2e1mAWqmXWCvfWZ3YIBSFPsgS3Fku7vgWFEVHw4M/7Dk5QHYahm7RHyRPvpl5nghLWgkjK7DxfV+hS0eUEAZD5mV4ctsVQfHChusrJ82i9YECyy+PTXvEjepSa0k8h7ScVO9ygMfqju7ArFlVqNrP2E1fRO1m1lX1PEa4BFJ7ybHpID7b2W37wJeDhOTMMlEeZViVS5"
      },
      {
        "name": "USER_NAME",
        "value": "${ecs_ssh_user}"
      },
      {
        "name": "USER_PASSWORD",
        "value": "${ecs_ssh_pass}"
      },
      {
        "name": "SUDO_ACCESS",
        "value": "true"
      },
      {
        "name": "PASSWORD_ACCESS",
        "value": "true"
      }
    ],
    "ulimits": [
      {
        "name": "nofile",
        "softLimit": 65536,
        "hardLimit": 65536
      }
    ],
    "mountPoints": [],
    "memory": 512,
    "volumesFrom": []
  }
]
