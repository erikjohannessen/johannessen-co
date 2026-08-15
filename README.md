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
  - `ROUTE53_ZONE_NAME` (Route 53 hosted zone, e.g. `example.com`)
  - `GHOST_IMAGE` (Container image to use for Ghost, default `ghost:6-alpine`)
  - `TF_STATE_BUCKET` (S3 bucket for Terraform state)
  - `GHOST_EXPORTS_BUCKET` (optional, S3 bucket for Ghost export files used by manual import workflow)
  - `TF_STATE_KEY` (optional, default `ghost/terraform.tfstate`)
- GitHub repository secret (Settings → Secrets and variables → Actions → Secrets):
  - `DB_PASSWORD` (MySQL password used by both Ghost environments)
- GitHub environment secrets for each environment (`test` and `prod`):
  - `GHOST_ADMIN_API_KEY` (Ghost Admin API key for that environment's custom integration — see [Generating a Ghost Admin API key](#generating-a-ghost-admin-api-key))
- GitHub environment variables for each environment (`test` and `prod`):
  - `SUBDOMAIN` (The subdomain to deploy the Ghost site to for this environment, e.g. `blog` deploys to `blog.example.com`)

## GitHub Actions deployment

Workflow files:

- `.github/workflows/pull-request.yml`
- `.github/workflows/push.yml`
- `.github/workflows/manual-ghost-import.yml`

- Pull requests: `terraform fmt -check`, `terraform validate`, and `terraform plan` (plan requires `TF_STATE_BUCKET`)
- Push to `main`: `terraform apply -auto-approve` (requires `TF_STATE_BUCKET`)
- State is stored in S3 with S3-native locking (`use_lockfile=true`) to keep GitHub Actions deployments consistent across runs.
- Common Terraform now provisions SES (domain identity, DKIM, MAIL FROM, SMTP IAM credentials) once per account/region and injects SMTP settings into each Ghost environment at task startup.

## Manual Ghost Import from S3

Use the manual workflow to import an existing Ghost export JSON into `test` or `prod` for recovery or test environment refreshes.

Workflow:

- `.github/workflows/manual-ghost-import.yml`

How it works:

1. Trigger the workflow manually from GitHub Actions.
2. Provide:
  - `environment` (`test` or `prod`)
  - `s3_bucket` (bucket containing export file)
  - `s3_key` (object key, for example `backups/ghost_export.json`)
3. The workflow assumes your AWS role via OIDC, downloads the export JSON from S3, and runs:
  - `scripts/import-ghost-export.sh`
4. The script authenticates against the Ghost Admin API using a JWT signed with your Admin API key and imports tags, posts, and pages individually via their respective Admin API endpoints.

Notes:

- The GitHub Actions role must have at least `s3:GetObject` on the export bucket.
- If `GHOST_EXPORTS_BUCKET` is set, Terraform includes that bucket in the managed role policy.
- `skip_tls_verify` exists only for temporary troubleshooting and should normally remain `false`.
- `GHOST_ADMIN_API_KEY` must be configured as an environment-scoped secret (separately for `test` and `prod`) since each Ghost site has its own custom integration. The workflow fails if the secret is not set for the selected environment.

## Generating a Ghost Admin API key

The import script and workflow authenticate using a Ghost Admin API key, which is a credential tied to a custom integration rather than an interactive staff account. This avoids weakening staff login security.

### Steps

1. **Log in to Ghost Admin** for the target environment (e.g. `https://blog.example.com/ghost`).

2. **Open Settings → Integrations.**
   - In the left-hand sidebar, click **Settings**.
   - Under the **Advanced** section, click **Integrations**.

3. **Create a new custom integration.**
   - Click **+ Add custom integration**.
   - Enter a descriptive name (e.g. `GitHub Actions Import`) and click **Add**.

4. **Copy the Admin API key.**
   - On the integration detail page you'll see an **Admin API key** field containing a value in the format `<id>:<secret>` (e.g. `6745abc...def:a3b9...1f`).
   - Copy this value. The secret portion is shown only once; you can regenerate it from the same page if needed.

5. **Store the key as a GitHub environment secret.**
   - In your GitHub repository, go to **Settings → Environments → `test`** (or `prod`).
   - Under **Environment secrets**, click **Add secret**, name it `GHOST_ADMIN_API_KEY`, and paste the `id:secret` value.
   - Repeat for each environment, using the key from that environment's Ghost site.

> For more detail on creating and managing custom integrations in Ghost, see [Add a new custom integration](https://ghost.org/integrations/custom-integrations/#add-a-new-custom-integration).

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
- New AWS accounts begin in SES sandbox mode. While sandboxed, you can only send to verified recipient addresses until SES production access is granted. See [Request Production Access](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html) for more info.

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
