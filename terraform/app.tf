resource "kubernetes_namespace" "retail_app" {
  metadata {
    name = "retail-app"
  }
  depends_on = [module.eks]
}

data "aws_secretsmanager_secret_version" "catalog_password" {
  secret_id = aws_secretsmanager_secret.catalog_secret.id
}
data "aws_secretsmanager_secret_version" "orders_password" {
  secret_id = aws_secretsmanager_secret.orders_db_secret.id
}

resource "helm_release" "retail_app" {
  name       = "retail-store-sample-app"
  repository = "oci://public.ecr.aws/aws-containers"
  chart      = "retail-store-sample-chart"
  version    = "0.8.5"
  namespace  = kubernetes_namespace.retail_app.metadata[0].name

  timeout = 900
  wait    = true

  set_sensitive {
    name  = "catalog.mysql.password"
    
    value = jsondecode(aws_secretsmanager_secret_version.catalog_secret_val.secret_string)["password"]
  }
  set {
    name  = "ui.frontend.title"
    value = "The most public Secret Shop"
  }

  set {
    name  = "ui.frontend.brand"
    value = "Secret"
  }
 
  
  # --- LABELS ---
  set {
    name  = "catalog.podLabels.app\\.kubernetes\\.io/owner"
    value = "retail-store-sample"
  }
  set {
    name  = "catalog.podLabels.app\\.kubernetes\\.io/name"
    value = "catalog"
  }
  set {
    name  = "catalog.podLabels.app\\.kubernetes\\.io/instance"
    value = "retail-store-sample-app"
  }
  set {
    name  = "catalog.podLabels.app\\.kubernetes\\.io/component"
    value = "service"
  }

  # --- 1. DISABLE IN-CLUSTER DATABASES ---
  set {
    name  = "catalog.mysql.enabled"
    value = "false"
  }
  set {
    name  = "orders.postgresql.enabled"
    value = "false"
  }

  # --- 2. CATALOG: RDS MYSQL CONNECTION ---
  set {
    name  = "catalog.database.type"
    value = "mysql"
  }
  set {
    name  = "catalog.mysql.host"
    value = aws_db_instance.catalog.address
  }
  set {
    name  = "catalog.mysql.port"
    value = "3306"
  }
  set {
    name  = "catalog.mysql.dbName"
    value = "catalog"
  }
  set {
    name  = "catalog.mysql.username"
    value = "catalog"
  }

  set {
    name  = "catalog.database.secretName"
    value = "catalog" 
  }

  # This tells the Helm chart to mount the CSI volume
  set {
    name  = "catalog.secrets.enabled"
    value = "true"
  }
  set {
    name  = "catalog.secrets.providerClass"
    value = "catalog-aws-provider"
  }
  set {
    name  = "catalog.mysql.password"
    value = jsondecode(data.aws_secretsmanager_secret_version.catalog_password.secret_string)["password"]
  }

  # --- SERVICE ACCOUNT (The Identity Bridge) ---
  set {
    name  = "catalog.serviceAccount.name"
    value = "retail-store-sample-app-catalog"
  }

  # --- 3. ORDERS: RDS POSTGRES CONNECTION ---
  set {
    name  = "orders.postgresql.host"
    value = aws_db_instance.orders_db.address
  }
  set {
    name  = "orders.postgresql.port"
    value = "5432"
  }
  set {
    name  = "orders.postgresql.dbName"
    value = "ordersdb"
  }
  set {
    name  = "orders.postgresql.username"
    value = "postgres"
  }
  set {
    name  = "orders.postgresql.password"
    value = jsondecode(data.aws_secretsmanager_secret_version.orders_password.secret_string)["password"]
  }

  # --- 4. RESOURCE LIMITS ---
  set {
    name  = "catalog.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "catalog.resources.requests.memory"
    value = "128Mi"
  }

  # --- 5. UI ENDPOINTS (Connect UI to Services) ---
  set {
    name  = "ui.app.endpoints.catalog"
    value = "http://retail-store-sample-app-catalog:80"
  }
  set {
    name  = "ui.app.endpoints.carts"
    value = "http://retail-store-sample-app-carts:80"
  }
  set {
    name  = "ui.app.endpoints.orders"
    value = "http://retail-store-sample-app-orders:80"
  }

  set {
    name  = "ui.endpoints.catalog"
    value = "http://retail-store-sample-app-catalog:80"
  }
  set {
    name  = "ui.service.type"
    value = "ClusterIP"
  }

  depends_on = [
    kubernetes_namespace.retail_app,
    module.eks,
    aws_db_instance.catalog,
    aws_db_instance.orders_db
  ]
}

# --- 6. ALB INGRESS ---
resource "kubernetes_ingress_v1" "retail_ui" {
  metadata {
    name      = "retail-ui-ingress"
    namespace = kubernetes_namespace.retail_app.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"  = "ip"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/"
      "alb.ingress.kubernetes.io/healthcheck-port" = "traffic-port"
      "alb.ingress.kubernetes.io/success-codes"    = "200-399"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "retail-store-sample-app-ui"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.retail_app]
}

