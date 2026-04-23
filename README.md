# e-voting infra

AWS infrastructure for the e-voting platform, defined in Terraform. All five containers run inside a **single ECS Fargate task** behind an Application Load Balancer. nginx handles routing, auth, and rate limiting; containers communicate via localhost.

> **Lab environment constraints:** IAM role creation is restricted — all containers share the pre-created `LabRole`. Service Discovery is unavailable, which is why all services are colocated in one task instead of using Service Connect.

## Architecture

```
Internet
   │
   ▼
Application Load Balancer  (port 80)
   │
   ▼
┌─────────────────────────────────────────────────────┐
│  Single ECS Fargate task                            │
│                                                     │
│  ┌─────────┐   auth_request   ┌──────────────────┐  │
│  │  nginx  │ ───────────────▶ │  Identity API    │  │
│  │  :8080  │                  │  localhost:8081  │  │
│  └────┬────┘                  └──────────────────┘  │
│       │                                             │
│       ├─ /api/auth/*      ──▶ localhost:8081        │
│       ├─ /api/ballots     ──▶ localhost:8082        │
│       ├─ /api/votes       ──▶ localhost:8083        │
│       ├─ /api/votes/verify──▶ localhost:8083        │
│       └─ /*               ──▶ localhost:3000        │
│                                                     │
│  ┌──────────────┐  ┌──────────┐  ┌─────────────┐    │
│  │  Ballot API  │  │ Vote API │  │   vote-fe   │    │
│  │  :8082       │  │ :8083    │  │   :3000     │    │
│  └──────────────┘  └──────────┘  └─────────────┘    │
└─────────────────────────────────────────────────────┘
```

**How auth works:** Every request (except `/api/auth/*`, `/login`, `/_next/*`, and `/api/votes/verify`) triggers an nginx `auth_request` to Identity's `GET /api/auth/validate`. Identity calls Cognito `GetUser` with the access token, returns `X-Voter-Id` and `X-Voter-Role` headers, and nginx forwards them to the proxied service. A missing or invalid token returns 401 (API routes) or 302 to `/login` (frontend routes).

## Repository layout

```
infra/
├── nginx/
│   ├── Dockerfile      # FROM nginx:1.27-alpine
│   ├── limits.conf     # Rate limit zone (10 req/min for /api/votes/verify)
│   └── nginx.conf      # auth_request routing, rate limiting, proxies to localhost ports
└── terraform/
    ├── network/        # VPC, ALB, ECS cluster, security groups
    ├── vote/           # DynamoDB (evoting-votes + evoting-audit tables)
    └── identity/       # Cognito, DynamoDB (identity-users), ECR (nginx), ECS task + service
```

**Deploy order: network → vote → identity**

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.7
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- Docker (with `linux/amd64` build support)

---

## Local deployment

### Step 1 — Configure AWS credentials

In the lab console click **AWS Details → Show** next to AWS CLI, then:

```bash
aws configure set aws_access_key_id     <your-key-id>
aws configure set aws_secret_access_key <your-secret>
aws configure set aws_session_token     <your-session-token>
aws configure set region                us-east-1
```

> Lab credentials expire after a few hours. Re-run these commands and continue from where you left off.

---

### Step 2 — Deploy the network stack

```bash
cd terraform/network
terraform init
terraform apply
```

Note the outputs — you need them for the identity stack:

```bash
terraform output alb_dns_name               # public URL — use as frontend_url
terraform output ecs_cluster_arn
terraform output alb_target_group_arn
terraform output public_subnet_ids
terraform output identity_security_group_id
```

---

### Step 3 — Deploy the vote stack (DynamoDB tables)

```bash
cd ../vote
terraform init
terraform apply
```

---

### Step 4 — Deploy the identity stack

Copy and fill in the tfvars:

```bash
cd ../identity
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region         = "us-east-1"
environment        = "dev"
seed_user_password = "Test1234!"

# Public URL of the app — used as the CORS allowed origin for all services.
# Use the ALB DNS name from Step 2 (or your Cloudflare subdomain if configured).
frontend_url = "http://<alb_dns_name>"

# GHCR images — built and pushed by GitHub Actions on push to main
ghcr_image         = "ghcr.io/<org>/identity:latest"
ballot_ghcr_image  = "ghcr.io/<org>/ballot:latest"
vote_ghcr_image    = "ghcr.io/<org>/vote:latest"
vote_fe_ghcr_image = "ghcr.io/<org>/vote-fe:latest"

# From Step 2 outputs
ecs_cluster_arn            = "arn:aws:ecs:us-east-1:..."
subnet_ids                 = ["subnet-...", "subnet-..."]
alb_target_group_arn       = "arn:aws:elasticloadbalancing:..."
identity_security_group_id = "sg-..."
```

Create the nginx ECR repo first, then push the image:

```bash
terraform init
terraform apply \
  -target=aws_ecr_repository.nginx \
  -target=aws_ecr_lifecycle_policy.nginx
```

```bash
cd ../..

NGINX_ECR_URL=$(cd terraform/identity && terraform output -raw nginx_ecr_repository_url)
ECR_REGISTRY="${NGINX_ECR_URL%%/*}"

aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker build --platform linux/amd64 -t "${NGINX_ECR_URL}:latest" nginx/
docker push "${NGINX_ECR_URL}:latest"
```

Apply the rest of the identity stack:

```bash
cd terraform/identity
terraform apply
```

---

### Step 5 — (Optional) Point a custom domain to the ALB

Create a CNAME in your DNS provider:

```
Type:    CNAME
Name:    app
Content: <alb_dns_name>
```

---

### Step 6 — Verify

```bash
ALB=$(cd terraform/network && terraform output -raw alb_dns_name)

curl $ALB/health           # → ok
curl $ALB/api/ballots      # → 401 {"error":"Unauthorized",...}
curl $ALB/                 # → redirects to /login
```

---

## DynamoDB tables

| Table            | Stack    | Hash key     | Range key   | Notes                                                        |
|------------------|----------|--------------|-------------|--------------------------------------------------------------|
| `identity-users` | identity | `pk` (email) | —           | Tracks login history                                         |
| `evoting-votes`  | vote     | `electionId` | `voterHash` | `voterHash` = SHA-256 of voter ID — prevents duplicate votes |
| `evoting-audit`  | vote     | `electionId` | `version`   | Append-only ledger; GSI on `receiptId` for vote verification |

> **Seed users:** `terraform apply` on the identity stack seeds test users into both Cognito and DynamoDB. Both records are required for login to succeed.

## Teardown

```bash
cd terraform/identity && terraform destroy
cd ../vote                  && terraform destroy
cd ../network               && terraform destroy
```
