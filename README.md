# Ghost on AWS with Terraform

This repository provisions two Ghost environments on AWS, a Test site and a Production site.

Both environments are managed with Terraform and deployed through GitHub Actions.

Both sites are deployed on different subdomains within the same domain.

## What gets created

For each environment:

- ECS Fargate service running Ghost
- Application Load Balancer (ALB)
- ACM certificate validated via Route53 DNS
- RDS MySQL database
- Dedicated EC2 SSM tunnel host for private DB access
- Security groups and networking in your default VPC
- Route53 `A` record
- IAM roles for ECS task execution

## Prerequisites

- AWS account with Route53 hosted zone
- Terraform >= 1.10
- AWS CLI v2 with Session Manager plugin installed locally
- GitHub repository variables (Settings → Secrets and variables → Actions → Variables):
  - `AWS_ACCOUNT_ID` (Account ID for AWS to deploy resources to, e.g. `123456789012`)
  - `AWS_ROLE_NAME` (Role Name to assume for deployment via GitHub Actions, e.g. `GitHubActionsRole`)
  - `AWS_REGION` (e.g. `us-east-1`)
  - `ROUTE53_ZONE_NAME` (Route 53 hosted zone, e.g. `abcdef.com`)
  - `GHOST_IMAGE` (Container image to use for Ghost, default `ghost:6-alpine`)
  - `TF_STATE_BUCKET` (S3 bucket for Terraform state)
  - `TF_STATE_KEY` (optional, default `ghost/terraform.tfstate`)
- GitHub repository secret (Settings → Secrets and variables → Actions → Secrets):
  - `DB_PASSWORD` (MySQL password used by both Ghost environments)
- GitHub environment variables for each environment (`test` and `prod`):
  - `SUBDOMAIN` (The subdomain to deploy the Ghost site to for this environment, e.g. `blog` deploys to `blog.abcdef.com`)

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

## GitHub Actions Role Permissions

The AWS role assumed by GitHub Actions must be able to create and manage ECS, ALB, ACM, RDS, Route53, IAM roles for task execution, CloudWatch logs, and Terraform state in S3.

Minimum service-level actions to include:

- `ecs:*`
- `elasticloadbalancing:*`
- `acm:*`
- `ec2:*` (required for security groups, subnets/VPC discovery, ENIs for Fargate, and load balancer networking)
- `rds:*`
- `route53:*`
- `logs:*`
- `iam:CreateRole`
- `iam:DeleteRole`
- `iam:GetRole`
- `iam:PassRole`
- `iam:AttachRolePolicy`
- `iam:DetachRolePolicy`
- `iam:TagRole`
- `iam:UntagRole`
- `iam:CreateServiceLinkedRole`
- `s3:ListBucket`
- `s3:GetObject`
- `s3:PutObject`
- `s3:DeleteObject`

If your state bucket uses a customer-managed KMS key, also include:

- `kms:Decrypt`
- `kms:Encrypt`
- `kms:GenerateDataKey`
- `kms:DescribeKey`

## Notes

- Ghost is configured with `https://<domain>` and ALB redirects HTTP to HTTPS.

## Connect to RDS via SSM

The stack now creates one SSM tunnel instance per environment and allows MySQL access to each RDS instance only from its matching tunnel host security group.

Fetch required outputs:

```bash
cd terraform
TEST_TUNNEL_ID=$(terraform output -raw test_ssm_tunnel_instance_id)
TEST_DB_ENDPOINT=$(terraform output -raw test_db_endpoint)
PROD_TUNNEL_ID=$(terraform output -raw prod_ssm_tunnel_instance_id)
PROD_DB_ENDPOINT=$(terraform output -raw prod_db_endpoint)
```

Start a local tunnel to test:

```bash
aws ssm start-session \
  --target "$TEST_TUNNEL_ID" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["'"$TEST_DB_ENDPOINT"'"],"portNumber":["3306"],"localPortNumber":["13306"]}'
```

In another terminal, connect your MySQL client to `127.0.0.1:13306` using the existing database credentials.
