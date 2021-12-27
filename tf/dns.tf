/*
resource "aws_route53_zone" "dev" {
  name = "dev.in.openpolicy.cloud"
  vpc {
    vpc_id = aws_vpc.aws-vpc.id
  }
  tags = {
    Environment = "dev"
  }
}
*/

resource "aws_route53_zone" "root_domain" {
  name = var.opc_root_domain
}

resource "aws_route53_record" "auth0_validation" {
  name = "${auth0_custom_domain.my_custom_domain.domain}."
  //value = "${auth0_custom_domain.my_custom_domain.verification[0].methods[0].record}."
  //name = "_cf-custom-hostname.id.openpolicy.cloud"
  type = "CNAME"
  ttl = 300
  records = ["${auth0_custom_domain.my_custom_domain.verification[0].methods[0].record}."]
  zone_id = aws_route53_zone.root_domain.zone_id
}

resource "aws_acm_certificate" "certificate" {
  // We want a wildcard cert so we can host subdomains later.
  domain_name = "*.${var.opc_root_domain}"
  validation_method = "EMAIL"
  provider = aws.virginia

  // We also want the cert to be valid for the root domain even though we'll be
  // redirecting to the www. domain immediately.
  subject_alternative_names = [
    var.opc_root_domain
  ]
}

## API
resource "aws_acm_certificate" "api_certificate" {
  domain_name = local.api_fqdn
  validation_method = "DNS"
  provider = aws // not virginia
}

resource "aws_acm_certificate" "opa_certificate" {
  domain_name = local.opa_fqdn
  validation_method = "DNS"
  provider = aws // not virginia
}

resource "aws_acm_certificate_validation" "opa_certificate_validation" {
  certificate_arn = aws_acm_certificate.opa_certificate.arn
}

resource "aws_acm_certificate_validation" "api_certificate_validation" {
  certificate_arn = aws_acm_certificate.opa_certificate.arn
}

resource "aws_route53_record" "api_certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.root_domain.zone_id
}

resource "aws_route53_record" "opa_certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.opa_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.root_domain.zone_id
}


resource "aws_route53_record" "jump" {
  name = "jump"
  type = "A"
  zone_id = aws_route53_zone.root_domain.zone_id
  ttl = 300
  records = [ aws_eip.nat_eip.public_ip ]
}

resource "aws_route53_record" "local" {
  name = "local"
  type = "CNAME"
  zone_id = aws_route53_zone.root_domain.zone_id
  ttl = 300
  records = [ "home.abbaspour.net" ]
}
