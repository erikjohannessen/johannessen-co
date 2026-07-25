data "aws_route53_zone" "primary" {
  name         = "${var.route53_zone_name}."
  private_zone = false
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  default_subnet_ids = sort(data.aws_subnets.default.ids)
  prod_subnet_id     = length(local.default_subnet_ids) > 1 ? local.default_subnet_ids[1] : local.default_subnet_ids[0]
}

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

resource "aws_security_group" "ssm_tunnel_test" {
  name_prefix = "ghost-test-ssm-tunnel-"
  description = "SSM tunnel host security group for test database access"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssm_tunnel_prod" {
  name_prefix = "ghost-prod-ssm-tunnel-"
  description = "SSM tunnel host security group for production database access"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ssm_tunnel_test" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.ssm_tunnel_instance_type
  subnet_id                   = local.default_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.ssm_tunnel_test.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_tunnel.name
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name        = "ghost-test-ssm-tunnel"
    Environment = "test"
    ManagedBy   = "terraform"
  }
}

resource "aws_instance" "ssm_tunnel_prod" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.ssm_tunnel_instance_type
  subnet_id                   = local.prod_subnet_id
  vpc_security_group_ids      = [aws_security_group.ssm_tunnel_prod.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_tunnel.name
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name        = "ghost-prod-ssm-tunnel"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

module "ghost_test" {
  source = "./modules/ghost_site"

  name_prefix                  = "ghost-test"
  domain_name                  = "test.johannessen.co"
  route53_zone_id              = data.aws_route53_zone.primary.zone_id
  aws_region                   = var.aws_region
  db_password                  = var.db_password
  ghost_image                  = var.ghost_image
  local_dev_ip                 = var.local_dev_ip
  db_client_security_group_ids = [aws_security_group.ssm_tunnel_test.id]
}

module "ghost_prod" {
  source = "./modules/ghost_site"

  name_prefix                  = "ghost-prod"
  domain_name                  = "blog.johannessen.co"
  route53_zone_id              = data.aws_route53_zone.primary.zone_id
  aws_region                   = var.aws_region
  db_password                  = var.db_password
  ghost_image                  = var.ghost_image
  local_dev_ip                 = var.local_dev_ip
  db_client_security_group_ids = [aws_security_group.ssm_tunnel_prod.id]
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
