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