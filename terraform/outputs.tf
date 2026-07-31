output "ssm_tunnel_instance_profile" {
  description = "IAM instance profile for SSM tunnels."
  value       = aws_iam_instance_profile.ssm_tunnel.name
}
