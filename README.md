# Ghost on AWS with Terraform

This repository provisions two Ghost environments on AWS:

- Test: `test.johannessen.co`
- Production: `blog.johannessen.co`

Both environments are managed with Terraform and deployed through GitHub Actions.

## What gets created

For each environment:

- EC2 instance (Amazon Linux 2023) running Ghost in Docker
- RDS MySQL database
- Security groups and networking in your default VPC
- Elastic IP for stable DNS
- Route53 `A` record
- IAM role/profile for AWS Systems Manager access

## Prerequisites

- AWS account with Route53 hosted zone for `johannessen.co`
- Terraform >= 1.6
- GitHub repository variables (Settings → Secrets and variables → Actions → Variables):
  - `AWS_ROLE_ARN` (OIDC assumable role ARN for GitHub Actions, e.g. `arn:aws:iam::123456789012:role/GitHubActionsRole`)
  - `AWS_REGION` (for example `us-east-1`)
  - `TF_STATE_BUCKET` (S3 bucket for Terraform state)
  - `TF_STATE_DYNAMODB_TABLE` (DynamoDB lock table)
  - `TF_STATE_KEY` (optional, default `ghost/terraform.tfstate`)

## Local usage

```bash
cd terraform
terraform init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="dynamodb_table=<lock-table>" \
  -backend-config="key=ghost/terraform.tfstate" \
  -backend-config="region=us-east-1"
terraform plan
terraform apply
```

Optional overrides:

```bash
terraform apply \
  -var="aws_region=us-east-1" \
  -var="route53_zone_name=johannessen.co"
```

## GitHub Actions deployment

Workflow file: `.github/workflows/terraform.yml`

- Pull requests: `terraform fmt -check`, `terraform validate`, and `terraform plan`
- Push to `main`: `terraform apply -auto-approve`
- State is stored in S3 with DynamoDB locking to keep GitHub Actions deployments consistent across runs.

## Notes

- Ghost is configured with `http://<domain>` by default in this stack.
- Add TLS (for example with CloudFront/ALB + ACM or reverse proxy) if you want HTTPS end-to-end at infrastructure level.
