# terraform/secrets.tf

resource "kubernetes_manifest" "catalog_db_secret_provider" {
  manifest = {
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"
    metadata = {
      name      = "catalog-db-aws-provider"
      namespace = "retail-app"
    }
    spec = {
      provider = "aws"
      parameters = {
        objects = <<-EOT
          - objectName: "bedrock-catalog-db-creds-v2"
            objectType: "secretsmanager"
            jmesPath: 
              - path: "username"
                objectAlias: "username"
              - path: "password"
                objectAlias: "password"
        EOT
      }
      secretObjects = [{
        secretName = "catalog"
        type       = "Opaque"
        data = [
          { objectName = "username", key = "username" },
          { objectName = "password", key = "password" }
        ]
      }]
    }
  }
}
