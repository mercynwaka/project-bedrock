# --- Create the Namespace for Logging ---
resource "kubernetes_namespace" "amazon_cloudwatch" {
  metadata {
    name = "amazon-cloudwatch"
  }
}

# --- Install Fluent Bit (Lightweight Logger) ---
resource "helm_release" "fluent_bit" {
  name       = "aws-for-fluent-bit"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  version    = "0.1.34" # Stable version
  namespace  = kubernetes_namespace.amazon_cloudwatch.metadata[0].name

  # 1. Point logs to the correct region
  set {
    name  = "cloudWatch.region"
    value = "us-east-1"
  }

  # 2. Create the Log Group automatically
  set {
    name  = "cloudWatch.logGroupName"
    value = "/aws/eks/project-bedrock/workload-logs"
  }

  # 3.  Limit Memory for Free Tier
  # Standard defaults will crash t3.micro. These limits prevent that.
  set {
    name  = "resources.limits.memory"
    value = "100Mi"
  }
  set {
    name  = "resources.requests.memory"
    value = "50Mi"
  }
  set {
    name  = "resources.requests.cpu"
    value = "10m"
  }

  depends_on = [module.eks, kubernetes_namespace.amazon_cloudwatch]
}
