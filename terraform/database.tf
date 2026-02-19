# --- 1. THE SECURITY GROUP CONTAINER ---
resource "aws_security_group" "rds_sg" {
  name_prefix = "bedrock-rds-sg-"
  description = "Security group for Project Bedrock RDS instances"
  vpc_id      = module.vpc.vpc_id

  # include an egress rule so the DB can send data back to the app
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Project = "Bedrock" }

  lifecycle {
    create_before_destroy = true
  }
}

# --- 2. DECOUPLED RULES  ---

# Rule for MySQL (Catalog Service)
resource "aws_security_group_rule" "allow_eks_mysql" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = module.eks.node_security_group_id # Trust the EKS nodes
  description              = "Allow EKS nodes to reach MySQL RDS"
}

# Rule for PostgreSQL (Orders Service)
resource "aws_security_group_rule" "allow_eks_postgres" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = module.eks.node_security_group_id # Trust the EKS nodes
  description              = "Allow EKS nodes to reach Postgres RDS"
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
resource "aws_secretsmanager_secret" "catalog_secret" {
  name = "bedrock-catalog-db-creds"
}

# 3. Store the credentials (username & password) in the secret
resource "aws_secretsmanager_secret_version" "catalog_secret_val" {
  secret_id = aws_secretsmanager_secret.catalog_secret.id
  secret_string = jsonencode({
    username = "catalog"
    password = random_password.db_password.result
  })
}

# --- MYSQL (Catalog) ---
resource "aws_db_instance" "catalog" {
  identifier             = "bedrock-catalog-db"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "catalog"
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.bedrock.name
  apply_immediately      = true
  
  # --- SECRETS MANAGER INTEGRATION ---
  
  username = jsondecode(aws_secretsmanager_secret_version.catalog_secret_val.secret_string)["username"]
  password = jsondecode(aws_secretsmanager_secret_version.catalog_secret_val.secret_string)["password"]
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
