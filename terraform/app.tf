resource "kubernetes_namespace" "retail_app" {
  metadata {
    name = "retail-app"
  }
  depends_on = [module.eks]
}

# We use the Parent Chart because it automatically wires the UI to the Catalog/Cart.
resource "helm_release" "retail_app" {
  name       = "retail-store-sample-app"
  repository = "oci://public.ecr.aws/aws-containers"
  chart      = "retail-store-sample-app"
  version    = "0.5.0" # This version bundles the compatible UI
  namespace  = "retail-app"


  # --- Disable In-Cluster DBs ---
  set {
    name  = "catalog.mysql.local"
    value = "false"
  }
  set {
    name  = "orders.postgresql.local"
    value = "false"
  }


  # --- Connect to RDS MySQL (Catalog) ---
  set {
    name  = "catalog.mysql.host"
    value = aws_db_instance.catalog_db.address
  }
  set {
    name  = "catalog.mysql.port"
    value = "3306"
  }
  set {
    name = "catalog.mysql.username"

    value = jsondecode(aws_secretsmanager_secret_version.catalog_db_secret_val.secret_string)["username"]
  }
  set {
    name = "catalog.mysql.password"
    # ✅ DYNAMICALLY PULL PASSWORD FROM SECRET
    value = jsondecode(aws_secretsmanager_secret_version.catalog_db_secret_val.secret_string)["password"]
  }

  # --- Connect to RDS Postgres (Orders) ---
  set {
    name  = "orders.postgresql.host"
    value = aws_db_instance.orders_db.address
  }
  set {
    name  = "orders.postgresql.port"
    value = "5432"
  }
  set {
    name = "orders.postgresql.username"

    value = jsondecode(aws_secretsmanager_secret_version.orders_db_secret_val.secret_string)["username"]
  }
  set {
    name = "orders.postgresql.password"
    # ✅ DYNAMICALLY PULL PASSWORD FROM SECRET
    value = jsondecode(aws_secretsmanager_secret_version.orders_db_secret_val.secret_string)["password"]
  }

  depends_on = [
    kubernetes_namespace.retail_app,
    module.eks,
    aws_db_instance.catalog_db,
    aws_db_instance.orders_db
  ]
}
