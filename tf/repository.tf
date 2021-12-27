## provides authenticated bundle & status services to on-prem (i.e. remote) OPA instances
# docs:
# https://www.openpolicyagent.org/docs/latest/configuration/#oauth2-client-credentials
# https://www.openpolicyagent.org/docs/latest/configuration/#bundles
# https://medium.com/lego-engineering/functionless-s3-integration-inside-a-serverless-casserole-part-1-b300085eea78
# https://docs.aws.amazon.com/apigateway/latest/developerguide/integrating-api-with-aws-services-s3.html
# https://github.com/hashicorp/terraform-provider-aws/blob/main/examples/s3-api-gateway-integration/main.tf
# https://medium.com/onfido-tech/aws-api-gateway-with-terraform-7a2bebe8b68f
# https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-lambda-authorizer-output.html
# https://www.alexdebrie.com/posts/api-gateway-elements/

resource "aws_api_gateway_account" "gateway_account" {
  cloudwatch_role_arn = aws_iam_role.bundle_srv_cloudwatch.arn
}

resource "aws_api_gateway_rest_api" "repository_api" {
  name = "Repository API"
  description = "https://api.openpolicy.cloud/repository"

  binary_media_types = [
    "application/gzip",
    "application/x-gzip",
    "application/zip",
    "binary/octet-stream"
    //"*/*"
  ]
  endpoint_configuration {
    types = [
      "REGIONAL"]
  }
}

## Logging
resource "aws_cloudwatch_log_group" "repository_srv_log_group" {
  name = "/api/bundle-service"
  retention_in_days = 3
}

data "aws_iam_policy_document" "bundle_srv_log" {
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

resource "aws_iam_policy" "bundle_srv_policy" {
  name = "bundle_srv_policy"
  path = "/"
  description = "IAM policy for bundle srv"
  policy = data.aws_iam_policy_document.bundle_srv_log.json
}

resource "aws_iam_policy_attachment" "attach_bundle_srv_gateway_logs" {
  name = "api_gateway_bundle_srv_logs_policy_attach"
  roles = [
    aws_iam_role.bundle_srv_cloudwatch.id]
  policy_arn = aws_iam_policy.bundle_srv_policy.arn
}

resource "aws_api_gateway_method_settings" "bundle_srv_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  stage_name = aws_api_gateway_stage.repository_srv_stg.stage_name
  method_path = "${aws_api_gateway_resource.bundles.path_part}/${aws_api_gateway_method.GetBundlesMethod.http_method}"

  settings {
    metrics_enabled = true
    logging_level = "INFO"
    data_trace_enabled = true
  }
}

## S3 Access
data "aws_iam_policy_document" "api_gw_s3_access_policy_doc" {
  statement {
    actions = [
      "s3:ListBucket"]
    resources = [
      aws_s3_bucket.s3_data_bucket.arn]
  }
  statement {
    actions = [
      "s3:*Object"]
    resources = [
      "${aws_s3_bucket.s3_data_bucket.arn}/*"]
  }
}

# Create S3 Full Access Policy
resource "aws_iam_policy" "s3_policy" {
  name = "api-gw-access-s3-bundles"
  description = "Policy for allowing all S3 Actions"
  path = "/"
  policy = data.aws_iam_policy_document.api_gw_s3_access_policy_doc.json
}

# Create API Gateway Role
resource "aws_iam_role" "s3_api_gateway_role" {
  name = "s3-api-gateyway-role"

  # Create Trust Policy for API Gateway
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

# Attach S3 Access Policy to the API Gateway Role
resource "aws_iam_role_policy_attachment" "s3_policy_attach" {
  role = aws_iam_role.s3_api_gateway_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_iam_role" "bundle_srv_cloudwatch" {
  name = "APIGatewayCloudWatchLogsForBundleService"
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

resource "aws_iam_role_policy" "cloudwatch" {
  name = "cloudwatch_role_bundle"
  role = aws_iam_role.bundle_srv_cloudwatch.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "sqs:SendMessage",
                "sqs:SendMessageBatch"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

## S3 proxy - /v1
resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  parent_id = aws_api_gateway_rest_api.repository_api.root_resource_id
  path_part = "v1"
}

## S3 proxy - /v1/bundles
resource "aws_api_gateway_resource" "bundles" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  parent_id = aws_api_gateway_resource.v1.id
  path_part = "bundles"
}

## Integration for GET /v1/bundles
resource "aws_api_gateway_method" "GetBundlesMethod" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles.id
  http_method = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt_authorizer.id

  request_parameters = {
    // "method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_documentation_part" "get_bundles_doc" {
  location {
    type = "METHOD"
    method = aws_api_gateway_method.GetBundlesMethod.http_method
    path = aws_api_gateway_resource.bundles.path
  }

  properties = jsonencode({
    description = "Lists all available bundles."
    summary = "List Bundles"
    operationId = "listBundles"
    tags = [
      "Bundles"]
  })

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
}

resource "aws_api_gateway_integration" "IntegrationListBundles" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles.id
  http_method = aws_api_gateway_method.GetBundlesMethod.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"

  uri = aws_lambda_function.list-bundles.invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda_perm_list_bundles" {
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list-bundles.function_name
  principal = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.repository_api.id}/*/${aws_api_gateway_method.GetBundlesMethod.http_method}${aws_api_gateway_resource.bundles.path}"
}

/*
resource "aws_api_gateway_integration" "IntegrationListBundles" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles.id
  http_method = aws_api_gateway_method.GetBundlesMethod.http_method
  integration_http_method = "GET"
  type = "AWS"

  uri = "arn:aws:apigateway:${var.region}:s3:path/${var.s3_opa_bundles_bucket}/"
  credentials = aws_iam_role.s3_api_gateway_role.arn

  request_parameters = {
    "integration.request.querystring.delimiter" = "'/'"
    "integration.request.querystring.prefix" = "context.authorizer.prefix"
  }
}
*/

data "local_file" "schema_list_bundles_response" {
  filename = "schema/repository-bundle-list-response-schema.json"
}

resource "aws_api_gateway_model" "ListBundlesResponseModel" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  name = "BundlesList"
  description = "list bundles response model"
  schema = data.local_file.schema_list_bundles_response.content
  content_type = "application/json"
}

resource "aws_api_gateway_method_response" "ListBundlesStatus200" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles.id
  http_method = aws_api_gateway_method.GetBundlesMethod.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Timestamp" = true
    "method.response.header.Content-Length" = true
    "method.response.header.Content-Type" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = aws_api_gateway_model.ListBundlesResponseModel.name
  }
}

resource "aws_api_gateway_method_response" "ListBundlesStatus400" {
  depends_on = [
    aws_api_gateway_integration.IntegrationListBundles]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles.id
  http_method = aws_api_gateway_method.GetBundlesMethod.http_method
  status_code = "400"
}

resource "aws_api_gateway_method_response" "ListBundlesStatus500" {
  depends_on = [
    aws_api_gateway_integration.IntegrationListBundles]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles.id
  http_method = aws_api_gateway_method.GetBundlesMethod.http_method
  status_code = "500"
}

resource "aws_api_gateway_integration_response" "ListBundlesIntegrationResponse200" {
  depends_on = [
    aws_api_gateway_integration.IntegrationListBundles]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles.id
  http_method = aws_api_gateway_method.GetBundlesMethod.http_method
  status_code = aws_api_gateway_method_response.ListBundlesStatus200.status_code

  response_parameters = {
    "method.response.header.Timestamp" = "integration.response.header.Date"
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type" = "integration.response.header.Content-Type"
  }
}

resource "aws_api_gateway_integration_response" "ListBundlesIntegrationResponse400" {
  depends_on = [
    aws_api_gateway_integration.IntegrationListBundles]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles.id
  http_method = aws_api_gateway_method.GetBundlesMethod.http_method
  status_code = aws_api_gateway_method_response.ListBundlesStatus400.status_code

  selection_pattern = "4\\d{2}"
}

resource "aws_api_gateway_integration_response" "ListBundlesIntegrationResponse500" {
  depends_on = [
    aws_api_gateway_integration.IntegrationListBundles]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles.id
  http_method = aws_api_gateway_method.GetBundlesMethod.http_method
  status_code = aws_api_gateway_method_response.ListBundlesStatus500.status_code

  selection_pattern = "5\\d{2}"
}

## S3 proxy - /v1/policies
resource "aws_api_gateway_resource" "policies" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  parent_id = aws_api_gateway_resource.v1.id
  path_part = "policies"
}

## Integration for GET /v1/policies
resource "aws_api_gateway_method" "list_policies_method" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policies.id
  http_method = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt_authorizer.id

  request_parameters = {
    // "method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_documentation_part" "list_policies_doc" {
  location {
    type = "METHOD"
    method = aws_api_gateway_method.list_policies_method.http_method
    path = aws_api_gateway_resource.policies.path
  }

  properties = jsonencode({
    description = "Lists all available policies."
    summary = "List Policies"
    operationId = "listPolicies"
    tags = [
      "Policies"]
  })

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
}

resource "aws_api_gateway_integration" "list_policies_integration" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policies.id
  http_method = aws_api_gateway_method.list_policies_method.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"

  uri = aws_lambda_function.list-policies.invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda_perm_list_policies" {
  statement_id = "AllowExecutionFromAPIGateway_list_policies"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list-policies.function_name
  principal = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.repository_api.id}/*/${aws_api_gateway_method.list_policies_method.http_method}${aws_api_gateway_resource.policies.path}"
}


/*
resource "aws_api_gateway_integration" "list_policies_integration" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policies.id
  http_method = aws_api_gateway_method.list_policies_method.http_method
  integration_http_method = "GET"
  type = "AWS"

  uri = "arn:aws:apigateway:${var.region}:s3:path/${var.s3_opa_bundles_bucket}/"
  credentials = aws_iam_role.s3_api_gateway_role.arn

  request_parameters = {
    "integration.request.querystring.delimiter" = "'/'"
    "integration.request.querystring.prefix" = "context.authorizer.prefix"
  }
}
*/

resource "aws_api_gateway_method_response" "list_policies_status_200" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policies.id
  http_method = aws_api_gateway_method.list_policies_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Timestamp" = true
    "method.response.header.Content-Length" = true
    "method.response.header.Content-Type" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "list_policies_status_400" {
  depends_on = [
    aws_api_gateway_integration.list_policies_integration]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policies.id
  http_method = aws_api_gateway_method.list_policies_method.http_method
  status_code = "400"
}

resource "aws_api_gateway_method_response" "list_policies_status_500" {
  depends_on = [
    aws_api_gateway_integration.list_policies_integration]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policies.id
  http_method = aws_api_gateway_method.list_policies_method.http_method
  status_code = "500"
}

resource "aws_api_gateway_integration_response" "list_policies_integration_response" {
  depends_on = [
    aws_api_gateway_integration.list_policies_integration]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policies.id
  http_method = aws_api_gateway_method.list_policies_method.http_method
  status_code = aws_api_gateway_method_response.list_policies_status_200.status_code

  response_parameters = {
    "method.response.header.Timestamp" = "integration.response.header.Date"
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type" = "integration.response.header.Content-Type"
  }
}

resource "aws_api_gateway_integration_response" "list_policies_integration_response_400" {
  depends_on = [
    aws_api_gateway_integration.list_policies_integration]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policies.id
  http_method = aws_api_gateway_method.list_policies_method.http_method
  status_code = aws_api_gateway_method_response.list_policies_status_400.status_code

  selection_pattern = "4\\d{2}"
}

resource "aws_api_gateway_integration_response" "list_policies_integration_response_500" {
  depends_on = [
    aws_api_gateway_integration.list_policies_integration]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policies.id
  http_method = aws_api_gateway_method.list_policies_method.http_method
  status_code = aws_api_gateway_method_response.list_policies_status_500.status_code

  selection_pattern = "5\\d{2}"
}

## Integration for GET/PUT/DELETE /v1/bundles/${item}
resource "aws_api_gateway_resource" "bundles_folder_item" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  parent_id = aws_api_gateway_resource.bundles.id
  path_part = "{item}"
}

resource "aws_api_gateway_method" "GetBundleFile" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles_folder_item.id
  http_method = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt_authorizer.id
  request_parameters = {
    "method.request.path.item" = true
    /*
    "method.request.header.Authorization" = true
    "method.request.header.Accept" = true
    "method.request.header.Content-Type" = true
    */
  }
}

resource "aws_api_gateway_documentation_part" "get_bundle_item_doc" {
  location {
    type = "METHOD"
    method = aws_api_gateway_method.GetBundleFile.http_method
    path = aws_api_gateway_resource.bundles_folder_item.path
  }

  properties = jsonencode({
    description = "Get bundle item."
    summary = "Get Bundle"
    operationId = "getBundle"
    tags = [
      "Bundles"]
  })

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
}

resource "aws_api_gateway_integration" "S3IntegrationBundleItem" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles_folder_item.id
  http_method = aws_api_gateway_method.GetBundleFile.http_method
  integration_http_method = "GET"

  type = "AWS"

  # See uri description: https://docs.aws.amazon.com/apigateway/api-reference/resource/integration/
  uri = "arn:aws:apigateway:${var.region}:s3:path/${var.s3_opa_bundles_bucket}/{account_no}/bundles/{object}"
  credentials = aws_iam_role.s3_api_gateway_role.arn

  request_parameters = {
    "integration.request.path.account_no" = "context.authorizer.account_no"
    "integration.request.path.object" = "method.request.path.item"
    //"integration.request.header.Accept" = "method.request.header.Accept"
    //"integration.request.header.Content-Type" = "method.request.header.Content-Type"
  }

  passthrough_behavior = "WHEN_NO_TEMPLATES"
}

resource "aws_api_gateway_method_response" "BundleItemStatus200" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles_folder_item.id
  http_method = aws_api_gateway_method.GetBundleFile.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Timestamp" = true
    "method.response.header.Content-Length" = true
    "method.response.header.Content-Type" = true
    "method.response.header.Content-Encoding" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    // "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "BundleItemIntegrationResponse200" {
  depends_on = [
    aws_api_gateway_integration.S3IntegrationBundleItem]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles_folder_item.id
  http_method = aws_api_gateway_method.GetBundleFile.http_method
  status_code = aws_api_gateway_method_response.BundleItemStatus200.status_code

  //content_handling = "CONVERT_TO_BINARY"

  response_parameters = {
    "method.response.header.Timestamp" = "integration.response.header.Date"
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type" = "integration.response.header.Content-Type"
    "method.response.header.Content-Encoding" = "integration.response.header.Content-Encoding"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

## Integration for GET /v1/policies/${item}
resource "aws_api_gateway_resource" "policy_item" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  parent_id = aws_api_gateway_resource.policies.id
  path_part = "{item+}"
}

resource "aws_api_gateway_method" "get_policy_method" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policy_item.id
  http_method = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt_authorizer.id
  request_parameters = {
    "method.request.path.item" = true
    // "method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_documentation_part" "get_policy_item_doc" {
  location {
    type = "METHOD"
    method = aws_api_gateway_method.get_policy_method.http_method
    path = aws_api_gateway_resource.policy_item.path
  }

  properties = jsonencode({
    description = "Get policy item."
    summary = "Get Policy"
    operationId = "getPolicy"
    tags = [
      "Policies"]
  })

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
}

resource "aws_api_gateway_integration" "get_policy_integration" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policy_item.id
  http_method = aws_api_gateway_method.get_policy_method.http_method
  integration_http_method = "GET"
  type = "AWS"

  uri = "arn:aws:apigateway:${var.region}:s3:path/${var.s3_opa_bundles_bucket}/{account_no}/policies/{object}"
  credentials = aws_iam_role.s3_api_gateway_role.arn

  request_parameters = {
    "integration.request.path.account_no" = "context.authorizer.account_no"
    "integration.request.path.object" = "method.request.path.item"
  }
}

resource "aws_api_gateway_method_response" "get_policy_status_200" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policy_item.id
  http_method = aws_api_gateway_method.get_policy_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Timestamp" = true
    "method.response.header.Content-Length" = true
    "method.response.header.Content-Type" = true
    "method.response.header.Content-Encoding" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "get_policy_integration_response_200" {
  depends_on = [
    aws_api_gateway_integration.get_policy_integration]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policy_item.id
  http_method = aws_api_gateway_method.get_policy_method.http_method
  status_code = aws_api_gateway_method_response.get_policy_status_200.status_code

  response_parameters = {
    "method.response.header.Timestamp" = "integration.response.header.Date"
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type" = "integration.response.header.Content-Type"
    "method.response.header.Content-Encoding" = "integration.response.header.Content-Encoding"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

## Integration for PUT /v1/bundles/{item}
resource "aws_api_gateway_method" "PutBundleFile" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles_folder_item.id
  http_method = "PUT"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt_authorizer.id
  request_parameters = {
    "method.request.path.item" = true
    /*
    "method.request.header.Content-Type" = true
    "method.request.header.Authorization" = true
    */
  }
}

resource "aws_api_gateway_documentation_part" "put_bundle_item_doc" {
  location {
    type = "METHOD"
    method = aws_api_gateway_method.PutBundleFile.http_method
    path = aws_api_gateway_resource.bundles_folder_item.path
  }

  properties = jsonencode({
    description = "Put bundle item."
    summary = "Add bundle"
    operationId = "createBundle"
    tags = [
      "Bundles"]
  })

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
}

resource "aws_api_gateway_integration" "S3IntegrationPutFile" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles_folder_item.id
  http_method = aws_api_gateway_method.PutBundleFile.http_method
  integration_http_method = "PUT"

  type = "AWS"

  uri = "arn:aws:apigateway:${var.region}:s3:path/${var.s3_opa_bundles_bucket}/{account_no}/bundles/{object}"
  credentials = aws_iam_role.s3_api_gateway_role.arn

  request_parameters = {
    "integration.request.path.account_no" = "context.authorizer.account_no"
    "integration.request.path.object" = "method.request.path.item"
    // "integration.request.header.Content-Type" = "method.request.header.Content-Type"
  }
}

resource "aws_api_gateway_method_response" "PutBundleFileResponseStatus200" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles_folder_item.id
  http_method = aws_api_gateway_method.PutBundleFile.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Timestamp" = true
    "method.response.header.Content-Length" = true
    "method.response.header.Content-Type" = true
    "method.response.header.Content-Encoding" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "PutBundleFileIntegrationResponse200" {
  depends_on = [
    aws_api_gateway_integration.S3IntegrationBundleItem]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles_folder_item.id
  http_method = aws_api_gateway_method.PutBundleFile.http_method
  status_code = aws_api_gateway_method_response.PutBundleFileResponseStatus200.status_code

  response_parameters = {
    "method.response.header.Timestamp" = "integration.response.header.Date"
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type" = "integration.response.header.Content-Type"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

## Integration for PUT /v1/policies/{item}
resource "aws_api_gateway_method" "put_policy" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policy_item.id
  http_method = "PUT"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt_authorizer.id
  request_parameters = {
    "method.request.path.item" = true
    /*
    "method.request.header.Content-Type" = true
    "method.request.header.Authorization" = true
    */
  }
}

resource "aws_api_gateway_documentation_part" "put_policy_item_doc" {
  location {
    type = "METHOD"
    method = aws_api_gateway_method.put_policy.http_method
    path = aws_api_gateway_resource.policy_item.path
  }

  properties = jsonencode({
    description = "Put policy item."
    summary = "Add policy"
    operationId = "createPolicy"
    tags = [
      "Policies"]
  })

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
}

resource "aws_api_gateway_integration" "put_policy_integration" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policy_item.id
  http_method = aws_api_gateway_method.put_policy.http_method
  integration_http_method = "PUT"

  type = "AWS"

  uri = "arn:aws:apigateway:${var.region}:s3:path/${var.s3_opa_bundles_bucket}/{account_no}/policies/{object}"
  credentials = aws_iam_role.s3_api_gateway_role.arn

  request_parameters = {
    "integration.request.path.account_no" = "context.authorizer.account_no"
    "integration.request.path.object" = "method.request.path.item"
    //"integration.request.header.Content-Type" = "method.request.header.Content-Type"
    "integration.request.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_method_response" "put_policy_response_200" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policy_item.id
  http_method = aws_api_gateway_method.put_policy.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Timestamp" = true
    "method.response.header.Content-Length" = true
    "method.response.header.Content-Type" = true
    "method.response.header.Content-Encoding" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "put_policy_integration_response_200" {
  depends_on = [
    aws_api_gateway_integration.put_policy_integration]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policy_item.id
  http_method = aws_api_gateway_method.put_policy.http_method
  status_code = aws_api_gateway_method_response.put_policy_response_200.status_code

  response_parameters = {
    "method.response.header.Timestamp" = "integration.response.header.Date"
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type" = "integration.response.header.Content-Type"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

## Integration for DELETE /v1/bundles/{item}
resource "aws_api_gateway_method" "delete_bundle_item" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles_folder_item.id
  http_method = "DELETE"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt_authorizer.id
  request_parameters = {
    "method.request.path.item" = true
    /*
    "method.request.header.Content-Type" = true
    "method.request.header.Authorization" = true
    */
  }
}

resource "aws_api_gateway_documentation_part" "delete_bundle_item_doc" {
  location {
    type = "METHOD"
    method = aws_api_gateway_method.delete_bundle_item.http_method
    path = aws_api_gateway_resource.bundles_folder_item.path
  }

  properties = jsonencode({
    description = "Delete bundle item."
    summary = "Delete bundle item"
    operationId = "deleteBundle"
    tags = [
      "Bundles"]
  })

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
}

resource "aws_api_gateway_integration" "delete_bundle_item_integration" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles_folder_item.id
  http_method = aws_api_gateway_method.delete_bundle_item.http_method
  integration_http_method = "DELETE"

  type = "AWS"

  uri = "arn:aws:apigateway:${var.region}:s3:path/${var.s3_opa_bundles_bucket}/{account_no}/bundles/{object}"
  credentials = aws_iam_role.s3_api_gateway_role.arn

  request_parameters = {
    "integration.request.path.account_no" = "context.authorizer.account_no"
    "integration.request.path.object" = "method.request.path.item"
    //"integration.request.header.Content-Type" = "method.request.header.Content-Type"
  }
}

resource "aws_api_gateway_method_response" "delete_bundle_item_response_200" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles_folder_item.id
  http_method = aws_api_gateway_method.delete_bundle_item.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Timestamp" = true
    "method.response.header.Content-Length" = true
    // "method.response.header.Content-Type" = true
    "method.response.header.Content-Encoding" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "delete_bundle_item_integration_response_200" {
  depends_on = [
    aws_api_gateway_integration.delete_bundle_item_integration]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.bundles_folder_item.id
  http_method = aws_api_gateway_method.delete_bundle_item.http_method
  status_code = aws_api_gateway_method_response.delete_bundle_item_response_200.status_code

  response_parameters = {
    "method.response.header.Timestamp" = "integration.response.header.Date"
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type" = "integration.response.header.Content-Type"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

## Integration for DELETE /v1/policies/{item}
resource "aws_api_gateway_method" "delete_policy_item" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policy_item.id
  http_method = "DELETE"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt_authorizer.id
  request_parameters = {
    "method.request.path.item" = true
    /*
    "method.request.header.Content-Type" = true
    "method.request.header.Authorization" = true
    */
  }
}

resource "aws_api_gateway_documentation_part" "delete_policy_item_doc" {
  location {
    type = "METHOD"
    method = aws_api_gateway_method.delete_policy_item.http_method
    path = aws_api_gateway_resource.policy_item.path
  }

  properties = jsonencode({
    description = "Delete policy."
    summary = "Delete policy"
    operationId = "deletePolicy"
    tags = [
      "Policies"]
  })

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
}

resource "aws_api_gateway_integration" "delete_policy_item_integration" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policy_item.id
  http_method = aws_api_gateway_method.delete_policy_item.http_method
  integration_http_method = "DELETE"

  type = "AWS"

  uri = "arn:aws:apigateway:${var.region}:s3:path/${var.s3_opa_bundles_bucket}/{account_no}/policies/{object}"
  credentials = aws_iam_role.s3_api_gateway_role.arn

  request_parameters = {
    "integration.request.path.account_no" = "context.authorizer.account_no"
    "integration.request.path.object" = "method.request.path.item"
    //"integration.request.header.Content-Type" = "method.request.header.Content-Type"
  }
}

resource "aws_api_gateway_method_response" "delete_policy_item_response_200" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policy_item.id
  http_method = aws_api_gateway_method.delete_policy_item.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Timestamp" = true
    "method.response.header.Content-Length" = true
    "method.response.header.Content-Type" = true
    "method.response.header.Content-Encoding" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "delete_policy_item_integration_response_200" {
  depends_on = [
    aws_api_gateway_integration.delete_policy_item_integration]

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.policy_item.id
  http_method = aws_api_gateway_method.delete_policy_item.http_method
  status_code = aws_api_gateway_method_response.delete_policy_item_response_200.status_code

  response_parameters = {
    "method.response.header.Timestamp" = "integration.response.header.Date"
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type" = "integration.response.header.Content-Type"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}


## Deployment
resource "aws_api_gateway_deployment" "repository_srv_deployment" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  // stage_description = timestamp() // trick to redeploy

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.repository_api.body))
    //redeployment = aws_lambda_alias.jwt_authorizer_alias.function_version
  }

  depends_on = [
    aws_api_gateway_integration.IntegrationListBundles,
    aws_api_gateway_integration.S3IntegrationBundleItem,
    aws_api_gateway_authorizer.jwt_authorizer
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      // stage_description
    ]
  }
}

resource "aws_api_gateway_stage" "repository_srv_stg" {
  stage_name = "stg"
  // This a hack to fix the API being auto deployed.
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  deployment_id = aws_api_gateway_deployment.repository_srv_deployment.id

  //documentation_version = aws_api_gateway_documentation_version.repository_api_doc_version.version

  lifecycle {
    ignore_changes = [
      documentation_version
    ]
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.repository_srv_log_group.arn
    format = jsonencode(
    {
      httpMethod = "$context.httpMethod"
      ip = "$context.identity.sourceIp"
      protocol = "$context.protocol"
      requestId = "$context.requestId"
      requestTime = "$context.requestTime"
      responseLength = "$context.responseLength"
      routeKey = "$context.routeKey"
      status = "$context.status"
      errorMessage = "$context.error.message"
      authorizerError = "$context.authorizer.error"
      integrationError = "$context.integration.error"
      // TODO: add latency and other useful metrics
      //  https://www.alexdebrie.com/posts/api-gateway-access-logs/
      //  https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-logging-variables.html
    }
    )
  }

  depends_on = [
    aws_cloudwatch_log_group.repository_srv_log_group
  ]
}

/*
output "bundle_api_url" {
  value = aws_api_gateway_deployment.repository_srv_deployment.invoke_url
}
*/

## Lambda
locals {
  jwt-authorizer-name = "jwt-authorizer"
  //jwks_uri = "https://${var.auth0_domain}/.well-known/jwks.json"
  issuer = "https://${var.auth0_domain}/"
  abs_path = abspath(path.root)
  public_key_file = "${var.auth0_domain}-${var.auth0_jwks_kid}-public_key.pem"
}

resource "aws_cloudwatch_log_group" "jwt_authorizer_log_group" {
  name = "/aws/lambda/${local.jwt-authorizer-name}"
  retention_in_days = 3
}

resource "aws_iam_role" "jwt_authorizer_lambda" {
  name = "jwt-authorizer-lambda"

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

resource "aws_iam_role_policy_attachment" "jwt_authorizer_lambda_logs" {
  role = aws_iam_role.jwt_authorizer_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "null_resource" "download_public_key" {
  provisioner "local-exec" {
    command = "if [ ! -f \"${local.public_key_file}\" ]; then ./jwks-to-pem.sh -d ${var.auth0_domain} -k ${var.auth0_jwks_kid}; fi"
  }
}

resource "aws_lambda_function" "jwt-authorizer" {
  function_name = local.jwt-authorizer-name

  s3_bucket = var.lambda_bucket
  s3_key = "lambda-${local.jwt-authorizer-name}-0.1.0.zip"

  handler = "js/handler.authorize"
  runtime = "nodejs14.x"

  role = aws_iam_role.jwt_authorizer_lambda.arn
  timeout = 20

  vpc_config {
    security_group_ids = [
      aws_security_group.lambda-sg.id]
    subnet_ids = aws_subnet.private_subnet.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.jwt_authorizer_lambda_logs,
    aws_cloudwatch_log_group.jwt_authorizer_log_group,
    null_resource.download_public_key
  ]

  environment {
    variables = {
      AUDIENCE = var.api_audience
      TOKEN_ISSUER = local.issuer
      //JWKS_URI = local.jwks_uri
      PUBLIC_KEY = file( "${local.abs_path}/${local.public_key_file}")
      NODE_OPTIONS = "--enable-source-maps"
    }
  }
}

resource "aws_lambda_alias" "jwt_authorizer_alias" {
  name = "PROD"
  description = "PROD env alias"
  function_name = aws_lambda_function.jwt-authorizer.arn
  function_version = "$LATEST"

  depends_on = [
    aws_lambda_function.jwt-authorizer
  ]

  lifecycle {
    ignore_changes = [
      function_version
    ]
  }
}

resource "aws_iam_role_policy" "invocation_policy" {
  name = "default"
  role = aws_iam_role.apigateway_invocation_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "lambda:InvokeFunction",
      "Effect": "Allow",
      "Resource": "${aws_lambda_function.jwt-authorizer.arn}"
    }
  ]
}
EOF
}

## Authorizer
resource "aws_iam_role" "apigateway_invocation_role" {
  name = "api_gateway_auth_invocation"
  path = "/"

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

resource "aws_api_gateway_authorizer" "jwt_authorizer" {
  name = "repository_jwt_authorizer"
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  authorizer_uri = aws_lambda_function.jwt-authorizer.invoke_arn
  authorizer_credentials = aws_iam_role.apigateway_invocation_role.arn
  type = "REQUEST"
  // https://forum.serverless.com/t/rest-api-with-custom-authorizer-how-are-you-dealing-with-authorization-and-policy-cache/3310
  //
  authorizer_result_ttl_in_seconds = 0
  // TODO increase, default is 300
}

## DNS
/*
locals {
  repo_fqdn = "${var.dns_repo_subdomain}.${var.root_domain}"
}


resource "aws_api_gateway_domain_name" "repo_domain_name" {
  domain_name = local.repo_fqdn
  regional_certificate_arn = aws_acm_certificate_validation.repo_certificate_validation.certificate_arn
  endpoint_configuration {
    types = [
      "REGIONAL"]
  }
}

resource "aws_route53_record" "repo_domain_name" {
  name = aws_api_gateway_domain_name.repo_domain_name.domain_name
  type = "A"
  zone_id = aws_route53_zone.dotcom.id

  alias {
    evaluate_target_health = true
    name = aws_api_gateway_domain_name.repo_domain_name.regional_domain_name
    zone_id = aws_api_gateway_domain_name.repo_domain_name.regional_zone_id
  }
}

resource "aws_api_gateway_base_path_mapping" "repo_mapping" {
  api_id = aws_api_gateway_rest_api.repository_api.id
  stage_name = aws_api_gateway_stage.repository_srv_stg.stage_name
  domain_name = aws_api_gateway_domain_name.repo_domain_name.domain_name
}
*/

## CORS
module "cors_bundles" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id = aws_api_gateway_rest_api.repository_api.id
  api_resource_id = aws_api_gateway_resource.bundles.id

  /*
  allow_headers = [
    "Authorization",
    "Content-Type",
    "X-Amz-Date",
    "X-Amz-Security-Token",
    "X-Api-Key",
    "Access-Control-Allow-Origin"
  ]
  */
}

module "cors_bundle_item" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id = aws_api_gateway_rest_api.repository_api.id
  api_resource_id = aws_api_gateway_resource.bundles_folder_item.id
}

module "cors_policies" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id = aws_api_gateway_rest_api.repository_api.id
  api_resource_id = aws_api_gateway_resource.policies.id
}

module "cors_policy_item" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id = aws_api_gateway_rest_api.repository_api.id
  api_resource_id = aws_api_gateway_resource.policy_item.id
}


## Status
resource "aws_api_gateway_resource" "status_resource" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  parent_id = aws_api_gateway_rest_api.repository_api.root_resource_id
  path_part = "status"
}

resource "aws_api_gateway_integration" "receive_status" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.status_resource.id
  http_method = aws_api_gateway_method.status_api.http_method
  integration_http_method = "POST"
  type = "AWS"
  credentials = aws_iam_role.status_queue_publish.arn
  //uri                     = aws_sqs_queue.opa_status_queue.arn
  //uri                     = "arn:aws:apigateway:${var.region}:sqs:action/SendMessage"
  uri = "arn:aws:apigateway:${var.region}:sqs:path/${aws_sqs_queue.opa_status_queue.name}"
  passthrough_behavior = "NEVER"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  // Action=SendMessage&MessageBody=$input.json('$')
  // MessageGroupId=1&
  // TODO: make FIFO
  request_templates = {
    // "application/json" = "Action=SendMessage&MessageBody=$input.body"
    "application/json" = "Action=SendMessage&MessageBody={\"params\":{\"account_no\":$context.authorizer.account_no},\"status\":$input.json('$')}"
  }
}

resource "aws_api_gateway_method" "status_api" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.status_resource.id
  api_key_required = false
  http_method = "POST"
  // authorization        = "NONE"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt_authorizer.id

  request_parameters = {
    // "method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_documentation_part" "post_status_doc" {
  location {
    type = "METHOD"
    method = aws_api_gateway_method.status_api.http_method
    path = aws_api_gateway_resource.status_resource.path
  }

  properties = jsonencode({
    description = "Post status."
    summary = "Post status"
    operationId = "sendStatus"
    tags = [
      "Status"]
  })

  rest_api_id = aws_api_gateway_rest_api.repository_api.id
}

resource "aws_api_gateway_method_response" "status_r200" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.status_resource.id
  http_method = aws_api_gateway_integration.receive_status.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "r200" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  resource_id = aws_api_gateway_resource.status_resource.id
  http_method = aws_api_gateway_method_response.status_r200.http_method
  status_code = aws_api_gateway_method_response.status_r200.status_code
  //selection_pattern = "^2[0-9][0-9]"                                       // regex pattern for any 200 message that comes back from SQS

  response_templates = {
    "application/json" = "{\"message\": \"status received!\"}"
  }

  depends_on = [
    aws_api_gateway_integration.receive_status]
}

/*
resource "aws_cloudwatch_log_group" "private-api-logs" {
  name              = "API-Gateway-Execution-Logs_OPC-Private"
  retention_in_days = 3
}
*/
/*
data "aws_iam_policy_document" "status_api_policy_doc" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:FilterLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

resource "aws_iam_policy" "private_api_policy" {
  name = "status_api_logging_policy"
  path = "/"
  description = "IAM policy for private api"
  policy = data.aws_iam_policy_document.status_api_policy_doc.json
}

resource "aws_iam_policy_attachment" "api_gateway_logs" {
  name = "api_gateway_logs_policy_attach"
  roles = [
    aws_iam_role.cloudwatch.id]
  policy_arn = aws_iam_policy.private_api_policy.arn
}

resource "aws_api_gateway_method_settings" "status_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  stage_name  = aws_api_gateway_stage.repository_srv_stg.stage_name
  method_path = "${aws_api_gateway_resource.status_resource.path_part}/${aws_api_gateway_method.status_api.http_method}"

  settings {
    metrics_enabled = true
    logging_level = "INFO"
    data_trace_enabled = false
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
*/

data "aws_iam_policy_document" "private-api-policy" {
  /*
    statement {
      actions = ["execute-api:Invoke"]
      effect = "Deny"
      principals {
        identifiers = ["*"]
        type = "*"
      }
      resources = [aws_api_gateway_rest_api.private_api.arn]
      condition {
        test = "StringNotEquals"
        variable = "aws:sourceVpc"  # TODO: `aws:SourceVpce`
        values = [aws_vpc.aws-vpc.id, aws_default_vpc.default.id]
      }
      sid = "1"
    }
  */
  statement {
    actions = [
      "execute-api:Invoke"]
    effect = "Allow"
    principals {
      identifiers = [
        "*"]
      type = "*"
    }
    //resources = ["arn:aws:execute-api:ap-southeast-2:377258293252:9ms2c3v81c/*/POST/status"]
    resources = [
      "*"]
    sid = "2"
  }
}

/*
resource "aws_api_gateway_rest_api_policy" "from-opc-vpc" {
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  policy = data.aws_iam_policy_document.private-api-policy.json
}
*/

/*
resource "aws_api_gateway_stage" "dev-stage" {
  stage_name    = "dev-temp" // This a hack to fix the API being auto deployed.
  rest_api_id   = aws_api_gateway_rest_api.private_api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
}
*/

/*
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id     = aws_api_gateway_rest_api.repository_api.id
  stage_name      = "dev"
}
*/

/*
output "private_api_url" {
  value = aws_api_gateway_deployment.deployment.invoke_url
}
*/


## Documentation Part Version
resource "aws_api_gateway_documentation_part" "api_doc" {
  properties = jsonencode({
    description = "Repository API."
    summary = "Repository"
    "termsOfService": "http://example.com/terms/",
    "contact": {
      "name": "API Support",
      "url": "http://www.example.com/support",
      "email": "support@example.com"
    },
    "license": {
      "name": "Apache 2.0",
      "url": "https://www.apache.org/licenses/LICENSE-2.0.html"
    },
    "version": "1.0.1"
  })

  rest_api_id = aws_api_gateway_rest_api.repository_api.id

  location {
    type = "API"
  }
}

resource "aws_api_gateway_documentation_version" "repository_api_doc_version" {
  version = "0.1.3"
  rest_api_id = aws_api_gateway_rest_api.repository_api.id
  description = "Repository API Documentation"
  depends_on = [
    aws_api_gateway_documentation_part.api_doc,
    aws_api_gateway_documentation_part.get_bundles_doc,
    aws_api_gateway_documentation_part.put_bundle_item_doc,
    aws_api_gateway_documentation_part.delete_bundle_item_doc,
    aws_api_gateway_documentation_part.list_policies_doc,
    aws_api_gateway_documentation_part.put_policy_item_doc,
    aws_api_gateway_documentation_part.get_policy_item_doc,
    aws_api_gateway_documentation_part.delete_policy_item_doc,
    aws_api_gateway_documentation_part.post_status_doc,
    aws_api_gateway_documentation_part.bundle_content_delete_item_doc,
    aws_api_gateway_documentation_part.bundle_content_get_item_doc,
    aws_api_gateway_documentation_part.bundle_content_post_item_doc,
  ]
}


