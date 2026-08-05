output "ssm_tunnel_instance_profile" {
  description = "IAM instance profile for SSM tunnels."
  value       = aws_iam_instance_profile.ssm_tunnel.name
}

output "ses_smtp_username" {
  description = "SMTP username for Ghost mail through SES."
  value       = aws_iam_access_key.ghost_ses_smtp.id
}

output "ses_smtp_password" {
  description = "SMTP password for Ghost mail through SES."
  value       = aws_iam_access_key.ghost_ses_smtp.ses_smtp_password_v4
  sensitive   = true
}

output "ses_smtp_host" {
  description = "SES SMTP host for the configured AWS region."
  value       = "email-smtp.${var.aws_region}.amazonaws.com"
}

output "ses_mail_from" {
  description = "Default From address configured for Ghost mail."
  value       = local.ses_mail_from
}
