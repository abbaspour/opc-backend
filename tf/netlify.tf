resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.root_domain.zone_id
  name = var.www_domain
  type = "CNAME"
  ttl = 300
  records = [ "opc-website.netlify.app" ]

/*
  alias {
    name = aws_cloudfront_distribution.www_distribution.domain_name
    zone_id = aws_cloudfront_distribution.www_distribution.hosted_zone_id
    evaluate_target_health = false
  }
*/
}

resource "aws_route53_record" "naked" {
  zone_id = aws_route53_zone.root_domain.zone_id
  name = ""
  type = "A"
  ttl = 300
  records = [ "75.2.60.5" ]
}

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.root_domain.zone_id
  name = "app"
  type = "CNAME"
  ttl = 300
  records = [ "opc-app.netlify.app" ]
}

resource "aws_route53_record" "docs" {
  zone_id = aws_route53_zone.root_domain.zone_id
  name = var.docs_domain
  type = "CNAME"
  ttl = 300
  records = [ "opc-docs.netlify.app" ]
}
