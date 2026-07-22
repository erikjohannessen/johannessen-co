data "aws_route53_zone" "primary" {
  name         = "${var.route53_zone_name}."
  private_zone = false
}

module "ghost_test" {
  source = "./modules/ghost_site"

  name_prefix     = "ghost-test"
  domain_name     = "test.johannessen.co"
  route53_zone_id = data.aws_route53_zone.primary.zone_id
  aws_region      = var.aws_region
  db_password     = var.db_password
  ghost_image     = var.ghost_image
}

module "ghost_prod" {
  source = "./modules/ghost_site"

  name_prefix     = "ghost-prod"
  domain_name     = "blog.johannessen.co"
  route53_zone_id = data.aws_route53_zone.primary.zone_id
  aws_region      = var.aws_region
  db_password     = var.db_password
  ghost_image     = var.ghost_image
}

resource "aws_route53_record" "ghost_test" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "test.johannessen.co"
  type    = "A"

  alias {
    name                   = module.ghost_test.alb_dns_name
    zone_id                = module.ghost_test.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "ghost_prod" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "blog.johannessen.co"
  type    = "A"

  alias {
    name                   = module.ghost_prod.alb_dns_name
    zone_id                = module.ghost_prod.alb_zone_id
    evaluate_target_health = true
  }
}
