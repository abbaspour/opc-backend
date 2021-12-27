/*
variable "get-root-name" {
  default = "get-root"
  description = "Lambda function name get-root"
  type        = string
}

variable "post-v1-data-name" {
  default = "post-v1-data"
  description = "Lambda function name post-v1-data"
  type        = string
}
*/

variable "post-token-name" {
  default = "post-token"
  description = "Lambda function POST /token"
  type        = string
}

/*
variable "get-v1-policies-name" {
  default = "get-v1-policies"
  description = "Lambda function name get-v1-policies"
  type        = string
}
*/

variable "create-account-name" {
  default = "create-account"
  description = "Lambda function name create-account"
  type        = string
}

/*
variable "put-v1-policy" {
  default = "put-v1-policy"
  description = "Lambda function name put-v1-policy"
  type        = string
}
*/

variable "update-policy-name" {
  default = "update-policy"
  description = "Lambda function name update-policy"
  type        = string
}

variable "status-queue-reader" {
  default = "status-queue-reader"
  description = "Lambda function name status-queue-reader"
  type        = string
}


variable "list-bundles-name" {
  default = "list-bundles"
  description = "Lambda function name list-bundles"
  type        = string
}

variable "list-policies-name" {
  default = "list-policies"
  description = "Lambda function name list-policies"
  type        = string
}

variable "list-instances-name" {
  default = "list-instances"
  description = "Lambda function name list-instances"
  type        = string
}

variable "get-instance-name" {
  default = "get-instance"
  description = "Lambda function name get-instance"
  type        = string
}

locals {
  start-stop-instance-name = "start-stop-instance"
}

resource "aws_lambda_function" "post-token" {
  function_name = var.post-token-name

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-post-token-0.1.0.zip"

  handler = "js/index.handler"
  runtime = "nodejs14.x"

  role = aws_iam_role.lambda_exec.arn
  timeout = 20

  vpc_config {
    security_group_ids = [aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.nat_subnet.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.post-token,
  ]

  environment {
      variables = {
        AUTH0_DOMAIN = var.auth0_domain
        AUDIENCE = auth0_resource_server.opc-api-rs.identifier
        AUTH0_CLIENT_ID = auth0_client.cli.client_id
        AUTH0_CLIENT_SECRET = auth0_client.cli.client_secret
        AUTH0_CONNECTION = auth0_connection.api-clients-db.name
        NODE_OPTIONS = "--enable-source-maps"
      }
    }
}

/*
resource "aws_lambda_function" "get-v1-policies" {
  function_name = "get-v1-policies"

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-get-v1-policies-0.1.0.zip"

  handler = "src/get-v1-policies.handler"
  runtime = "nodejs14.x"

  role = aws_iam_role.lambda_exec.arn

  vpc_config {
    security_group_ids = [aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.nat_subnet.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.get-v1-policies,
  ]
}
*/

resource "aws_lambda_function" "create-account" {
  function_name = var.create-account-name

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-create-account-0.1.3.zip"

  handler = "js/create-account.handler"
  runtime = "nodejs14.x"

  role = aws_iam_role.create_account_lambda.arn
  timeout = 60

  vpc_config {
    security_group_ids = [aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.nat_subnet.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.create-account,
  ]

  environment {
      variables = {
        // RDS_HOSTNAME = aws_db_instance.default.address,
        // RDS_USERNAME = var.lambda_create_account_db_user,
        // RDS_PASSWORD = var.lambda_create_account_db_pass,
        // RDS_DATABASE = var.rds_db_name,
        GITHUB_PERSONAL_TOKEN = var.github_personal_token
        GITHUB_OWNER = var.github_owner
        GITHUB_REPO = var.github_repo
        NODE_OPTIONS = "--enable-source-maps"
      }
    }
}

/*
resource "aws_lambda_function" "put-v1-policy" {
  function_name = "put-v1-policy"

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-${var.lambda_version}.zip"

  handler = "src/put-v1-policy.handler"
  runtime = "nodejs14.x"

  role = aws_iam_role.create_policy_lambda.arn

  vpc_config {
    security_group_ids = [aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.nat_subnet.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.put-v1-policy,
  ]

  environment {
      variables = {
        // RDS_HOSTNAME = aws_db_instance.default.address,
        RDS_USERNAME = var.lambda_create_account_db_user,
        RDS_PASSWORD = var.lambda_create_account_db_pass,
        RDS_DATABASE = var.rds_db_name,
        SQS_URL = aws_sqs_queue.policy_updates_queue.id
        BUNDLE_SYNC_SQS_URL = aws_sqs_queue.bundle_sync_queue.id
      }
    }
}
*/

resource "aws_lambda_function" "update-policy" {
  function_name = var.update-policy-name

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-update-policy-0.1.4.zip"

  handler = "src/update-policy.handler"
  runtime = "nodejs14.x"
  timeout = 20

  role = aws_iam_role.update_policy_lambda.arn

  vpc_config {
    security_group_ids = [aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.nat_subnet.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.update-policy,
  ]

  environment {
      variables = {
        SQS_URL = aws_sqs_queue.policy_updates_queue.id
        BUCKET = var.s3_opa_bundles_bucket
      }
    }

}

resource "aws_lambda_alias" "update-policy-alias" {
  name = "PROD"
  description = "PROD env alias"
  function_name = aws_lambda_function.update-policy.arn
  function_version = "$LATEST"

  depends_on = [
    aws_lambda_function.update-policy
  ]

  lifecycle {
    ignore_changes = [
      function_version
    ]
  }
}

resource "aws_lambda_function" "list-bundles" {
  function_name = var.list-bundles-name

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-list-repo-0.1.0.zip"

  handler = "list/app.handler"
  runtime = "nodejs14.x"
  timeout = 20

  role = aws_iam_role.list-repo_lambda.arn

  vpc_config {
    security_group_ids = [aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.nat_subnet.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.list-bundles,
  ]

  environment {
      variables = {
        TYPE = "bundles"
        BUCKET = var.s3_opa_bundles_bucket
        NODE_OPTIONS = "--enable-source-maps"
      }
    }
}

resource "aws_lambda_function" "list-policies" {
  function_name = var.list-policies-name

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-list-repo-0.1.0.zip"

  handler = "list/app.handler"
  runtime = "nodejs14.x"
  timeout = 20

  role = aws_iam_role.list-repo_lambda.arn

  vpc_config {
    security_group_ids = [aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.nat_subnet.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.list-policies,
  ]

  environment {
      variables = {
        TYPE = "policies"
        BUCKET = var.s3_opa_bundles_bucket
        NODE_OPTIONS = "--enable-source-maps"
      }
    }
}

resource "aws_lambda_function" "list-instances" {
  function_name = var.list-instances-name

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-list-instances-0.1.0.zip"

  handler = "js/list-instances.handler"
  runtime = "nodejs14.x"
  timeout = 20

  role = aws_iam_role.list-instances_lambda.arn

  vpc_config {
    security_group_ids = [aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.nat_subnet.*.id // todo: private with VPCe
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.list-instances,
  ]

  environment {
      variables = {
        REGION = var.region
        AWS_ACCOUNT = data.aws_caller_identity.current.account_id
        NODE_OPTIONS = "--enable-source-maps"
      }
    }
}

resource "aws_lambda_function" "get-instance" {
  function_name = var.get-instance-name

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-get-instance-0.1.0.zip"

  handler = "js/get-instance.handler"
  runtime = "nodejs14.x"
  timeout = 20

  role = aws_iam_role.get-instance_lambda.arn

  vpc_config {
    security_group_ids = [aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.nat_subnet.*.id // todo: private with VPCe
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.get-instance,
  ]

  environment {
      variables = {
        REGION = var.region
        AWS_ACCOUNT = data.aws_caller_identity.current.account_id
        NODE_OPTIONS = "--enable-source-maps"
      }
    }
}

resource "aws_lambda_function" "start-stop-instance" {
  function_name = local.start-stop-instance-name

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-start-stop-instance-0.1.0.zip"

  handler = "start-stop-instance/app.handler"
  runtime = "nodejs14.x"
  timeout = 20

  role = aws_iam_role.start-stop-instance_lambda.arn

  vpc_config {
    security_group_ids = [aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.nat_subnet.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.start-stop-instance,
  ]

  environment {
    variables = {
      REGION = var.region
      // AWS_ACCOUNT = data.aws_caller_identity.current.account_id
      NODE_OPTIONS = "--enable-source-maps"
    }
  }
}

resource "aws_lambda_alias" "create-account-alias" {
  name = "PROD"
  description = "PROD env alias"
  function_name = aws_lambda_function.create-account.arn
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [
      function_version
    ]
  }
}

resource "aws_lambda_alias" "post-token-alias" {
  name = "PROD"
  description = "PROD env alias"
  function_name = aws_lambda_function.post-token.arn
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [
      function_version
    ]
  }

  depends_on = [
    aws_lambda_function.post-token
  ]
}

resource "aws_lambda_alias" "list-bundles-alias" {
  name = "PROD"
  description = "PROD env alias"
  function_name = aws_lambda_function.list-bundles.arn
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [
      function_version
    ]
  }

  depends_on = [
    aws_lambda_function.list-bundles
  ]
}

resource "aws_lambda_alias" "list-policies-alias" {
  name = "PROD"
  description = "PROD env alias"
  function_name = aws_lambda_function.list-policies.arn
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [
      function_version
    ]
  }

  depends_on = [
    aws_lambda_function.list-policies
  ]
}

resource "aws_lambda_alias" "list-instances-alias" {
  name = "PROD"
  description = "PROD env alias"
  function_name = aws_lambda_function.list-instances.arn
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [
      function_version
    ]
  }

  depends_on = [
    aws_lambda_function.list-instances
  ]
}

resource "aws_lambda_alias" "start-stop-instance-alias" {
  name = "PROD"
  description = "PROD env alias"
  function_name = aws_lambda_function.start-stop-instance.arn
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [
      function_version
    ]
  }
}

resource "aws_lambda_alias" "get-instance-alias" {
  name = "PROD"
  description = "PROD env alias"
  function_name = aws_lambda_function.get-instance.arn
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [
      function_version
    ]
  }

  depends_on = [
    aws_lambda_function.get-instance
  ]
}

resource "aws_lambda_function" "status-queue-reader" {
  function_name = "status-queue-reader"

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-status-queue-reader-0.1.8.zip"

  handler = "src/status-queue-reader.handler"
  runtime = "nodejs14.x"
  timeout = 20

  role = aws_iam_role.status-queue-reader.arn

  vpc_config {
    security_group_ids = [aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.nat_subnet.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.status-queue-reader,
  ]

  environment {
    variables = {
      SQS_URL = aws_sqs_queue.opa_status_queue.id
      /*
      RDS_HOSTNAME = aws_db_instance.default.address,
      RDS_USERNAME = var.lambda_create_account_db_user,
      RDS_PASSWORD = var.lambda_create_account_db_pass,
      RDS_DATABASE = var.rds_db_name
      */
    }
  }

}

resource "aws_lambda_alias" "status-queue-reader-alias" {
  name = "PROD"
  description = "PROD env alias"
  function_name = aws_lambda_function.status-queue-reader.arn
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [
      function_version
    ]
  }
}

resource "aws_security_group" "lambda-sg" {
  name        = "lambda-sg"
  description = "allow inbound access on port 80 only"
  vpc_id = aws_vpc.aws-vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}


/*
resource "aws_cloudwatch_log_group" "get-root" {
  name              = "/aws/lambda/${var.get-root-name}"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "post-v1-data" {
  name              = "/aws/lambda/${var.post-v1-data-name}"
  retention_in_days = 3
}
*/

resource "aws_cloudwatch_log_group" "post-token" {
  name              = "/aws/lambda/${var.post-token-name}"
  retention_in_days = 3
}

/*
resource "aws_cloudwatch_log_group" "get-v1-policies" {
  name              = "/aws/lambda/${var.get-v1-policies-name}"
  retention_in_days = 3
}
*/

resource "aws_cloudwatch_log_group" "create-account" {
  name              = "/aws/lambda/${var.create-account-name}"
  retention_in_days = 3
}

/*
resource "aws_cloudwatch_log_group" "put-v1-policy" {
  name              = "/aws/lambda/${var.put-v1-policy}"
  retention_in_days = 3
}
*/

resource "aws_cloudwatch_log_group" "update-policy" {
  name              = "/aws/lambda/${var.update-policy-name}"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "status-queue-reader" {
  name              = "/aws/lambda/${var.status-queue-reader}"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "list-bundles" {
  name              = "/aws/lambda/${var.list-bundles-name}"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "list-policies" {
  name              = "/aws/lambda/${var.list-policies-name}"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "list-instances" {
  name              = "/aws/lambda/${var.list-instances-name}"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "start-stop-instance" {
  name              = "/aws/lambda/${local.start-stop-instance-name}"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "get-instance" {
  name              = "/aws/lambda/${var.get-instance-name}"
  retention_in_days = 3
}

# IAM role which dictates what other AWS services the Lambda function may access.
resource "aws_iam_role" "lambda_exec" {
  name = "opal_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "create_policy_lambda" {
  name = "create_policy_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "update_policy_lambda" {
  name = "update_policy_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "create_account_lambda" {
  name = "create_account_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "list-repo_lambda" {
  name = "list-repo"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "list-instances_lambda" {
  name = "list-instances"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "start-stop-instance_lambda" {
  name = "start-stop-instance"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "get-instance_lambda" {
  name = "get-instance"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "status-queue-reader" {
  name = "status-queue-reader"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "lambda_logging" {
  name = "lambda_logging"
  path = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

data "aws_iam_policy_document" "sqs_publish_policy" {
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:SendMessageBatch"
    ]
    resources = [
      aws_sqs_queue.policy_updates_queue.arn,
      aws_sqs_queue.bundle_sync_queue.arn
    ]
  }
}

resource "aws_iam_policy" "lambda_sqs_publish" {
  name = "lambda_sqs_publish"
  path = "/"
  description = "IAM policy for SQS publish from a lambda"
  policy = data.aws_iam_policy_document.sqs_publish_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_create_policy_logs" {
  role = aws_iam_role.create_policy_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_create_policy_sqs" {
  role = aws_iam_role.create_policy_lambda.name
  policy_arn = aws_iam_policy.lambda_sqs_publish.arn
}

data "aws_iam_policy_document" "ddb_create_account" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem"
    ]
    resources = [
      aws_dynamodb_table.account_table.arn
    ]
  }
}

data "aws_iam_policy_document" "sqs_receive_s3_write_policy" {
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      aws_sqs_queue.policy_updates_queue.arn
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]
    resources = [
      "arn:aws:s3:::${var.s3_opa_bundles_bucket}/*"
    ]
  }

  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.s3_opa_bundles_bucket}"
    ]
  }
}

data "aws_iam_policy_document" "list-repo_s3_read_policy" {
  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.s3_opa_bundles_bucket}"
    ]
  }
  statement {
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::${var.s3_opa_bundles_bucket}/*"
    ]
  }
}

data "aws_iam_policy_document" "list-instances_policy" {
  statement {
    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition"
    ]
    resources = [
      //"${aws_ecs_cluster.staging.arn}/*"
      "*" // TODO: only opa clusters
    ]
  }
}

data "aws_iam_policy_document" "start-stop-instance_policy" {
  statement {
    actions = [
      "ecs:UpdateService",
      "ecs:ListTasks",
      "ecs:StopTask"
    ]
    resources = [
      //"${aws_ecs_cluster.staging.arn}/*"
      "*" // TODO: only opa clusters
    ]
  }
}

data "aws_iam_policy_document" "get-instance_policy" {
  statement {
    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition"
    ]
    resources = [
      //"${aws_ecs_cluster.staging.arn}/*"
      "*" // TODO: only opa clusters
    ]
  }
}

resource "aws_iam_policy" "lambda_sqs_receive" {
  name = "lambda_sqs_receive"
  path = "/"
  description = "IAM policy to receive SQS from a lambda and write to S3"
  policy = data.aws_iam_policy_document.sqs_receive_s3_write_policy.json
}

resource "aws_iam_policy" "lambda_dynamodb_account" {
  name = "lambda_dynamodb_account"
  path = "/"
  description = "IAM policy to update account table in Dynamo"
  policy = data.aws_iam_policy_document.ddb_create_account.json
}

resource "aws_iam_policy" "lambda_list-repo_policy" {
  name = "lambda_list_repo"
  path = "/"
  description = "IAM policy to list repository entries from S3"
  policy = data.aws_iam_policy_document.list-repo_s3_read_policy.json
}

resource "aws_iam_policy" "lambda_list-instances_policy" {
  name = "lambda_list_instances"
  path = "/"
  description = "IAM policy to list ecs instances"
  policy = data.aws_iam_policy_document.list-instances_policy.json
}

resource "aws_iam_policy" "lambda_start-stop-instance_policy" {
  name = "lambda_start_stop_instance"
  path = "/"
  description = "IAM policy to start/stop ecs instances"
  policy = data.aws_iam_policy_document.start-stop-instance_policy.json
}

resource "aws_iam_policy" "lambda_get-instance_policy" {
  name = "lambda_get_instance"
  path = "/"
  description = "IAM policy to get single ecs instance details"
  policy = data.aws_iam_policy_document.get-instance_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_update_policy_sqs" {
  role = aws_iam_role.update_policy_lambda.name
  policy_arn = aws_iam_policy.lambda_sqs_receive.arn
}

resource "aws_iam_role_policy_attachment" "lambda_update_policy_logs" {
  role = aws_iam_role.update_policy_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_create_account_dynamo" {
  role = aws_iam_role.create_account_lambda.name
  policy_arn = aws_iam_policy.lambda_dynamodb_account.arn
}

resource "aws_iam_role_policy_attachment" "lambda_create_account_logs" {
  role = aws_iam_role.create_account_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_list-bundles_logs" {
  role = aws_iam_role.list-repo_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_list-bundles_s3" {
  role = aws_iam_role.list-repo_lambda.name
  policy_arn = aws_iam_policy.lambda_list-repo_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_list-instances" {
  role = aws_iam_role.list-instances_lambda.name
  policy_arn = aws_iam_policy.lambda_list-instances_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_start-stop-instance" {
  role = aws_iam_role.start-stop-instance_lambda.name
  policy_arn = aws_iam_policy.lambda_start-stop-instance_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_get-instance" {
  role = aws_iam_role.get-instance_lambda.name
  policy_arn = aws_iam_policy.lambda_get-instance_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_list-instances_logs" {
  role = aws_iam_role.list-instances_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_start-stop-instance_logs" {
  role = aws_iam_role.start-stop-instance_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_get-instance_logs" {
  role = aws_iam_role.get-instance_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

data "aws_iam_policy_document" "sqs_receive_status_policy" {
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      aws_sqs_queue.opa_status_queue.arn
    ]
  }
  statement {
    actions = [
      "dynamodb:BatchWriteItem"
    ]
    resources = [
      aws_dynamodb_table.bundle_status.arn
    ]
  }
}

resource "aws_iam_policy" "lambda_sqs_status_receive" {
  name = "lambda_sqs_status_receive"
  path = "/"
  description = "IAM policy to receive SQS from a OPA status"
  policy = data.aws_iam_policy_document.sqs_receive_status_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_status_queue_reader_sqs" {
  role = aws_iam_role.status-queue-reader.name
  policy_arn = aws_iam_policy.lambda_sqs_status_receive.arn
}

resource "aws_iam_role_policy_attachment" "lambda_status_reader_logs" {
  role = aws_iam_role.status-queue-reader.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

