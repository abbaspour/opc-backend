# https://shaneblandford.medium.com/amazon-api-gateway-integration-with-sqs-using-terraform-3c81040b0b70

/*
resource "aws_api_gateway_rest_api" "private_api" {
  name = "OPC-Private"
  description = "unprotected status and decision logs endpoint service for on-cloud OPA instances"

  endpoint_configuration {
//    types = ["REGIONAL"]
    types = ["PRIVATE"]
    vpc_endpoint_ids = [
      aws_vpc_endpoint.api-gateway.id
    ]
  }
}

resource "aws_api_gateway_resource" "status_resource" {
  rest_api_id = aws_api_gateway_rest_api.private_api.id
  parent_id   = aws_api_gateway_rest_api.private_api.root_resource_id
  path_part   = "status"
}

resource "aws_api_gateway_integration" "receive_status" {
  rest_api_id             = aws_api_gateway_rest_api.private_api.id
  resource_id             = aws_api_gateway_resource.status_resource.id
  http_method             = aws_api_gateway_method.api.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  credentials             = aws_iam_role.status_queue_publish.arn
  //uri                     = aws_sqs_queue.opa_status_queue.arn
  //uri                     = "arn:aws:apigateway:${var.region}:sqs:action/SendMessage"
  uri = "arn:aws:apigateway:${var.region}:sqs:path/${aws_sqs_queue.opa_status_queue.name}"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  // Action=SendMessage&MessageBody=$input.json('$')
  // MessageGroupId=1&
  // TODO: make FIFO
  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
  }
  passthrough_behavior    = "WHEN_NO_TEMPLATES"
}

resource "aws_api_gateway_method" "api" {
  rest_api_id          = aws_api_gateway_rest_api.private_api.id
  resource_id          = aws_api_gateway_resource.status_resource.id
  api_key_required     = false
  http_method          = "POST"
  authorization        = "NONE"
}

resource "aws_api_gateway_method_response" "r200" {
  rest_api_id = aws_api_gateway_rest_api.private_api.id
  resource_id = aws_api_gateway_resource.status_resource.id
  http_method = aws_api_gateway_integration.receive_status.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "r200" {
  rest_api_id       = aws_api_gateway_rest_api.private_api.id
  resource_id       = aws_api_gateway_resource.status_resource.id
  http_method       = aws_api_gateway_method_response.r200.http_method
  status_code       = aws_api_gateway_method_response.r200.status_code
  //selection_pattern = "^2[0-9][0-9]"                                       // regex pattern for any 200 message that comes back from SQS

  response_templates = {
    "application/json" = "{\"message\": \"great success!\"}"
  }

  depends_on = [ aws_api_gateway_integration.receive_status  ]
}

resource "aws_cloudwatch_log_group" "private-api-logs" {
  name              = "API-Gateway-Execution-Logs_OPC-Private"
  retention_in_days = 3
}

data "aws_iam_policy_document" "private_api_policy_doc" {
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
}

resource "aws_iam_policy" "private_api_policy" {
  name = "private_api_logging_policy"
  path = "/"
  description = "IAM policy for private api"
  policy = data.aws_iam_policy_document.private_api_policy_doc.json
}

resource "aws_iam_policy_attachment" "api_gateway_logs" {
  name = "api_gateway_logs_policy_attach"
  roles = [
    aws_iam_role.cloudwatch.id]
  //policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
  policy_arn = aws_iam_policy.private_api_policy.arn
}

resource "aws_api_gateway_method_settings" "name" {
  rest_api_id = aws_api_gateway_rest_api.private_api.id
  stage_name  = "dev"
  method_path = "${aws_api_gateway_resource.status_resource.path_part}/${aws_api_gateway_method.api.http_method}"

  settings {
    metrics_enabled = true
    logging_level = "INFO"
    data_trace_enabled = true
  }
}

resource "aws_iam_role" "cloudwatch" {
  name = "APIGatewayCloudWatchLogs"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Sid": "",
     "Effect": "Allow",
     "Principal": {
     "Service": "apigateway.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }
 ]
}
  EOF
}

data "aws_iam_policy_document" "private-api-policy" {
  statement {
    actions = ["execute-api:Invoke"]
    effect = "Allow"
    principals {
      identifiers = ["*"]
      type = "*"
    }
    //resources = ["arn:aws:execute-api:ap-southeast-2:377258293252:9ms2c3v81c/* /POST/status"]
    resources = ["*"]
    sid = "2"
  }
}

resource "aws_api_gateway_rest_api_policy" "from-opc-vpc" {
  rest_api_id = aws_api_gateway_rest_api.private_api.id
  policy = data.aws_iam_policy_document.private-api-policy.json
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id     = aws_api_gateway_rest_api.private_api.id
  stage_name      = "dev"
}

/*
output "private_api_url" {
  value = aws_api_gateway_deployment.deployment.invoke_url
}
*/

