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

variable "acr_id" {
  type        = string
  description = "value of the Azure Container Registry resource id"
}

variable "aks_rbac_admin_group_object_id" {
  type        = string
  description = "value of the Azure Kubernetes Service administrators group object id in Azure Active Directory"
}

variable "dns_prefix" {
  type        = string
  description = "value of the DNS prefix specified when creating the managed cluster"
}
