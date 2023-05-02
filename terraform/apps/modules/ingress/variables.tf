variable "namespace" {
    description = "Namespace to deploy the ingress controller"
    type        = string  
}

variable "ingress_routes" {
    description = "List of ingress routes"
    type        = list(object({
        name = string
        path = string
        service = string
        port = number
    }))
}