resource "aws_appsync_graphql_api" "repository" {
  authentication_type = "OPENID_CONNECT"
  name = "repository"

  schema = file("./graphql/repository.graphql")

  openid_connect_config {
    issuer = local.issuer
  }

  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.iam_appsync_role.arn
    field_log_level          = "ALL"
  }
}

## IAM
data "aws_iam_policy_document" "iam_appsync_role_document" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["appsync.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iam_appsync_role" {
  name = "appsync_role"
  assume_role_policy = data.aws_iam_policy_document.iam_appsync_role_document.json
}

resource "aws_iam_role_policy_attachment" "appsync_cloudwatch_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppSyncPushToCloudWatchLogs"
  role       = aws_iam_role.iam_appsync_role.name
}

## Data Sources
resource "aws_appsync_datasource" "repository" {
  api_id = aws_appsync_graphql_api.repository.id
  name = "repository"
  type = "HTTP"

  http_config {
    endpoint = aws_api_gateway_deployment.repository_srv_deployment.invoke_url
  }
}

## Bundles

resource "aws_appsync_resolver" "list_bundles_resolver" {
  api_id = aws_appsync_graphql_api.repository.id
  field = "listBundles"
  request_template = file("./graphql/resolvers/bundles-request.vtl")
  response_template = file("./graphql/resolvers/bundles-response.vtl")
  data_source = aws_appsync_datasource.repository.name
  type = "Query"
}

## Policies
resource "aws_appsync_resolver" "list_policies_resolver" {
  api_id = aws_appsync_graphql_api.repository.id
  field = "listPolicies"
  request_template = file("./graphql/resolvers/policies-request.vtl")
  response_template = file("./graphql/resolvers/policies-response.vtl")
  data_source = aws_appsync_datasource.repository.name
  type = "Query"
}
