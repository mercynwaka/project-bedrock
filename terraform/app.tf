resource "kubernetes_namespace" "retail_app" {
  metadata {
    name = "retail-app"
  }
  depends_on = [module.eks]
}

data "aws_secretsmanager_secret_version" "catalog_password" {
  secret_id = aws_secretsmanager_secret.catalog_db_secret.id
}

resource "helm_release" "retail_app" {
  name       = "retail-store-sample-app"
  repository = "oci://public.ecr.aws/aws-containers"
  chart      = "retail-store-sample-chart"
  version    = "0.8.5"
  namespace  = "retail-app"

  timeout = 900
  wait    = true

  set_sensitive {
    name  = "catalog.mysql.password"
    value = jsondecode(data.aws_secretsmanager_secret_version.catalog_password.secret_string)["password"]
  }

  set {
    name  = "catalog.podLabels.app\\.kubernetes\\.io/owner"
    value = "retail-store-sample"
  }

  set {
    name  = "catalog.podLabels.app\\.kuberneres\\.io/owner"
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
  value = aws_db_instance.catalog_db.address
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
  name  = "catalog.mysql.password"
  value = jsondecode(data.aws_secretsmanager_secret_version.catalog_password.secret_string)["password"]
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
  value = "catalog"
}
set {
  name  = "orders.postgresql.password"
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

set {
  name  = "ui.service.type"
  value = "LoadBalancer"
}

depends_on = [
  kubernetes_namespace.retail_app,
  module.eks,
  aws_db_instance.catalog_db,
  aws_db_instance.orders_db
]
}
