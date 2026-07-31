module "ghost_site" {
  source = "./modules/ghost_site"

  environment                 = var.environment
  route53_zone_name           = var.route53_zone_name
  subdomain                   = var.subdomain
  aws_region                  = var.aws_region
  db_password                 = var.db_password
  ghost_image                 = var.ghost_image
  ssm_tunnel_instance_type    = var.ssm_tunnel_instance_type
  ssm_tunnel_instance_profile = var.ssm_tunnel_instance_profile
  local_dev_ip                = var.local_dev_ip
}
