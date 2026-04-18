variable "res_prefix" {
  type        = string
  description = "Enter your prefix for resource naming rule"
}

variable "rg_name" {
  type        = string
  description = "Enter your resource group name"
}

variable "location" {
  type        = string
  description = "Enter a location to deploy your resources on Azure"
  default     = "Japan East"
}

variable "tags" {
  type        = map(any)
  description = "Enter tags for resources to deploy if necessary"
}

variable "my_ip" {
  type        = string
  description = "Enter your global IP address"
}

variable "vnet_address" {
  type        = string
  description = "Enter your VNET address space"
}

variable "subnet_address" {
  type        = string
  description = "Enter your subnet address space"
}

variable "vm_username" {
  type        = string
  description = "Enter an admin user name of VMs"
}

variable "vm_password" {
  type        = string
  description = "Enter an admin password of VMs"
  sensitive   = true
}

variable "client_hostname" {
  type        = string
  description = "Enter a client VM hostname"
}

variable "sql_hostname" {
  type        = string
  description = "Enter a hostname of Azure SQL Server"
}

variable "sql_username" {
  type        = string
  description = "Enter an admin user name of Azure SQL Server"
}

variable "sql_password" {
  type        = string
  description = "Enter an admin password of Azure SQL Server"
  sensitive   = true
}

variable "storage_account" {
  type        = string
  description = "Enter a name of Storage Account"
}

variable "redis_hostname" {
  type        = string
  description = "Enter a name of Azure Redis Cache"
}

variable "aks_fqdn" {
  type        = string
  description = "Enter a FQDN of AKS for Automation Suite"
}

variable "aks_subnet_address" {
  type        = string
  description = "Enter your AKS subnet address space"
}

variable "aks_dns_ip" {
  type        = string
  description = "Enter your AKS DNS IP address"
}

variable "aks_node_size" {
  type        = string
  description = "Enter your AKS Node size"
}

variable "kubernetes_version" {
  type        = string
  description = "Enter the Kubernetes version for AKS"
  default     = "1.34"
}

variable "number_of_cpu_nodes" {
  type        = number
  description = "Number of CPU nodes in the AKS default node pool"
  default     = 3
}

variable "number_of_asrobot_nodes" {
  type        = number
  description = "Number of dedicated AKS nodes for Automation Suite Serverless Robot"
  default     = 0
}

variable "enable_public_access" {
  type        = bool
  description = "Enable public access for AKS cluster (assigns a public IP to the load balancer)"
  default     = false
}

variable "aks_internal_lb_ip" {
  type        = string
  description = "Static private IP address for AKS Internal Load Balancer (required when enable_public_access = false)"
  default     = ""
}

variable "postgres_hostname" {
  type        = string
  description = "Enter a hostname of Azure Database for PostgreSQL Flexible Server"
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

variable "postgres_version" {
  type        = string
  description = "Enter the PostgreSQL engine version"
  default     = "16"
}

variable "postgres_storage_size" {
  type        = number
  description = "Enter the PostgreSQL storage size in GB"
  default     = 128
}

variable "postgres_sku" {
  type        = string
  description = "Enter the PostgreSQL SKU name"
  default     = "GP_Standard_D4ds_v5"
}

variable "postgres_db_name" {
  type        = list(string)
  description = "Enter the database names for PostgreSQL"
  default     = ["automationsuite_taas", "automationsuite_a4d"]
}

variable "postgres_subnet_address" {
  type        = string
  description = "Enter the subnet address space for PostgreSQL delegated subnet"
}
