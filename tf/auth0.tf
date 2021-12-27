resource "auth0_client" "cli" {
  name = "CLI Client"
  description = "ROPG client for command line and /token lambda"
  app_type = "regular_web"
  oidc_conformant = true
  is_first_party = true
  grant_types = [
    "http://auth0.com/oauth/grant-type/password-realm",
    "password"]
}

resource "auth0_connection" "api-clients-db" {
  name = "api-clients-db"
  strategy = "auth0"
  options {
    requires_username = true
    password_policy = "excellent"
    disable_signup = true
  }
  enabled_clients = [
    auth0_client.cli.id,
    var.auth0_tf_client_id
  ]
}

resource "auth0_connection" "users" {
  name = "users"
  strategy = "auth0"
  options {
    requires_username = false
    password_policy = "low"
    disable_signup = true
  }
  enabled_clients = [
    auth0_client.webapp.id,
    var.auth0_tf_client_id
  ]
}

resource "auth0_user" "test-api-user-1" {
  connection_name = auth0_connection.api-clients-db.name
  username = var.auth0_test_username_1
  password = var.auth0_test_password_1
  email = "${var.auth0_test_username_1}@clients.openpolicy.cloud"
  app_metadata = jsonencode({
    account_no = var.auth0_test_account_no_1
  })
}

resource "auth0_user" "test-web-user-1" {
  connection_name = auth0_connection.users.name
  email = var.auth0-demo-user-email
  password = var.auth0-demo-user-password
  app_metadata = jsonencode({
    account_no = var.auth0_test_account_no_1
  })
}

/*
resource "auth0_user" "test-user-2" {
  connection_name = auth0_connection.api-clients-db.name
  username = var.auth0_test_username_2
  password = var.auth0_test_password_2
  email = "${var.auth0_test_username_2}@clients.dev.openpolicy.cloud"
  app_metadata = jsonencode({
    account_no = 100534235
  })
}
*/

resource "auth0_resource_server" "opc-api-rs" {
  name = "opc.api"
  identifier = "opc.api"
  signing_alg = "RS256"
  allow_offline_access = false
  token_lifetime = 8600
  skip_consent_for_verifiable_first_party_clients = true

  scopes {
    value = "read:policies"
    description = "read policies"
  }

  scopes {
    value = "create:policy"
    description = "create policy"
  }

  scopes {
    value = "get:data"
    description = "get data with GET and POST request"
  }

  scopes {
    value = "account:admin"
    description = "account admin"
  }

  scopes {
    value = "read:instances"
    description = "get runtime instances"
  }
}

## admin
resource "auth0_resource_server" "opc-admin-rs" {
  name = "opc.admin"
  identifier = "opc.admin"
  signing_alg = "RS256"
  allow_offline_access = false
  token_lifetime = 8600
  skip_consent_for_verifiable_first_party_clients = false

  scopes {
    value = "create:account"
    description = "create account"
  }
}

resource "auth0_client" "admin-cli" {
  name = "admin client"
  description = "admin client to call admin api from command line"
  app_type = "non_interactive"
  oidc_conformant = true
  is_first_party = true
  grant_types = [
    "client_credentials"
  ]
}

resource "auth0_client" "rules_m2m_client" {
  name = "rules client"
  description = "m2m client to provision account from rules"
  app_type = "non_interactive"
  oidc_conformant = true
  is_first_party = true
  grant_types = [
    "client_credentials"
  ]
}

resource "auth0_client_grant" "admin-client-grant" {
  audience = auth0_resource_server.opc-admin-rs.name
  client_id = auth0_client.admin-cli.id
  scope = [
    "create:account"
  ]
}

resource "auth0_client_grant" "rules-client-grant" {
  audience = auth0_resource_server.opc-admin-rs.name
  client_id = auth0_client.rules_m2m_client.id
  scope = [
    "create:account"
  ]
}

locals {
  app_url = "https://app.${var.opc_root_domain}"
  local_dev_url = "https://local.${var.opc_root_domain}"
}

resource "auth0_client" "webapp" {
  name = "Webapp"
  description = "app.openpolicy.cloud"
  app_type = "spa"
  oidc_conformant = true
  is_first_party = true
  token_endpoint_auth_method = "none"
  grant_types = [
    "authorization_code",
    "refresh_token"
  ]
  callbacks = [
    local.app_url,
    local.local_dev_url,
    var.auth0_local_dev_url
  ]
  web_origins = [
    local.app_url,
    local.local_dev_url,
    var.auth0_local_dev_url
  ]
  allowed_logout_urls = [
    local.app_url,
    local.local_dev_url,
    var.auth0_local_dev_url
  ]
  allowed_origins = [
    local.app_url,
    local.local_dev_url,
    var.auth0_local_dev_url
  ]
}

/*
resource "auth0_connection" "google_social" {
  # https://console.developers.google.com/apis/credentials?project=openpolicy-dev
  # https://auth0.com/docs/connections/social/google
  name = "google"
  strategy = "google-oauth2"
  options {
    client_id = var.google_client_id
    client_secret = var.google_client_secret
    scopes = [
      "email",
      "profile"]
  }
  enabled_clients = [
    auth0_client.webapp.id
  ]
}
*/

output "app_client_id" {
  value = auth0_client.webapp.id
}


resource "auth0_tenant" "tenant_config" {
  friendly_name = "Open Policy Cloud"
  support_email = "support@openpolicy.cloud"
  allowed_logout_urls = [
    "${local.app_url}/logout"
  ]
  flags {
    enable_client_connections = false
  }
}

## Rules data
data "local_file" "rule01" {
  filename = "rules/01-globals.js"
}

data "local_file" "rule10" {
  filename = "rules/10-account_no.js"
}

## Rules
resource "auth0_rule" "rule01" {
  name = "globals"
  order = 1
  enabled = true
  script = data.local_file.rule01.content
}

resource "auth0_rule" "rule10" {
  name = "account"
  order = 10
  enabled = true
  script = data.local_file.rule10.content
}

## Rules config
resource "auth0_rule_config" "m2m_client_id" {
  key = "client_id"
  value = auth0_client.rules_m2m_client.client_id
}

resource "auth0_rule_config" "m2m_client_secret" {
  key = "client_secret"
  value = auth0_client.rules_m2m_client.client_secret
}

resource "auth0_rule_config" "base_url" {
  key = "API_BASE_URL"
  value = aws_apigatewayv2_stage.default.invoke_url

}

## Event bridge
data "aws_caller_identity" "current" {}

/*
resource "auth0_log_stream" "event_bridge" {
  type = "eventbridge"
  name = "AWS EventBridge"
  sink {
    aws_region = var.region
    aws_account_id = data.aws_caller_identity.current.account_id
  }
}
*/

## custom domain
//noinspection MissingProperty
resource "auth0_custom_domain" "my_custom_domain" {
  domain = "id.${var.opc_root_domain}"
  type = "auth0_managed_certs"
  //verification_method = "CNAME"
}

resource "auth0_custom_domain_verification" "my_custom_domain_verification" {
  custom_domain_id = auth0_custom_domain.my_custom_domain.id
  timeouts { create = "5m" }
  depends_on = [ aws_route53_record.auth0_validation ]
}

