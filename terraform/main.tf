resource "aws_iam_role" "ssm_tunnel" {
  name = "ghost-ssm-tunnel-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_tunnel_core" {
  role       = aws_iam_role.ssm_tunnel.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_tunnel" {
  name = "ghost-ssm-tunnel-instance-profile"
  role = aws_iam_role.ssm_tunnel.name
}

module "ghost_test" {
  source = "./modules/ghost_site"

  providers = {
    aws = aws.test
  }

  environment                 = "test"
  route53_zone_name           = var.route53_zone_name
  subdomain                   = "test"
  aws_region                  = var.aws_region
  db_password                 = var.db_password
  ghost_image                 = var.ghost_image
  ssm_tunnel_instance_type    = var.ssm_tunnel_instance_type
  ssm_tunnel_instance_profile = aws_iam_instance_profile.ssm_tunnel.name
  local_dev_ip                = var.local_dev_ip
}

module "ghost_prod" {
  source = "./modules/ghost_site"

  environment                 = "prod"
  route53_zone_name           = var.route53_zone_name
  subdomain                   = "blog"
  aws_region                  = var.aws_region
  db_password                 = var.db_password
  ghost_image                 = var.ghost_image
  ssm_tunnel_instance_type    = var.ssm_tunnel_instance_type
  ssm_tunnel_instance_profile = aws_iam_instance_profile.ssm_tunnel.name
  local_dev_ip                = var.local_dev_ip
}
