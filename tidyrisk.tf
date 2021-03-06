# Data source for ACM certificate
/*
resource "aws_acm_certificate_validation" "tidyrisk" {
  provider                = aws.us-east-1
  certificate_arn         = aws_acm_certificate.tidyrisk.arn
  validation_record_fqdns = [aws_route53_record.tidyrisk_cert_validation.fqdn]
}
*/

resource "aws_acm_certificate" "tidyrisk" {
  provider = aws.us-east-1

  domain_name               = "tidyrisk.org"
  subject_alternative_names = ["*.tidyrisk.org"]
  validation_method         = "DNS"

  tags = {
    managed_by = "Terraform"
    project    = var.project
    Name       = "Tidyrisk domain"
  }

  lifecycle {
    create_before_destroy = true
  }
}

/*
  ------------------------
  | TidyRisk DNS Records |
  ------------------------
*/

resource "aws_route53_zone" "tidyrisk" {
  name = "tidyrisk.org."

  tags = {
    managed_by = "Terraform"
    project    = var.project
  }
}

resource "aws_route53_record" "tidyrisk_cert_validation" {
  zone_id = aws_route53_zone.tidyrisk.zone_id
  name    = aws_acm_certificate.tidyrisk.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.tidyrisk.domain_validation_options.0.resource_record_type
  records = [aws_acm_certificate.tidyrisk.domain_validation_options.0.resource_record_value]
  ttl     = "600"
}

resource "aws_route53_record" "tidyrisk" {
  zone_id = aws_route53_zone.tidyrisk.zone_id
  name    = aws_route53_zone.tidyrisk.name
  type    = "A"

  alias {
    name                   = module.tidyriskcdn.domain_name
    zone_id                = module.tidyriskcdn.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "tidyrisk_www" {
  zone_id = aws_route53_zone.tidyrisk.zone_id
  name    = "www.${aws_route53_zone.tidyrisk.name}"
  type    = "A"

  alias {
    name                   = module.tidyriskcdn.domain_name
    zone_id                = module.tidyriskcdn.hosted_zone_id
    evaluate_target_health = false
  }
}

/*
  -------------
  | CDN Setup |
  -------------
*/

# configure cloudfront SSL caching for S3 hosted static content
module "tidyriskcdn" {
  #source = "../../modules//cloudfronts3"
  source    = "github.com/davidski/tf-cloudfronts3?ref=ea7c42b"
  providers = { aws = aws.us-east-1, aws.bucket = aws }

  bucket_name              = "tidyrisk"
  origin_id                = "tidyrisk_bucket"
  alias                    = ["tidyrisk.org", "www.tidyrisk.org"]
  acm_certificate_arn      = aws_acm_certificate.tidyrisk.arn
  project                  = var.project
  audit_bucket             = data.terraform_remote_state.main.outputs.auditlogs
  minimum_protocol_version = "TLSv1.2_2018"
}
