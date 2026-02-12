# tf-aws-eks-atlantis-demo

Atlantis on EKS with Terraform automation demo

# need to run twice so the shared_alb_arn gets populated

terraform apply -target=module.eks

terraform apply -target=module.landing_page

terraform apply -target=module.argocd

terraform apply -target=module.bitwarden

terraform apply -target=module.atlantis

terraform apply -target=module.github_terraform_aws

##########

terraform destroy -target=module.github_terraform_aws --auto-approve

terraform apply -target=module.atlantis --auto-approve

terraform apply -target=module.bitwarden --auto-approve

terraform apply -target=module.argocd --auto-approve

terraform apply -target=module.landing_page --auto-approve

terraform apply -target=module.eks --auto-approve

## Troubleshooting

### Cannot curl <https://argocd.dev.geonet.cloud> (or other subdomains)

DNS resolves but HTTPS times out or is refused because the **shared ALB security group restricts access by IP**.

- Allowed: VPC CIDR, and the CIDRs in `shared_alb_allowed_ips` in `terraform.tfvars` (plus GitHub webhook IPs for 443).
- If your client IP is not in that list, the ALB will drop the connection (curl will timeout).

**Fix:** Add your IP to `shared_alb_allowed_ips` in `terraform.tfvars`, then run `terraform apply` so the ALB security group is updated. Example:

```hcl
shared_alb_allowed_ips = [
  "202.180.122.6/32",
  "172.30.0.0/19",
  "161.65.32.0/19",
  "YOUR_IP/32"   # e.g. "203.0.113.50/32"
]
```

To allow unrestricted access (e.g. for a demo), set `shared_alb_allowed_ips = []` or include `"0.0.0.0/0"` so the module allows all IPs.

### Webhook "payload signature check failed" (400)

GitHub signs webhook payloads with a secret; Atlantis verifies using `ATLANTIS_GH_WEBHOOK_SECRET`. If they differ, Atlantis returns 400.

- **GitHub** gets the secret from Terraform: `github_webhook_secret` in `terraform.tfvars` (used when creating the repo webhook).
- **Atlantis** gets it from the Bitwarden-synced Kubernetes secret: the Bitwarden secret whose ID is `bitwarden_secrets["dev-github-webhook-secret"]`; the secret’s **value** in Bitwarden must match `github_webhook_secret` in tfvars.

**Fix:** In Bitwarden, open the secret for `dev-github-webhook-secret` (ID in `bitwarden_secrets`) and set its value to exactly the same string as `github_webhook_secret` in `terraform.tfvars`. After the Bitwarden operator syncs (or you restart the Atlantis pod), redeliver the webhook from GitHub.
