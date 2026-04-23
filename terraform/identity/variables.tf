variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "ghcr_image" {
  type        = string
  description = "GHCR image for the Identity API (e.g. ghcr.io/your-org/identity:latest)"
}

variable "ballot_ghcr_image" {
  type        = string
  description = "GHCR image for the Ballot API (e.g. ghcr.io/your-org/ballot:latest)"
}

variable "vote_ghcr_image" {
  type        = string
  description = "GHCR image for the Vote API (e.g. ghcr.io/your-org/vote:latest)"
}

variable "vote_fe_ghcr_image" {
  type        = string
  description = "GHCR image for vote-fe — must be built with NEXT_PUBLIC_BACKEND_URL set (e.g. ghcr.io/your-org/vote-fe:latest)"
}

variable "seed_user_password" {
  type        = string
  description = "Password for seeded test users — only applied when environment = dev"
  default     = "Test1234!"
  sensitive   = true
}

variable "frontend_url" {
  type        = string
  description = "Public URL of the app (e.g. Cloudflare subdomain CNAME'd to the ALB) — used as the allowed CORS origin for all backend services"
}

# ── Inputs from the network stack ───────────────────────────────────────────
variable "ecs_cluster_arn" {
  type        = string
  description = "ARN of the shared ECS cluster (from network stack output)"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for the ECS service (from network stack output)"
}

variable "alb_target_group_arn" {
  type        = string
  description = "ARN of the ALB target group (from network stack output)"
}

variable "identity_security_group_id" {
  type        = string
  description = "Security group ID for the ECS task (from network stack output)"
}
