variable "application_name" {
  type        = string
  description = "The name of your application"
  default     = "demo-6256-6791"
}

variable "resource_group" {
  type        = string
  description = "The resource group"
}

variable "environment" {
  type        = string
  description = "The environment (dev, test, prod...)"
  default     = ""
}

variable "location" {
  type        = string
  description = "The Azure region where all resources in this example should be created"
  default     = "eastus"
}

variable "apps" {
  type        = list(string)
  description = "List of applications to deploy"
  default = [
    "spring-petclinic-customers-service",
    "spring-petclinic-vets-service",
    "spring-petclinic-visits-service"
  ]
}

variable "cloud_services" {
  type        = list(string)
  description = "List of Spring Cloud Services to deploy"
  default     = []
}

variable "apps_namespace" {
  type    = string
  default = "spring-petclinic"
}

variable "cluster_name" {
  description = "The name of the AKS cluster."
}

variable "database_url" {
  description = "The JDBC URL to connect to the MySQL database"
}

variable "database_server_fqdn" {
  description = "The FQDN of the MySQL server"
}

variable "database_server_name" {
  description = "The host name of the MySQL server"
}

variable "database_name" {
  description = "The name of the MySQL database"
}

variable "registry_url" {
  description = "The URL of the container registry"
}

variable "apps_version" {
  description = "value of the tag to use for the images"
  default     = "latest"
}

variable "profile" {
  description = "Spring profile"
  type        = string
  default     = "k8s"
}


variable "container_port" {
  description = "The default port the container listens on"
  type        = number
  default     = 8080
}
