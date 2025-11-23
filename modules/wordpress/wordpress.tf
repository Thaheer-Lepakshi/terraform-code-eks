resource "helm_release" "wordpress" {
  name       = "wordpress"
  namespace  = "wordpress"
  create_namespace = true

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "wordpress"
  version    = "22.1.1"

  values = [
    yamlencode({
      wordpressUsername = "admin"
      wordpressPassword = "admin123"
      wordpressEmail    = "admin@example.com"
      wordpressBlogName = "My Blog"

      replicaCount = 1

      mariadb = {
        enabled = true
        auth = {
          rootPassword = "root123"
          database     = "wordpress"
          username     = "wpuser"
          password     = "wpuser123"
        }
      }

      persistence = {
        enabled      = true
        storageClass = "gp3"
        size         = "10Gi"
        accessModes  = ["ReadWriteOnce"]
      }

      service = {
        type = "ClusterIP"
        port = 80
      }

      ingress = {
        enabled           = true
        ingressClassName  = "alb"

        annotations = {
          "kubernetes.io/ingress.class"               = "alb"
          "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"     = "ip"
          "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\":80}]"
          "alb.ingress.kubernetes.io/healthcheck-path" = "/"
        }

        hosts = [
          {
            name = "wordpress.local"
            path = "/"
            pathType = "Prefix"
          }
        ]

        # IMPORTANT: Bitnami expects boolean, NOT array
        tls = false
      }
    })
  ]
}
