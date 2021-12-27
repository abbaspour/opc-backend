resource "aws_sqs_queue" "policy_updates_queue" {
  name = "policy-updates-queue"
  message_retention_seconds = 3600
  receive_wait_time_seconds = 20
}

resource "aws_lambda_event_source_mapping" "update-policy-event_source_mapping" {
  batch_size        = 10
  event_source_arn  = aws_sqs_queue.policy_updates_queue.arn
  enabled           = true
  function_name     = aws_lambda_function.update-policy.arn
}

resource "aws_lambda_event_source_mapping" "status-queue-reader-event_source_mapping" {
  maximum_batching_window_in_seconds = 300
  batch_size        = 10
  event_source_arn  = aws_sqs_queue.opa_status_queue.arn
  enabled           = true
  function_name     = aws_lambda_function.status-queue-reader.arn

}

resource "aws_sqs_queue" "opa_status_queue" {
  name = "opa-status-queue"
  message_retention_seconds = 3600
  receive_wait_time_seconds = 20
}


data "aws_iam_policy_document" "sqs_status_publish_doc" {
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:SendMessageBatch"
    ]
    resources = [
      aws_sqs_queue.opa_status_queue.arn
    ]
  }

  statement {
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "logs:CreateLogStream"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:List*"
    ]
    resources = ["*"]
    sid = "3"
  }

}

resource "aws_iam_policy" "status_sqs_publish" {
  name = "status_queue_publish"
  path = "/"
  description = "IAM policy for SQS publish to Status Queue"
  policy = data.aws_iam_policy_document.sqs_status_publish_doc.json
}

resource "aws_iam_role" "status_queue_publish" {
  name = "status-publish-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "gateway_publish_status_sqs" {
  role = aws_iam_role.status_queue_publish.name
  policy_arn = aws_iam_policy.status_sqs_publish.arn
}
