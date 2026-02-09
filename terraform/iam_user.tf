resource "aws_iam_user" "dev_view" {
  name = "bedrock-dev-view"

  tags = { Project = "Bedrock" }
}

# Console Access (ReadOnly)
resource "aws_iam_user_policy_attachment" "dev_ro" {
  user       = aws_iam_user.dev_view.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Kubernetes Access (View Only)
resource "aws_eks_access_entry" "dev_view" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = aws_iam_user.dev_view.arn
  kubernetes_groups = ["bedrock-view-group"]
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "dev_view" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  principal_arn = aws_iam_user.dev_view.arn
  access_scope {
    type = "cluster"
  }
}


resource "aws_iam_access_key" "dev_keys" {
  user = aws_iam_user.dev_view.name
}


# 2. Create a Secret in AWS Secrets Manager
resource "aws_secretsmanager_secret" "dev_user_creds" {
  name        = "bedrock-dev-view-keys"
  description = "Access keys for the developer view-only user"

  # Force deletion allows you to destroy/recreate easily while testing
  recovery_window_in_days = 0
}

# 3. Store the Generate Keys inside that Secret
resource "aws_secretsmanager_secret_version" "dev_user_creds_val" {
  secret_id = aws_secretsmanager_secret.dev_user_creds.id
  secret_string = jsonencode({
    access_key_id     = aws_iam_access_key.dev_keys.id
    secret_access_key = aws_iam_access_key.dev_keys.secret

    # Helpful instruction for whoever retrieves this
    instructions = "Use these to configure AWS CLI or local .aws/credentials"
  })
}
