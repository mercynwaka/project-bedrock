# --- SECURITY GROUP FOR RDS ---
resource "aws_security_group" "rds_sg" {
  name        = "bedrock-rds-sg"
  description = "Allow EKS access to RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }
}

resource "aws_db_subnet_group" "bedrock" {
  name       = "bedrock-db-subnet-group"
  subnet_ids = module.vpc.private_subnets
  tags       = { Project = "Bedrock" }
}

# 1. Generate a random password automatically
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 2. Create the Secret Container
resource "aws_secretsmanager_secret" "catalog_db_secret" {
  name = "bedrock-catalog-db-creds"
}

# 3. Store the credentials (username & password) in the secret
resource "aws_secretsmanager_secret_version" "catalog_db_secret_val" {
  secret_id = aws_secretsmanager_secret.catalog_db_secret.id
  secret_string = jsonencode({
    username = "adminuser"
    password = random_password.db_password.result
  })
}

# --- MYSQL (Catalog) ---
resource "aws_db_instance" "catalog_db" {
  identifier             = "bedrock-catalog-db"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "catalogdb"
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.bedrock.name

  # --- SECRETS MANAGER INTEGRATION ---

  # 1. Reference the username from the secret (consistent)
  username = jsondecode(aws_secretsmanager_secret_version.catalog_db_secret_val.secret_string)["username"]

  # 2. Reference the password dynamically
  password = jsondecode(aws_secretsmanager_secret_version.catalog_db_secret_val.secret_string)["password"]
}


# --- SECRETS: ORDERS DB (Postgres) ---

resource "aws_secretsmanager_secret" "orders_db_secret" {
  name = "bedrock-orders-db-creds"
}

resource "aws_secretsmanager_secret_version" "orders_db_secret_val" {
  secret_id = aws_secretsmanager_secret.orders_db_secret.id
  secret_string = jsonencode({
    username = "postgres_admin"
    password = random_password.db_password.result
  })
}


# --- POSTGRES (Orders) ---
resource "aws_db_instance" "orders_db" {
  identifier             = "bedrock-orders-db"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = "db.t3.micro"
  db_name                = "ordersdb"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.bedrock.name


  # --- SECRETS MANAGER INTEGRATION ---

  username = jsondecode(aws_secretsmanager_secret_version.orders_db_secret_val.secret_string)["username"]
  password = jsondecode(aws_secretsmanager_secret_version.orders_db_secret_val.secret_string)["password"]
}

