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
