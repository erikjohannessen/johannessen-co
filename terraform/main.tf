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

data "aws_route53_zone" "primary" {
  name         = "${var.route53_zone_name}."
  private_zone = false
}

locals {
  ses_mail_from = var.ses_mail_from != "" ? var.ses_mail_from : "noreply@${var.route53_zone_name}"
}

resource "aws_ses_domain_identity" "ghost" {
  domain = var.route53_zone_name

  depends_on = [aws_iam_role_policy.github_actions]
}

resource "aws_route53_record" "ses_verification" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "_amazonses.${var.route53_zone_name}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.ghost.verification_token]
}

resource "aws_ses_domain_identity_verification" "ghost" {
  domain = aws_ses_domain_identity.ghost.id

  depends_on = [aws_route53_record.ses_verification]
}

resource "aws_ses_domain_dkim" "ghost" {
  domain = aws_ses_domain_identity.ghost.domain
}

resource "aws_route53_record" "ses_dkim" {
  count = 3

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${aws_ses_domain_dkim.ghost.dkim_tokens[count.index]}._domainkey.${var.route53_zone_name}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.ghost.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_ses_domain_mail_from" "ghost" {
  domain                 = aws_ses_domain_identity.ghost.domain
  mail_from_domain       = "mail.${var.route53_zone_name}"
  behavior_on_mx_failure = "UseDefaultValue"
}

resource "aws_route53_record" "ses_mail_from_mx" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = aws_ses_domain_mail_from.ghost.mail_from_domain
  type    = "MX"
  ttl     = 600
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

resource "aws_route53_record" "ses_mail_from_spf" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = aws_ses_domain_mail_from.ghost.mail_from_domain
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com -all"]
}

resource "aws_iam_user" "ghost_ses_smtp" {
  name = "ghost-ses-smtp-user"
}

resource "aws_iam_user_policy" "ghost_ses_smtp" {
  name = "ghost-ses-smtp-send-policy"
  user = aws_iam_user.ghost_ses_smtp.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ses:SendRawEmail"]
        Resource = [
          aws_ses_domain_identity.ghost.arn,
        ]
      }
    ]
  })
}

resource "aws_iam_access_key" "ghost_ses_smtp" {
  user = aws_iam_user.ghost_ses_smtp.name
}
