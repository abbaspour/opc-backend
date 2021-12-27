# API Gateway, SQS, Lambda and S3 policies to maintain bundle.tar.gz
#
# GET     /repository/v1/bundles/{item}/contents             TODO List policy/data content in the bundle
# DELETE  /repository/v1/bundles/{item}/contents/{content}   Delete policy/data from the bundle
# POST    /repository/v1/bundles/{item}/contents/{content}   Update policy/data in the bundle

### Queue
resource "aws_sqs_queue" "bundle_sync_queue" {
  name = "bundle-sync-queue"
  message_retention_seconds = 3600
  receive_wait_time_seconds = 20
}

### IAM
data "aws_iam_policy_document" "bundle_content_sync_assume_role_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["apigateway.amazonaws.com"]
      type = "Service"
    }
  }
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "bundle_content_sync_role" {
  name = "bundle_content_sync_role"
  assume_role_policy = data.aws_iam_policy_document.bundle_content_sync_assume_role_policy_document.json
}


data "aws_iam_policy_document" "bundle_sync_sqs_publish_policy_document" {
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:SendMessageBatch"
    ]
    resources = [
      aws_sqs_queue.bundle_sync_queue.arn
    ]
    sid = "sqs"
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
    sid = "logs"
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

resource "aws_iam_policy" "bundle_content_sync_sqs_policy" {
  name = "bundle_content_sync_sqs_policy"
  path = "/"
  description = "IAM policy for SQS publish to bundle-sync Queue"
  policy = data.aws_iam_policy_document.bundle_sync_sqs_publish_policy_document.json
}

resource "aws_iam_role_policy_attachment" "bundle_content_sync_role_sqs_policy_attachment" {
  role = aws_iam_role.bundle_content_sync_role.name
  policy_arn = aws_iam_policy.bundle_content_sync_sqs_policy.arn
}

### Resources
# /repository/v1/bundles/{item}/contents
resource "aws_api_gateway_resource" "bundle_content_resource" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  parent_id   = aws_api_gateway_resource.bundles_folder_item.id
  path_part   = "contents"
}

# /repository/v1/bundles/{item}/contents/{content}
resource "aws_api_gateway_resource" "bundle_content_item_resource" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  parent_id   = aws_api_gateway_resource.bundle_content_resource.id
  path_part   = "{content+}"
}

### API

# DELETE /repository/v1/bundles/{item}/contents/{content+}
resource "aws_api_gateway_method" "bundle_content_delete_item_method" {
  rest_api_id          = aws_api_gateway_rest_api.repository_api.id
  resource_id          = aws_api_gateway_resource.bundle_content_item_resource.id
  api_key_required     = false
  http_method          = "DELETE"
  authorization        = "CUSTOM"
  authorizer_id        = aws_api_gateway_authorizer.jwt_authorizer.id

  request_parameters = {
    "method.request.path.item" = true
    "method.request.path.content" = true
  }
}

resource "aws_api_gateway_documentation_part" "bundle_content_delete_item_doc" {
  location {
    type   = "METHOD"
    method = aws_api_gateway_method.bundle_content_delete_item_method.http_method
    path   = aws_api_gateway_resource.bundle_content_item_resource.path
  }


  properties  = jsonencode({
    description = "Delete bundle content item"
    summary = "Delete content"
    operationId = "deleteBundleContent"
    tags = [
      "Bundle Content"
    ]
    "parameters" : [
      {
        name : "item"
        in : "path"
        required : "true"
        description: "bundle name"
      },
      {
        name : "content"
        in : "path"
        required : "true"
        description: "content name"
      },
      {
        type: "apiKey"
        name: "Authorization"
        in: "header"
      }
    ]
  })

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
}

resource "aws_api_gateway_integration" "bundle_content_delete_item_integration" {
  rest_api_id             = aws_api_gateway_rest_api.repository_api.id
  resource_id             = aws_api_gateway_resource.bundle_content_item_resource.id
  http_method             = aws_api_gateway_method.bundle_content_delete_item_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  credentials             = aws_iam_role.bundle_content_sync_role.arn
  uri = "arn:aws:apigateway:${var.region}:sqs:path/${aws_sqs_queue.bundle_sync_queue.name}"
  passthrough_behavior    = "NEVER"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody={\"method\":\"DELETE\", \"account_no\":$context.authorizer.account_no, \"bundle\":\"$method.request.path.item\", \"content\":\"$method.request.path.content\"}"
  }
}

resource "aws_api_gateway_integration_response" "bundle_sync_delete_item_integration_response" {
  rest_api_id       = aws_api_gateway_rest_api.repository_api.id
  resource_id       = aws_api_gateway_resource.bundle_content_item_resource.id
  http_method       = aws_api_gateway_method_response.bundle_sync_put_item_method_response.http_method
  status_code       = aws_api_gateway_method_response.bundle_sync_put_item_method_response.status_code
  //selection_pattern = "^2[0-9][0-9]"                                       // regex pattern for any 200 message that comes back from SQS

  response_templates = {
    "application/json" = "{\"message\": \"delete request received!\"}"
  }

  depends_on = [ aws_api_gateway_integration.bundle_content_delete_item_integration  ]
}

resource "aws_api_gateway_method_response" "bundle_sync_put_item_method_response" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundle_content_item_resource.id
  http_method = aws_api_gateway_integration.bundle_content_delete_item_integration.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}


# POST /repository/v1/bundles/{item}/contents/{content+}
resource "aws_api_gateway_method" "bundle_content_post_item_method" {
  rest_api_id          = aws_api_gateway_rest_api.repository_api.id
  resource_id          = aws_api_gateway_resource.bundle_content_item_resource.id
  api_key_required     = false
  http_method          = "POST"
  authorization        = "CUSTOM"
  authorizer_id        = aws_api_gateway_authorizer.jwt_authorizer.id

  request_parameters = {
    "method.request.path.item" = true
    "method.request.path.content" = true
  }

}

resource "aws_api_gateway_documentation_part" "bundle_content_post_item_doc" {
  location {
    type   = "METHOD"
    method = aws_api_gateway_method.bundle_content_post_item_method.http_method
    path   = aws_api_gateway_resource.bundle_content_item_resource.path
  }


  properties  = jsonencode({
    description = "Post bundle content item"
    operationId = "createBundleContent"
    summary = "Post bundle content"
    tags = [
      "Bundle Content"
    ]
    "parameters" : [
      {
        name : "item"
        in : "path"
        required : "true"
        description: "bundle name"
      },
      {
        name : "content"
        in : "path"
        required : "true"
        description: "content name"
      }
    ]
  })

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
}


resource "aws_api_gateway_integration" "bundle_content_post_item_integration" {
  rest_api_id             = aws_api_gateway_rest_api.repository_api.id
  resource_id             = aws_api_gateway_resource.bundle_content_item_resource.id
  http_method             = aws_api_gateway_method.bundle_content_post_item_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  credentials             = aws_iam_role.bundle_content_sync_role.arn
  uri = "arn:aws:apigateway:${var.region}:sqs:path/${aws_sqs_queue.bundle_sync_queue.name}"
  passthrough_behavior    = "NEVER"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody={\"method\":\"POST\", \"account_no\":$context.authorizer.account_no, \"bundle\":\"$method.request.path.item\", \"content\":\"$method.request.path.content\"}"
/*
    "application/json" = <<EOT
Action=SendMessage
&MessageAttribute.1.Name=method
&MessageAttribute.1.Value.StringValue=POST
&MessageAttribute.1.Value.DataType=String
&MessageAttribute.2.Name=account_no
&MessageAttribute.2.Value.StringValue=$context.authorizer.account_no
&MessageAttribute.2.Value.DataType=Number
&MessageAttribute.3.Name=bundle
&MessageAttribute.3.Value.StringValue=$method.request.path.item
&MessageAttribute.3.Value.DataType=String
&MessageAttribute.4.Name=content
&MessageAttribute.4.Value.StringValue=$method.request.path.content
&MessageAttribute.4.Value.DataType=String
EOT
*/
  }
}

resource "aws_api_gateway_integration_response" "bundle_sync_post_item_integration_response" {
  rest_api_id       = aws_api_gateway_rest_api.repository_api.id
  resource_id       = aws_api_gateway_resource.bundle_content_item_resource.id
  http_method       = aws_api_gateway_method_response.bundle_sync_post_item_method_response.http_method
  status_code       = aws_api_gateway_method_response.bundle_sync_post_item_method_response.status_code
  //selection_pattern = "^2[0-9][0-9]"                                       // regex pattern for any 200 message that comes back from SQS

  response_templates = {
    "application/json" = "{\"message\": \"post request received!\"}"
  }

  depends_on = [ aws_api_gateway_integration.bundle_content_post_item_integration  ]
}

resource "aws_api_gateway_method_response" "bundle_sync_post_item_method_response" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundle_content_item_resource.id
  http_method = aws_api_gateway_integration.bundle_content_post_item_integration.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

# GET /repository/v1/bundles/{item}/contents

resource "aws_api_gateway_method" "bundle_content_get_method" {
  rest_api_id          = aws_api_gateway_rest_api.repository_api.id
  resource_id          = aws_api_gateway_resource.bundle_content_resource.id
  api_key_required     = false
  http_method          = "GET"
  authorization        = "CUSTOM"
  authorizer_id        = aws_api_gateway_authorizer.jwt_authorizer.id

  request_parameters = {
    "method.request.path.item" = true
  }
}

resource "aws_api_gateway_documentation_part" "bundle_content_get_item_doc" {
  location {
    type   = "METHOD"
    method = aws_api_gateway_method.bundle_content_get_method.http_method
    path   = aws_api_gateway_resource.bundle_content_resource.path
  }

  properties  = jsonencode({
    description = "Get bundle content item list"
    summary = "List contents of an item"
    operationId = "getBundleContents"
    tags = [
      "Bundle Content"
    ]
    "parameters" : [
      {
        name : "item"
        in : "path"
        required : "true"
        description: "bundle name"
      },
      {
        type: "apiKey"
        name: "Authorization"
        in: "header"
      }
    ]
  })

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
}
resource "aws_api_gateway_integration" "bundle_content_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.repository_api.id
  resource_id             = aws_api_gateway_resource.bundle_content_resource.id
  http_method             = aws_api_gateway_method.bundle_content_get_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.bundle_content_lambda.invoke_arn
}

/*
resource "aws_api_gateway_integration_response" "bundle_content_integration_response" {
  depends_on = [
    aws_api_gateway_integration.bundle_content_get_integration]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundle_content_resource.id
  http_method = aws_api_gateway_method.bundle_content_get_method.http_method
  status_code = aws_api_gateway_method_response.bundle_content_get_method_response.status_code

  response_parameters = {
    "method.response.header.Timestamp" = "integration.response.header.Date"
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type" = "integration.response.header.Content-Type"
  }
}
*/

resource "aws_api_gateway_method_response" "bundle_content_get_method_response" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundle_content_resource.id
  http_method = aws_api_gateway_method.bundle_content_get_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Timestamp" = true
    "method.response.header.Content-Length" = true
    "method.response.header.Content-Type" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    //"application/json" = "Empty"
  }
}

### Lambda

locals {
  bundle-sync-name = "bundle-sync"
  bundle-content-name = "bundle-content"
}

## Mutate content (DELETE, POST)
resource "aws_iam_role" "bundle-sync_lambda" {
  name = "bundle-sync"

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

data "aws_iam_policy_document" "sqs_bundle_sync_receive_s3_write_policy" {
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      aws_sqs_queue.bundle_sync_queue.arn
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:PutObjectAcl",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:GetObjectAcl",
    ]
    resources = [
      "arn:aws:s3:::${var.s3_opa_bundles_bucket}/*"
    ]
  }

  statement {
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.s3_opa_bundles_bucket}"
    ]
    sid = "listing"
  }

}

resource "aws_iam_policy" "lambda_bundle-sync_sqs_receive" {
  name = "lambda_bundle-sync_sqs_receive"
  path = "/"
  description = "IAM policy to receive SQS from bundle-sync queue and write to S3"
  policy = data.aws_iam_policy_document.sqs_bundle_sync_receive_s3_write_policy.json
}


resource "aws_iam_role_policy_attachment" "lambda_bundle-sync_sqs" {
  role = aws_iam_role.bundle-sync_lambda.name
  policy_arn = aws_iam_policy.lambda_bundle-sync_sqs_receive.arn
}

resource "aws_iam_role_policy_attachment" "lambda_bundle-sync_logs" {
  role = aws_iam_role.bundle-sync_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_lambda_function" "bundle_sync_lambda" {
  function_name = local.bundle-sync-name

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-bundle-sync-0.1.0.zip"

  handler = "js/bundle-sync.handler"
  runtime = "nodejs14.x"
  timeout = 20

  role = aws_iam_role.bundle-sync_lambda.arn

  vpc_config {
    security_group_ids = [aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.nat_subnet.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.bundle-sync,
  ]

  environment {
    variables = {
      BUCKET = var.s3_opa_bundles_bucket
    }
  }
}

resource "aws_lambda_alias" "bundle-sync_alias" {
  name = "PROD"
  description = "PROD env alias"
  function_name = aws_lambda_function.bundle_sync_lambda.arn
  function_version = "$LATEST"

  depends_on = [
    aws_lambda_function.bundle_sync_lambda
  ]

  lifecycle {
    ignore_changes = [
      function_version
    ]
  }
}


resource "aws_lambda_event_source_mapping" "bundle-sync-event_source_mapping" {
  batch_size        = 10
  event_source_arn  = aws_sqs_queue.bundle_sync_queue.arn
  enabled           = true
  function_name     = aws_lambda_function.bundle_sync_lambda.arn
}


resource "aws_cloudwatch_log_group" "bundle-sync" {
  name              = "/aws/lambda/${local.bundle-sync-name}"
  retention_in_days = 3
}



## GET

resource "aws_lambda_function" "bundle_content_lambda" {
  function_name = local.bundle-content-name

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-bundle-sync-0.1.0.zip"

  handler = "js/bundle-sync.getHandler"
  runtime = "nodejs14.x"
  timeout = 20

  role = aws_iam_role.bundle_content_sync_role.arn

  vpc_config {
    security_group_ids = [aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.nat_subnet.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.bundle-sync,
  ]

  environment {
    variables = {
      BUCKET = var.s3_opa_bundles_bucket
    }
  }
}

resource "aws_lambda_alias" "bundle-content_alias" {
  name = "PROD"
  description = "PROD env alias"
  function_name = aws_lambda_function.bundle_content_lambda.arn
  function_version = "$LATEST"

  depends_on = [
    aws_lambda_function.bundle_content_lambda
  ]

  lifecycle {
    ignore_changes = [
      function_version
    ]
  }
}


resource "aws_cloudwatch_log_group" "bundle_content_log_group" {
  name              = "/aws/lambda/${local.bundle-content-name}"
  retention_in_days = 3
}

resource "aws_lambda_permission" "apigw_lambda_perm_bundles_content" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bundle_content_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.repository_api.id}/*/${aws_api_gateway_method.bundle_content_get_method.http_method}${aws_api_gateway_resource.bundle_content_resource.path}"
}
