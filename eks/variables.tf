variable "res_prefix" {
  type        = string
  description = "Enter your prefix for resource naming rule"
}

variable "region" {
  type        = string
  description = "Enter the AWS region"
  default     = "ap-northeast-1"
}

variable "availability_zones" {
  type        = list(string)
  description = "Enter the availability zones"
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "tags" {
  type        = map(any)
  description = "Enter tags for resources to deploy if necessary"
}

variable "vpc_address" {
  type        = string
  description = "Enter your VPC address space"
}

variable "my_ip" {
  type        = string
  description = "Enter your global IP address"
}

variable "enable_public_access" {
  type        = bool
  description = "Enable public access for EKS cluster"
  default     = false
}

variable "db_instance_type" {
  type        = string
  description = "Enter the DB instance type for SQL Server"
  default     = "db.m6i.2xlarge"
}

variable "sql_username" {
  type        = string
  description = "Enter an admin user name of SQL Server"
}

variable "sql_password" {
  type        = string
  description = "Enter an admin password of SQL Server"
  sensitive   = true
}

variable "redis_password" {
  type        = string
  description = "Enter a password for Redis"
  sensitive   = true
}

variable "eks_fqdn" {
  type        = string
  description = "Enter a FQDN for Automation Suite on EKS"
}

variable "cpu_instance_type" {
  type        = string
  description = "Enter the EC2 instance type for CPU node group"
  default     = "c7a.8xlarge"
}

variable "number_of_cpu_nodes" {
  type        = number
  description = "Number of CPU nodes in the EKS cluster"
  default     = 3
}

variable "asrobot_instance_type" {
  type        = string
  description = "Enter the EC2 instance type for AS Robot node group"
  default     = "c7a.4xlarge"
}

variable "number_of_asrobot_nodes" {
  type        = number
  description = "Number of dedicated EKS nodes for Automation Suite Serverless Robot"
  default     = 0
}

variable "gpu_instance_type" {
  type        = string
  description = "Enter the EC2 instance type for GPU node group"
  default     = "g4dn.xlarge"
}

variable "number_of_gpu_nodes" {
  type        = number
  description = "Number of GPU nodes in the EKS cluster"
  default     = 0
}

variable "kubernetes_version" {
  type        = string
  description = "Enter the Kubernetes version for EKS"
  default     = "1.34"
}

variable "s3_bucket_name" {
  type        = string
  description = "Enter the S3 bucket name pattern for EKS worker nodes"
}

variable "postgres_instance_type" {
  type        = string
  description = "Enter the DB instance type for PostgreSQL"
  default     = "db.m6i.xlarge"
}

variable "postgres_engine_version" {
  type        = string
  description = "Enter the PostgreSQL engine version"
  default     = "16.8"
}

variable "postgres_username" {
  type        = string
  description = "Enter an admin user name of PostgreSQL"
}

variable "postgres_password" {
  type        = string
  description = "Enter an admin password of PostgreSQL"
  sensitive   = true
}

variable "postgres_port" {
  type        = number
  description = "Enter the PostgreSQL port"
  default     = 5432
}

variable "postgres_storage_size" {
  type        = number
  description = "Enter the PostgreSQL storage size in GB"
  default     = 100
}

variable "postgres_max_storage" {
  type        = number
  description = "Enter the PostgreSQL max storage size in GB"
  default     = 500
}

variable "postgres_db_name" {
  type        = list(string)
  description = "Enter the database names for PostgreSQL"
  default     = ["automationsuite_taas", "automationsuite_a4d"]
}
