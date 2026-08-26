variable "aws_region" {
  description = "AWS region for the EKS project"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "portfolio-eks"
}

variable "cluster_admin_principal_arn" {
  description = "IAM principal allowed to administer the EKS cluster"
  type        = string
  sensitive   = true
}

variable "cluster_public_access_cidr" {
  description = "CIDR allowed to access the public EKS API endpoint"
  type        = string
  sensitive   = true
}