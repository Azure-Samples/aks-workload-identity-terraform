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
  namespace        = var.namespace
  create_namespace = true
}

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
