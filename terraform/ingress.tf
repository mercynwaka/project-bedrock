# --- IAM Role for LB Controller ---
module "lb_role" {
  
source                                   = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
version = "~> 5.39"     
  role_name                              = "bedrock-eks-lb-controller"
  attach_load_balancer_controller_policy = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}


# --- 2. Install Load Balancer Controller ---
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lb_role.iam_role_arn
  }
}


# --- 3. Ingress Resource---
resource "kubernetes_ingress_v1" "retail_ingress" {
  metadata {
    name      = "retail-store-ingress"
    namespace = "retail-app"

    annotations = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"

      # --- SSL CONFIGURATION ---

      "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:us-east-1:813594602707:certificate/b757179c-cace-4820-bec2-2761485fb48b"

      # Listen on both HTTP (80) and HTTPS (443)
      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{ "HTTP" : 80 }, { "HTTPS" : 443 }])

      # Redirect HTTP traffic to HTTPS automatically
      "alb.ingress.kubernetes.io/ssl-redirect" = "443"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = "africodes.com"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "ui" # This must match the service name created by the Helm chart
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.aws_load_balancer_controller, helm_release.retail_app]
}
