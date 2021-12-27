# https://www.openpolicyagent.org/docs/latest/rest-api/

resource "aws_apigatewayv2_api" "opa" {
  name = "OPA REST API"
  description = "https://opa.openpolicy.cloud"
  protocol_type = "HTTP"
}

resource "aws_cloudwatch_log_group" "opa_api_logs" {
  name = "/api/opa"
  retention_in_days = 3
}

resource "aws_apigatewayv2_stage" "opa_default" {
  api_id = aws_apigatewayv2_api.opa.id
  name = "$default"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.opa_api_logs.arn
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

  lifecycle {
    ignore_changes = [
      deployment_id,
      default_route_settings
    ]
  }
}

resource "aws_apigatewayv2_integration" "opa_root" {
  api_id = aws_apigatewayv2_api.opa.id

  integration_type = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri = aws_lb_listener.opa_ecs_lb_listener.arn

  connection_type = "VPC_LINK"
  connection_id = aws_apigatewayv2_vpc_link.opa_gw_vpc_link.id

  description = "This is our ANY /{proxy+} integration"

  //integration_uri = "http://${aws_lb.opa_ecs_lb.dns_name}"
  //passthrough_behavior = "WHEN_NO_MATCH"

  credentials_arn  = aws_iam_role.apigatewayv2_invocation_role.arn

  request_parameters = {
    "overwrite:header.account_no" = "$context.authorizer.account_no"
    //"overwrite:header.account_no" = "$context.authorizer.claims[\"https:\\/\\/opc.ns\\/account_no\"]"
  }

  lifecycle {
    ignore_changes = [
      passthrough_behavior
    ]
  }

}


## routes
resource "aws_apigatewayv2_route" "opa_root" {
  api_id = aws_apigatewayv2_api.opa.id
  route_key = "ANY /{proxy+}"
  target = "integrations/${aws_apigatewayv2_integration.opa_root.id}"
  authorizer_id = aws_apigatewayv2_authorizer.opa_authorizer.id
  authorization_type = "CUSTOM"
}


## JWT authorizer
/*
resource "aws_apigatewayv2_authorizer" "opa_auth0_authorizer" {
  name             = "opa_auth0_authorizer"
  api_id           = aws_apigatewayv2_api.opa.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [var.api_audience]
    issuer   = "https://${var.auth0_domain}/"
  }
}
*/

## Lambda authorizer
resource "aws_iam_role_policy" "opa_gw_invocation_policy" {
  name = "opa-allow-invoke"
  role = aws_iam_role.apigatewayv2_invocation_role.id

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


resource "aws_iam_role" "apigatewayv2_invocation_role" {
  name = "api_gatewayv2_auth_invocation"
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


resource "aws_apigatewayv2_authorizer" "opa_authorizer" {
  name = "repository_jwt_authorizer"
  api_id = aws_apigatewayv2_api.opa.id
  authorizer_uri = aws_lambda_function.jwt-authorizer.invoke_arn
  authorizer_credentials_arn = aws_iam_role.apigatewayv2_invocation_role.arn
  // https://forum.serverless.com/t/rest-api-with-custom-authorizer-how-are-you-dealing-with-authorization-and-policy-cache/3310
  authorizer_payload_format_version = "1.0"
  authorizer_result_ttl_in_seconds = 0
  // TODO increase, default is 300
  authorizer_type = "REQUEST"
  identity_sources = [
    "$request.header.Authorization"]
}

## VPC link
resource "aws_security_group" "opa_vpc_link_sg" {
  name = "opa_vpc_link_sg"
  vpc_id = aws_vpc.aws-vpc.id
  ingress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}


resource "aws_apigatewayv2_vpc_link" "opa_gw_vpc_link" {
  name = "opa_gw_vpc_link"
  security_group_ids = [
    aws_security_group.opa_vpc_link_sg.id]
  subnet_ids = aws_subnet.nat_subnet.*.id
}

## DNS
locals {
  opa_fqdn = "${var.dns_opa_subdomain}.${var.opc_root_domain}"
}

resource "aws_apigatewayv2_domain_name" "opa_domain_name" {
  domain_name = local.opa_fqdn
  domain_name_configuration {
    certificate_arn = aws_acm_certificate.opa_certificate.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_route53_record" "opa_dns_record" {
  name    = aws_apigatewayv2_domain_name.opa_domain_name.domain_name
  type    = "A"
  zone_id = aws_route53_zone.root_domain.zone_id

  alias {
    name                   = aws_apigatewayv2_domain_name.opa_domain_name.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.opa_domain_name.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_apigatewayv2_api_mapping" "opa_api_mapping" {
  api_id = aws_apigatewayv2_api.opa.id
  domain_name = aws_apigatewayv2_domain_name.opa_domain_name.domain_name
  stage = aws_apigatewayv2_stage.opa_default.id
  // api_mapping_key = ""
}
