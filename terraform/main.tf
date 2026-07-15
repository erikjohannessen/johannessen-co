data "aws_route53_zone" "primary" {
  name         = "${var.route53_zone_name}."
  private_zone = false
}

module "ghost_test" {
  source = "./modules/ghost_site"

  name_prefix   = "ghost-test"
  domain_name   = "test.johannessen.co"
  instance_type = var.ghost_instance_type
  db_password   = var.db_password
}

module "ghost_prod" {
  source = "./modules/ghost_site"

  name_prefix   = "ghost-prod"
  domain_name   = "blog.johannessen.co"
  instance_type = var.ghost_instance_type
  db_password   = var.db_password
}

resource "aws_route53_record" "ghost_test" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "test.johannessen.co"
  type    = "A"
  ttl     = 300
  records = [module.ghost_test.elastic_ip]
}

resource "aws_route53_record" "ghost_prod" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "blog.johannessen.co"
  type    = "A"
  ttl     = 300
  records = [module.ghost_prod.elastic_ip]
}

