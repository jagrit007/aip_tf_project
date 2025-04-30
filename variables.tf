variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "prefect_api_key" {
  description = "Prefect Cloud API key"
  type        = string
  sensitive   = true
}

variable "prefect_account_id" {
  description = "Prefect Cloud account ID"
  type        = string
}

variable "prefect_workspace_id" {
  description = "Prefect Cloud workspace ID"
  type        = string
}