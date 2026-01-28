# Bitwarden Secret Sync Module

Manages a single BitwardenSecret CRD that syncs a secret from Bitwarden Secrets Manager to Kubernetes.

## Features

- **Single Secret**: Each module instance handles one secret
- **Direct naming**: Kubernetes secret name matches the CRD name exactly
- **Reusable**: Use `for_each` in the calling module to create multiple instances

## Usage

Single secret:

```hcl
module "bitwarden_secret_example" {
  source = "./modules/bitwarden/bitwarden-secret"

  name            = "example-secret"
  namespace       = "bitwarden-secrets"
  organization_id = "your-org-id"
  secret_id      = "00000000-0000-0000-0000-000000000000"
  key_name       = "demo-secret-key"

  # access_token_secret_name defaults to "bitwarden-auth-token" (matches bitwarden module)
  # access_token_secret_key defaults to "token" (matches bitwarden module)

  tags = local.common_tags
}
```

Multiple secrets (using for_each):

```hcl
module "bitwarden_secrets" {
  source = "./modules/bitwarden/bitwarden-secret"
  for_each = {
    example-secret = {
      secret_id = "00000000-0000-0000-0000-000000000000"
      key_name  = "demo-secret-key"
    }
    api-key = {
      secret_id = "another-secret-id"
      key_name  = "api-key"
    }
  }

  name            = each.key
  namespace       = "bitwarden-secrets"
  organization_id = "your-org-id"
  secret_id       = each.value.secret_id
  key_name        = each.value.key_name

  tags = local.common_tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | -------- |
| name | Name of the BitwardenSecret CRD | `string` | n/a | yes |
| namespace | Kubernetes namespace for the secret | `string` | n/a | yes |
| organization_id | Bitwarden organization ID | `string` | n/a | yes |
| secret_id | Bitwarden secret ID to sync | `string` | n/a | yes |
| key_name | Kubernetes secret key name | `string` | n/a | yes |
| access_token_secret_name | Name of K8s secret with access token | `string` | `"bitwarden-auth-token"` | no |
| access_token_secret_key | Key name in access token secret | `string` | `"token"` | no |
| tags | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| name | Name of the BitwardenSecret CRD |
| kubernetes_secret_name | Name of the Kubernetes secret (matches CRD name) |
| namespace | Namespace where the secret is created |

## How It Works

1. Creates a BitwardenSecret CRD resource
2. Bitwarden Operator watches the CRD
3. Operator syncs the secret from Bitwarden to Kubernetes
4. Kubernetes secret is created with the name specified in `spec.secretName` (matches CRD name)
