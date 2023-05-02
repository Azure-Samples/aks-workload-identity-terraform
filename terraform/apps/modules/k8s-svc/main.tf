resource "kubernetes_service_v1" "app_service" {
  metadata {
    name      = var.appname
    namespace = var.namespace
    labels = {
      app = var.appname
    }
  }
  spec {
    selector = {
      app = var.appname
    }
    port {
      name        = "endpoint"
      port        = var.container_port
      target_port = var.container_port
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }

}

resource "kubernetes_deployment_v1" "app_deployment" {
  metadata {
    name      = var.appname
    namespace = var.namespace
  }

  spec {
    selector {
      match_labels = {
        app = var.appname
      }
    }
    template {
      metadata {
        labels = {
          app = var.appname
        }
        namespace = var.namespace
      }
      spec {
        container {
          name              = var.appname
          image             = var.image
          image_pull_policy = "Always"

          port {
            name           = "endpoint"
            container_port = var.container_port
          }
          security_context {
            privileged = false
          }
          dynamic "env" {
            for_each = var.profile == null ? [] : [1]
            content {
              name  = "SPRING_PROFILES_ACTIVE"
              value = var.profile
            }
          }

          liveness_probe {
            http_get {
              path = "/actuator/health"
              port = var.container_port
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }
        }
      }

    }
  }

}
