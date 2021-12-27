variable "app_name" {
  type = string
  description = "Application name"
  default = "OPC-App"
}

variable "app_environment" {
  type = string
  description = "Environment"
  default = "dev"
}

variable "s3_opa_bundles_bucket" {
  type = string
  description = "OPA discovery and bundles S3 bucket"
}

variable "s3_website_bucket_dev" {
  type = string
  description = "website dev version"
  default = "opc-website-dev"
}

variable "s3_website_root_bucket_dev" {
  type = string
  description = "website dev version root bucket"
  default = "opc-website-root-dev"
}

variable "lambda_version" {
  type = string
  description = "Lambda version"
}

variable "lambda_bucket" {
  type = string
  description = "Lambda bucket"
}

variable "ecs_ssh_pass" {
  type = string
  sensitive = true
}

variable "ecs_ssh_user" {
  type = string
  default = "amin"
}

variable "auth0_domain" {
  type = string
  description = "auth0 domain"
}

variable "auth0_canonical_domain" {
  type = string
  description = "auth0 canonical domain"
}

variable "api_audience" {
  type = string
  description = "audience"
  default = "opc.api"
}

variable "admin_api_audience" {
  type = string
  description = "admin api audience"
  default = "opc.admin"
}

variable "auth0_tf_client_id" {
  type = string
  description = "Auth0 TF provider client_id"
}

variable "auth0_tf_client_secret" {
  type = string
  description = "Auth0 TF provider client_secret"
  sensitive = true
}

variable "auth0_test_username_1" {
  type = string
  description = "demo username"
}

variable "auth0_test_password_1" {
  type = string
  description = "demo password"
  sensitive = true
}

variable "auth0_test_account_no_1" {
  type = number
  description = "demo account_no"
}

variable "auth0-demo-user-email" {
  type = string
  description = "demo email"
  default = "demo@openpolicy.cloud"
}

variable "auth0-demo-user-password" {
  type = string
  description = "demo password"
  sensitive = true
}

/*
variable "auth0_test_username_2" {
  type = string
  description = "Auth0 test username"
}

variable "auth0_test_password_2" {
  type = string
  description = "Auth0 test password"
  sensitive = true
}
*/

variable "github_personal_token" {
  type = string
  description = "github personal token. requires repo and user full"
  sensitive = true
}

variable "github_owner" {
  type = string
  description = "github owner"
  default = "abbaspour"
}

variable "github_repo" {
  type = string
  description = "account infra github repo"
  default = "opc-accounts"
}

variable "opc_root_domain" {
  type = string
  description = "domain name"
  default = "openpolicy.cloud"
}

variable "www_domain" {
  type = string
  description = "www domain name"
  default = "www.openpolicy.cloud"
}

variable "docs_domain" {
  type = string
  description = "docs domain name"
  default = "docs.openpolicy.cloud"
}

variable "auth0_origin" {
  type = string
  description = "Origin Domain Name"
}

variable "auth0_cname_api_key" {
  type = string
  description = "cname api key"
  sensitive = true
}

variable "auth0_jwks_kid" {
  type = string
  description = "active jwks.json kid"
}

variable "auth0_subdomain" {
  type = string
  description = "subdomain pointing to auth0 custom domain name"
  default = "id"
}

variable "s3_bucket_app_dev" {
  type = string
  description = "bucket for app subdomain static content"
  default = "opc-website-app-dev"
}

variable "auth0_local_dev_url" {
  type = string
  description = "local app development url"
  default = "http://localhost:3000"
}

variable "google_client_id" {
  type = string
  description = "google social connection client_id"
}

variable "google_client_secret" {
  type = string
  description = "google social connection client_secret"
  sensitive = true
}

variable "dns_api_subdomain" {
  default = "api"
}

variable "dns_opa_subdomain" {
  default = "opa"
}
