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

variable "image" {
  description = "Container image of the application"
  type        = string
}

variable "profile" {
  description = "Spring profile"
  type        = string
  default     = null
}

variable "container_port" {
  description = "The port the container listens on"
  type        = number
}
