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
