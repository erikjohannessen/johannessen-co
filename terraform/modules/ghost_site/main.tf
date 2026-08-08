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
  name_prefix        = "ghost-${var.environment}"
  domain_name        = "${var.subdomain}.${var.route53_zone_name}"
  default_subnet_ids = sort(data.aws_subnets.default.ids)
}

resource "aws_security_group" "ssm_tunnel" {
  name_prefix = "${local.name_prefix}-ssm-tunnel-"
  description = "SSM tunnel host security group for database access"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ssm_tunnel" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.ssm_tunnel_instance_type
  subnet_id                   = var.environment == "prod" && length(local.default_subnet_ids) > 1 ? local.default_subnet_ids[1] : local.default_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.ssm_tunnel.id]
  iam_instance_profile        = var.ssm_tunnel_instance_profile
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }
}

resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Ghost ALB security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${local.name_prefix}-ecs-"
  description = "Ghost ECS task security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 2368
    to_port         = 2368
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name_prefix = "${local.name_prefix}-db-"
  description = "MySQL security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "MySQL from Ghost tasks"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  ingress {
    description     = "MySQL from SSM Tunnel instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ssm_tunnel.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "ghost" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_db_instance" "ghost" {
  identifier_prefix           = "${local.name_prefix}-mysql"
  allocated_storage           = 20
  db_name                     = "ghost"
  engine                      = "mysql"
  engine_version              = "8.4"
  instance_class              = "db.t4g.micro"
  username                    = "ghostuser"
  password                    = var.db_password
  skip_final_snapshot         = true
  deletion_protection         = false
  backup_retention_period     = 7
  publicly_accessible         = true
  db_subnet_group_name        = aws_db_subnet_group.ghost.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  allow_major_version_upgrade = true
  apply_immediately           = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_cluster" "ghost" {
  name = "${local.name_prefix}-cluster"
}

resource "aws_cloudwatch_log_group" "ghost" {
  name              = "/ecs/${local.name_prefix}-ghost"
  retention_in_days = 14
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-task-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${local.name_prefix}-ecs-exec-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.ses_smtp_secret_arn]
      }
    ]
  })
}

resource "aws_lb" "ghost" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_route53_record" "ghost" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.ghost.dns_name
    zone_id                = aws_lb.ghost.zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "ghost" {
  domain_name       = local.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "ghost_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ghost.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.primary.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.value]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "ghost" {
  certificate_arn         = aws_acm_certificate.ghost.arn
  validation_record_fqdns = [for record in aws_route53_record.ghost_cert_validation : record.fqdn]
}

# Create the Apex Alias Record
resource "aws_route53_record" "apex_record" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = data.aws_route53_zone.primary.name
  type    = "A"

  # Only create an apex record alias for Production
  count = var.environment == "prod" ? 1 : 0

  alias {
    name                   = aws_route53_record.ghost.name
    zone_id                = aws_route53_record.ghost.zone_id
    evaluate_target_health = true
  }
}

resource "aws_lb_target_group" "ghost" {
  name        = "${local.name_prefix}-tg"
  port        = 2368
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ghost.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.ghost.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.ghost.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ghost.arn
  }
}

resource "aws_ecs_task_definition" "ghost" {
  family                   = "${local.name_prefix}-ghost"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "ghost"
      image     = var.ghost_image
      essential = true
      portMappings = [
        {
          containerPort = 2368
          hostPort      = 2368
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "url", value = "https://${local.domain_name}" },
        { name = "debug", value = "true" },
        { name = "database__client", value = "mysql" },
        { name = "database__connection__host", value = aws_db_instance.ghost.address },
        { name = "database__connection__user", value = "ghostuser" },
        { name = "database__connection__password", value = var.db_password },
        { name = "database__connection__database", value = "ghost" },
        { name = "mail__transport", value = "SMTP" },
        { name = "mail__from", value = var.ses_mail_from },
        { name = "mail__options__service", value = "SES" },
        { name = "mail__options__host", value = var.ses_smtp_host },
        { name = "mail__options__port", value = "465" },
        { name = "mail__options__secure", value = "true" },
        { name = "mail__options__auth__user", value = var.ses_smtp_username },
      ]
      secrets = [
        { name = "mail__options__auth__pass", valueFrom = var.ses_smtp_secret_arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ghost.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ghost"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "ghost" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.ghost.id
  task_definition = aws_ecs_task_definition.ghost.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ghost.arn
    container_name   = "ghost"
    container_port   = 2368
  }

  depends_on = [aws_lb_listener.https]
}
