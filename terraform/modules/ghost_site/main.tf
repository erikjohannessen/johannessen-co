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
}

resource "random_password" "db_password" {
  length  = 24
  special = false
}

resource "aws_security_group" "ghost" {
  name_prefix = "${var.name_prefix}-ghost-"
  description = "Ghost web security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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

resource "aws_security_group" "db" {
  name_prefix = "${var.name_prefix}-db-"
  description = "MySQL security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "MySQL from Ghost host"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ghost.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "ghost" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_db_instance" "ghost" {
  identifier              = "${var.name_prefix}-mysql"
  allocated_storage       = 20
  db_name                 = "ghost"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t4g.micro"
  username                = "ghostuser"
  password                = random_password.db_password.result
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 7
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.ghost.name
  vpc_security_group_ids  = [aws_security_group.db.id]
}

resource "aws_iam_role" "ssm" {
  name = "${var.name_prefix}-ssm-role"

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

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name_prefix}-ssm-profile"
  role = aws_iam_role.ssm.name
}

locals {
  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail

    dnf update -y
    dnf install -y docker docker-compose-plugin
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    mkdir -p /opt/ghost
    cat > /opt/ghost/nginx.conf <<'NGINXCONF'
    server {
        listen 80;

        location /health {
            access_log off;
            proxy_pass http://ghost:2368/;
            proxy_connect_timeout 5s;
            proxy_read_timeout 10s;
            proxy_intercept_errors on;
            error_page 301 302 303 307 308 = @ghost_healthy;
            error_page 502 503 504 = @ghost_down;
        }

        location @ghost_healthy {
            default_type text/plain;
            return 200 "Ghost is healthy\n";
        }

        location @ghost_down {
            default_type text/plain;
            return 503 "Ghost is not available\n";
        }

        location / {
            proxy_pass http://ghost:2368;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
    NGINXCONF

    cat > /opt/ghost/docker-compose.yml <<'COMPOSE'
    services:
      ghost:
        image: ghost:5-alpine
        restart: always
        environment:
          url: http://${var.domain_name}
          database__client: mysql
          database__connection__host: ${aws_db_instance.ghost.address}
          database__connection__user: ghostuser
          database__connection__password: ${random_password.db_password.result}
          database__connection__database: ghost
      nginx:
        image: nginx:alpine
        restart: always
        ports:
          - "80:80"
        volumes:
          - /opt/ghost/nginx.conf:/etc/nginx/conf.d/default.conf:ro
        depends_on:
          - ghost
    COMPOSE

    /usr/bin/docker compose -f /opt/ghost/docker-compose.yml up -d
  EOT
}

resource "aws_instance" "ghost" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.ghost.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  user_data              = local.user_data

  tags = {
    Name = "${var.name_prefix}-ec2"
  }
}

resource "aws_eip" "ghost" {
  domain   = "vpc"
  instance = aws_instance.ghost.id
}
