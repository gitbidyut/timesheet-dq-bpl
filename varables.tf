# variable "region" {
#   description = "AWS region"
#   type        = string
#   default     = "eu-west-1"
# }

############################
# General
############################

variable "env" {
  description = "Environment name (dev, qa, prod)"
  type        = string
  default     = "dev"
}

############################
# Alerts
############################
variable "alert_email" {
  description = "Email address to receive data quality alerts"
  type        = string
  default = "bidyut.pal@atos.net"
}

############################
# GitHub / Source
############################
# variable "github_owner" {
#   description = "GitHub organization or user"
#   type        = string
# }

variable "github_repo" {
  description = "bpl-timesheet-check"
  default = "bpl-timesheet-check"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to track"
  type        = string
  default     = "main"
}

# variable "github_token" {
#   description = "GitHub OAuth token"
#   type        = string
#   sensitive   = true
# }

############################
# Naming
############################
variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "timesheet-dq"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project prefix"
  type        = string
  default     = "bpl-training"
}

variable "artifact_bucket_name" {
  description = "S3 bucket name for CodePipeline artifacts (must be globally unique)"
  type        = string
  default     = "bpl-ml-artifacts-234" # set via -var or terraform.tfvars
}

variable "model_artifact_s3" {
  description = "S3 path to trained model"
  default= "s3://bpl-ml-artifacts-234/output/file-scanner-bpl/output/"
}

variable "sklearn_image_uri" {
  default = "683313688378.dkr.ecr.us-east-1.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3"
}
