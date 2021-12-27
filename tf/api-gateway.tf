resource "aws_apigatewayv2_api" "api" {
  name = "Runtime API"
  description = "https://api.openpolicy.cloud/runtime"
  protocol_type = "HTTP"


  cors_configuration {
    allow_credentials = true
    allow_headers = [
      "*"]
    allow_methods = [
      "*"]
    allow_origins = [
      "https://*"]
    expose_headers = [
      "*"]
    max_age = 3600
  }

}

resource "aws_cloudwatch_log_group" "api_logs" {
  name = "/api/logs"
  retention_in_days = 3
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode(
      {
        httpMethod     = "$context.httpMethod"
        ip             = "$context.identity.sourceIp"
        protocol       = "$context.protocol"
        requestId      = "$context.requestId"
        requestTime    = "$context.requestTime"
        responseLength = "$context.responseLength"
        routeKey       = "$context.routeKey"
        status         = "$context.status"
        errorMessage   = "$context.error.message"
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


resource "aws_apigatewayv2_integration" "post-token" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"

  connection_type      = "INTERNET"
  description          = "This is our POST /token integration"
  integration_method   = "POST"
  integration_uri      = aws_lambda_function.post-token.invoke_arn
  passthrough_behavior = "WHEN_NO_MATCH"
  payload_format_version = "2.0"

  lifecycle {
    ignore_changes = [
      passthrough_behavior
    ]
  }
}

resource "aws_apigatewayv2_integration" "list-instances" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"

  connection_type      = "INTERNET"
  description          = "This is our GET /instances integration"
  integration_method   = "POST"
  integration_uri      = aws_lambda_function.list-instances.invoke_arn
  passthrough_behavior = "WHEN_NO_MATCH"
  payload_format_version = "2.0"

  lifecycle {
    ignore_changes = [
      passthrough_behavior
    ]
  }
}

resource "aws_apigatewayv2_integration" "start-stop-instances" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"

  connection_type      = "INTERNET"
  description          = "This is our POST /instances/{instance}/start,stop integration"
  integration_method   = "POST"
  integration_uri      = aws_lambda_function.start-stop-instance.invoke_arn
  passthrough_behavior = "WHEN_NO_MATCH"
  payload_format_version = "2.0"

  lifecycle {
    ignore_changes = [
      passthrough_behavior
    ]
  }
}

resource "aws_apigatewayv2_integration" "get-instance" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"

  connection_type      = "INTERNET"
  description          = "This is our GET /v1/instances/{instance} integration"
  integration_method   = "POST"
  integration_uri      = aws_lambda_function.get-instance.invoke_arn
  passthrough_behavior = "WHEN_NO_MATCH"
  payload_format_version = "2.0"

  lifecycle {
    ignore_changes = [
      passthrough_behavior
    ]
  }
}

resource "aws_apigatewayv2_integration" "create-account" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"

  connection_type      = "INTERNET"
  description          = "This is our POST /v1/account integration"
  integration_method   = "POST"
  integration_uri      = aws_lambda_function.create-account.invoke_arn
  passthrough_behavior = "WHEN_NO_MATCH"
  payload_format_version = "2.0"

  lifecycle {
    ignore_changes = [
      passthrough_behavior
    ]
  }
}

resource "aws_apigatewayv2_route" "list-instances" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "GET /v1/instances"
  target             = "integrations/${aws_apigatewayv2_integration.list-instances.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.auth0authorizer.id
  authorization_scopes = ["read:instances", "account:admin"]
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_route" "get-instance" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "GET /v1/instances/{instance}"
  target             = "integrations/${aws_apigatewayv2_integration.get-instance.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.auth0authorizer.id
  authorization_scopes = ["read:instances", "account:admin"]
  authorization_type = "JWT"

}

/*resource "aws_apigatewayv2_model" "get_instance_model" {
  api_id       = aws_apigatewayv2_api.api.id
  content_type = "application/json"
  name         = "example"

  schema = <<EOF
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "ExampleModel",
  "type": "object",
  "properties": {
    "id": { "type": "string" }
  }
}
EOF
}*/

resource "aws_apigatewayv2_route" "start-instance" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "POST /v1/instances/start"
  target             = "integrations/${aws_apigatewayv2_integration.start-stop-instances.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.auth0authorizer.id
  authorization_scopes = ["read:instances", "account:admin"]
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_route" "stop-instance" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "POST /v1/instances/stop"
  target             = "integrations/${aws_apigatewayv2_integration.start-stop-instances.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.auth0authorizer.id
  authorization_scopes = ["read:instances", "account:admin"]
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_route" "post-token" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "POST /token"
  target             = "integrations/${aws_apigatewayv2_integration.post-token.id}"
}

resource "aws_apigatewayv2_route" "create-account" {
  api_id             = aws_apigatewayv2_api.api.id // todo: different API
  route_key          = "POST /v1/account"
  target             = "integrations/${aws_apigatewayv2_integration.create-account.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.auth0admin.id
  authorization_scopes = ["create:account"]
  authorization_type = "JWT"
}

resource "aws_lambda_permission" "invoke-post-token" {
   statement_id  = "AllowAPIGatewayInvoke"
   action        = "lambda:InvokeFunction"
   function_name = aws_lambda_function.post-token.function_name
   principal     = "apigateway.amazonaws.com"
   source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "invoke-list-instances" {
   statement_id  = "AllowAPIGatewayInvoke"
   action        = "lambda:InvokeFunction"
   function_name = aws_lambda_function.list-instances.function_name
   principal     = "apigateway.amazonaws.com"
   source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "invoke-start-stop-instance" {
   statement_id  = "AllowAPIGatewayInvoke"
   action        = "lambda:InvokeFunction"
   function_name = aws_lambda_function.start-stop-instance.function_name
   principal     = "apigateway.amazonaws.com"
   source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "invoke-get-instance" {
   statement_id  = "AllowAPIGatewayInvoke"
   action        = "lambda:InvokeFunction"
   function_name = aws_lambda_function.get-instance.function_name
   principal     = "apigateway.amazonaws.com"
   source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "invoke-create-account" {
   statement_id  = "AllowAPIGatewayInvoke"
   action        = "lambda:InvokeFunction"
   function_name = aws_lambda_function.create-account.function_name
   principal     = "apigateway.amazonaws.com"
   source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*/v1/account"
}

resource "aws_security_group" "api-gw-sg" {
  name        = "api-gateway-sg"
  description = "allow inbound access from the API Gateway only"
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


resource "aws_apigatewayv2_authorizer" "auth0authorizer" {
  name             = "auth0authorizer"
  api_id           = aws_apigatewayv2_api.api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [var.api_audience]
    issuer   = "https://${var.auth0_domain}/"
  }
}

resource "aws_apigatewayv2_authorizer" "auth0admin" {
  name             = "auth0admin_authorizer"
  api_id           = aws_apigatewayv2_api.api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [var.admin_api_audience]
    issuer   = "https://${var.auth0_domain}/"
  }
}


## DNS
locals {
  api_fqdn = "${var.dns_api_subdomain}.${var.opc_root_domain}"
}

resource "aws_apigatewayv2_domain_name" "domain_name" {
  domain_name = local.api_fqdn

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.api_certificate.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

/*
  depends_on = [
    aws_route53_record.api_certificate_validation
  ]
*/

}

resource "aws_route53_record" "dns_record" {
  name    = aws_apigatewayv2_domain_name.domain_name.domain_name
  type    = "A"
  zone_id = aws_route53_zone.root_domain.zone_id

  alias {
    name                   = aws_apigatewayv2_domain_name.domain_name.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.domain_name.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_apigatewayv2_api_mapping" "api_mapping" {
  api_id = aws_apigatewayv2_api.api.id
  domain_name = aws_apigatewayv2_domain_name.domain_name.domain_name
  stage = aws_apigatewayv2_stage.default.id
  api_mapping_key = "runtime"
}

resource "aws_apigatewayv2_api_mapping" "repo_mapping" {
  api_id = aws_api_gateway_rest_api.repository_api.id
  domain_name = aws_apigatewayv2_domain_name.domain_name.domain_name
  stage = aws_api_gateway_stage.repository_srv_stg.stage_name
  api_mapping_key = "repository"
}
