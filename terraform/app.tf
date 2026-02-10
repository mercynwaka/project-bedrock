resource "helm_release" "retail_app" {
  name       = "retail-store-sample-app"
  repository = "oci://public.ecr.aws/aws-containers"
  chart      = "retail-store-sample-chart"
  version    = "0.8.5"
  namespace  = "retail-app"

  timeout = 900
  wait    = true

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
  # These 'extraEnv' blocks are the ONLY way to force the app out of in-memory mode
  set {
    name  = "catalog.extraEnv.DB_TYPE"
    value = "mysql"
  }
  set {
    name  = "catalog.extraEnv.DB_ENDPOINT"
    value = "${aws_db_instance.catalog_db.address}:3306"
  }
  set {
    name  = "catalog.extraEnv.DB_USER"
    value = "catalog"
  }
  set {
    name  = "catalog.extraEnv.DB_NAME"
    value = "catalogdb"
  }
  set {
    name  = "catalog.extraEnv.DB_PASSWORD"
    value = jsondecode(aws_secretsmanager_secret_version.catalog_db_secret_val.secret_string)["password"]
  }

  # --- 3. ORDERS: RDS POSTGRES CONNECTION ---
  set {
    name  = "orders.extraEnv.SPRING_DATASOURCE_URL"
    value = "jdbc:postgresql://${aws_db_instance.orders_db.address}:5432/ordersdb"
  }
  set {
    name  = "orders.extraEnv.SPRING_DATASOURCE_USERNAME"
    value = jsondecode(aws_secretsmanager_secret_version.orders_db_secret_val.secret_string)["username"]
  }
  set {
    name  = "orders.extraEnv.SPRING_DATASOURCE_PASSWORD"
    value = jsondecode(aws_secretsmanager_secret_version.orders_db_secret_val.secret_string)["password"]
  }

  # --- 4. RESOURCE LIMITS (Keep pods small) ---
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

  depends_on = [
    kubernetes_namespace.retail_app,
    module.eks,
    aws_db_instance.catalog_db,
    aws_db_instance.orders_db
  ]
}
