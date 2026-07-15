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
  password                = var.db_password
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
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    nginx_conf     = file("${path.module}/templates/nginx.conf")
    healthcheck_js = file("${path.module}/templates/healthcheck.js")
    db_address     = aws_db_instance.ghost.address
    compose_content = templatefile("${path.module}/templates/docker-compose.yml.tftpl", {
      domain_name = var.domain_name
      db_address  = aws_db_instance.ghost.address
      db_password = var.db_password
    })
  })
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

  lifecycle {
    # Prevent unexpected instance replacement when Amazon publishes a new AMI.
    # To upgrade the AMI, remove this ignore rule, apply, then re-add it.
    ignore_changes = [ami]
    # Create a replacement instance before destroying the old one to minimise
    # the downtime window during intentional instance replacements.
    create_before_destroy = true
  }
}

resource "aws_eip" "ghost" {
  domain   = "vpc"
  instance = aws_instance.ghost.id
}
