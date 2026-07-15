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
- Terraform >= 1.10
- GitHub repository variables (Settings → Secrets and variables → Actions → Variables):
  - `AWS_ROLE_ARN` (OIDC assumable role ARN for GitHub Actions, e.g. `arn:aws:iam::123456789012:role/GitHubActionsRole`)
  - `AWS_REGION` (for example `us-east-1`)
  - `TF_STATE_BUCKET` (S3 bucket for Terraform state; plan and apply are skipped when unset)
  - `TF_STATE_KEY` (optional, default `ghost/terraform.tfstate`)
- GitHub repository secret (Settings → Secrets and variables → Actions → Secrets):
  - `DB_PASSWORD` (MySQL password used by both Ghost environments)

## Local usage

```bash
cd terraform
terraform init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="use_lockfile=true" \
  -backend-config="key=ghost/terraform.tfstate" \
  -backend-config="region=us-east-1"
export TF_VAR_db_password="<db-password>"
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

Workflow files:

- `.github/workflows/pull-request.yml`
- `.github/workflows/push.yml`

- Pull requests: `terraform fmt -check`, `terraform validate`, and `terraform plan` (plan requires `TF_STATE_BUCKET`)
- Push to `main`: `terraform apply -auto-approve` (requires `TF_STATE_BUCKET`)
- State is stored in S3 with S3-native locking (`use_lockfile=true`) to keep GitHub Actions deployments consistent across runs.

## Notes

- Ghost is configured with `http://<domain>` by default in this stack.
- Add TLS (for example with CloudFront/ALB + ACM or reverse proxy) if you want HTTPS end-to-end at infrastructure level.
