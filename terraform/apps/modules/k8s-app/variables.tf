variable "resource_group" {
  type        = string
  description = "The resource group"
}

variable "application_name" {
  type        = string
  description = "The name of your application"
}

variable "environment" {
  type        = string
  description = "The environment (dev, test, prod...)"
  default     = "dev"
}

variable "location" {
  type        = string
  description = "The Azure region where all resources in this example should be created"
}

variable "appname" {
  description = "Name of the application"
  type        = string
}

variable "namespace" {
  description = "Namespace of the application"
  type        = string
}

variable "aks_oidc_issuer_url" {
  description = "The issuer URL for the AKS cluster"
  type        = string
}

variable "image" {
  description = "The image to deploy"
  type        = string
}

variable "database_url" {
  description = "The database URL"
  type        = string
}

variable "database_server_name" {
  description = "The database server hostname"
  type        = string
}
variable "database_server_fqdn" {
  description = "The database FQDN"
  type        = string
}

variable "database_name" {
  description = "The database name"
  type        = string
}

variable "profile" {
  description = "Spring profile"
  type        = string
}

variable "container_port" {
  description = "The port the container listens on"
  type        = number
}

variable "env_vars" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}

variable "health_check_path" {
  description = "The path to use for health checks"
  type        = string
  default     = "/actuator/health"
}
