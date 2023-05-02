terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
  }
}

resource "helm_release" "nginx_ingress" {
  name = "ingress-nginx"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
  # set {
  #   name  = "controller.service.annotations.\"service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path\""
  #   value = "/healthz"
  # }
  namespace        = var.namespace
  create_namespace = true
}

# resource "kubernetes_service" "ingress_service" {
#   metadata {
#     name      = "nginx-ingress-controller"
#     namespace = var.namespace
#   }

#   spec {

#     port {
#       name = "http"
#       port = 80
#       target_port = 80
#     }

#     type = "NodePort"
#   }

#   depends_on = [
#     helm_release.nginx_ingress
#   ]

# }

# resource "kubernetes_ingress_v1" "service_routes" {
#   count = length(var.ingress_routes)
#   wait_for_load_balancer = true
#   metadata {
#     name =  var.ingress_routes[count.index].name
#     annotations = {
#       "kubernetes.io/ingress.class" = "nginx"
#     }
#   }
#   spec {
#     rule {
#       http {
#         path {
#           path = var.ingress_routes[count.index].path
#           backend {
#             service_name = var.ingress_routes[count.index].name
#             service_port = var.ingress_routes[count.index].port
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_ingress_class" "nginx_ingress" {
#   metadata {
#     name = "nginx"
#   }

#   spec {
#     controller = "example.com/ingress-controller"
#     parameters {
#       api_group = "k8s.example.com"
#       kind      = "IngressParameters"
#       name      = "external-lb"
#     }
#   }
# }

resource "kubernetes_ingress_v1" "ingress_routes" {
  count = length(var.ingress_routes)
  metadata {
    name      = var.ingress_routes[count.index].name
    namespace = var.namespace
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect" : "false"
      "nginx.ingress.kubernetes.io/use-regex" : "true"
      "nginx.ingress.kubernetes.io/rewrite-target" : "/$2"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          path = var.ingress_routes[count.index].path
          backend {
            service {
              name = var.ingress_routes[count.index].service
              port {
                number = var.ingress_routes[count.index].port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.nginx_ingress
  ]

}
