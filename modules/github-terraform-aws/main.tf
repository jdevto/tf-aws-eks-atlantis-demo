# GitHub repository
# The organization is determined by the GitHub provider's 'owner' field
# in the root module (providers.tf). Set var.github_owner to your specific
# organization name to create the repository in that organization.
resource "githubx_repository" "this" {
  name        = var.repository_name
  description = "Infrastructure as Code repository managed by Atlantis"
  visibility  = "public"
  auto_init   = true # Initialize with README to create default branch
}

# NOTE: The repository must be manually added to the GitHub App installation
# because managing GitHub App installations requires organization OWNER role,
# not just admin role, even with admin:org scope.
#
# After the repository is created, manually add it to the installation:
# 1. Go to: https://github.com/organizations/{org}/settings/installations
# 2. Find your GitHub App installation and click "Configure"
# 3. Go to "Repository access" → Add the repository
#
# NOTE: For the create-pr workflow to work, enable the repository setting:
# Settings → Actions → General → Workflow permissions
# Enable: "Allow GitHub Actions to create and approve pull requests"

# Grant platform team access to the repository
# Data source to get the platform team
data "github_team" "platform" {
  slug = "platform"
}

# Required for CODEOWNERS to work - team must have access to be code owners
resource "github_team_repository" "platform" {
  team_id    = data.github_team.platform.id
  repository = githubx_repository.this.name
  permission = "push" # Push permission allows team members to review and approve PRs
}

# Grant devops team access to the repository
data "github_team" "devops" {
  slug = "devops"
}

# Required for CODEOWNERS to work - team must have access to be code owners
resource "github_team_repository" "devops" {
  team_id    = data.github_team.devops.id
  repository = githubx_repository.this.name
  permission = "push" # Push permission allows team members to review and approve PRs
}

# CODEOWNERS file to require platform team approval
# Add to main branch first (required for branch protection)
resource "githubx_repository_file" "codeowners_main" {
  repository = githubx_repository.this.name
  branch     = githubx_repository.this.default_branch
  file       = ".github/CODEOWNERS"
  content = templatefile("${path.module}/external/CODEOWNERS.tftpl", {
    github_owner = var.github_owner
  })
  commit_message      = <<-EOM
    docs: add CODEOWNERS

    Require platform team approval for all changes.
  EOM
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [content]
  }

  depends_on = [githubx_repository.this]
}

# GitHub Actions workflow to create PRs manually
resource "githubx_repository_file" "create_pr_workflow_main" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository.this.default_branch
  file                = ".github/workflows/create-pr.yml"
  content             = file("${path.module}/external/create-pr.yml")
  commit_message      = <<-EOM
    feat: add workflow to create PRs

    Add GitHub Actions workflow for manually creating pull requests.
  EOM
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [content]
  }
  depends_on = [githubx_repository_file.codeowners_main]
}

# Branch protection for main branch - requires at least one approval
# Code owner reviews are not required
resource "github_branch_protection" "main" {
  repository_id = githubx_repository.this.name
  pattern       = "main"

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = false # No code owner reviews required
  }

  depends_on = [
    githubx_repository.this,
    github_team_repository.platform,
    github_team_repository.devops,
    githubx_repository_file.codeowners_main
  ]
}

# Feature branch for initial setup PR (temporary, will be merged and deleted)
resource "githubx_repository_branch" "feature" {
  branch        = "feat/initial-setup"
  repository    = githubx_repository.this.name
  source_branch = githubx_repository.this.default_branch

  depends_on = [
    githubx_repository_file.codeowners_main,
    github_branch_protection.main
  ]
}

# Atlantis configuration file
resource "githubx_repository_file" "atlantis_yaml" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository_branch.feature.branch
  file                = "atlantis.yaml"
  content             = file("${path.module}/external/atlantis.yaml")
  commit_message      = <<-EOM
    docs: add atlantis.yaml

    Configure Atlantis to use the repository.
  EOM
  overwrite_on_create = true

  # Uncomment to allow manual edits without Terraform overwriting:
  lifecycle {
    ignore_changes = [content]
  }
}

# Backend configuration file for dev environment
resource "githubx_repository_file" "backend_dev" {
  repository = githubx_repository.this.name
  branch     = githubx_repository_branch.feature.branch
  file       = "dev/backend.tf"
  content = templatefile("${path.module}/external/backend.tftpl", {
    state_bucket_name = var.state_bucket_name
    repository_name   = var.repository_name
    region            = var.region
    environment       = "dev"
  })
  commit_message      = <<-EOM
    docs: add dev/backend.tf

    Configure Terraform backend for dev environment.
    State key: ${var.repository_name}/dev/terraform.tfstate
  EOM
  overwrite_on_create = true
  lifecycle {
    ignore_changes = [content]
  }
  depends_on = [githubx_repository_file.atlantis_yaml]
}

# Backend configuration file for prod environment
resource "githubx_repository_file" "backend_prod" {
  repository = githubx_repository.this.name
  branch     = githubx_repository_branch.feature.branch
  file       = "prod/backend.tf"
  content = templatefile("${path.module}/external/backend.tftpl", {
    state_bucket_name = var.state_bucket_name
    repository_name   = var.repository_name
    region            = var.region
    environment       = "prod"
  })
  commit_message      = <<-EOM
    docs: add prod/backend.tf

    Configure Terraform backend for prod environment.
    State key: ${var.repository_name}/prod/terraform.tfstate
  EOM
  overwrite_on_create = true
  lifecycle {
    ignore_changes = [content]
  }
  depends_on = [githubx_repository_file.atlantis_yaml]
}

# Example main.tf file for dev environment
resource "githubx_repository_file" "main_tf_dev" {
  repository = githubx_repository.this.name
  branch     = githubx_repository_branch.feature.branch
  file       = "dev/main.tf"
  content = templatefile("${path.module}/external/main.tftpl", {
    state_bucket_name = "${var.state_bucket_name}"
    environment       = "dev"
  })
  commit_message      = <<-EOM
    feat: add dev/main.tf

    Add example S3 bucket resource for dev environment.
  EOM
  overwrite_on_create = true
  lifecycle {
    ignore_changes = [content]
  }
  depends_on = [githubx_repository_file.backend_dev]
}

# Example main.tf file for prod environment
resource "githubx_repository_file" "main_tf_prod" {
  repository = githubx_repository.this.name
  branch     = githubx_repository_branch.feature.branch
  file       = "prod/main.tf"
  content = templatefile("${path.module}/external/main.tftpl", {
    state_bucket_name = "${var.state_bucket_name}"
    environment       = "prod"
  })
  commit_message      = <<-EOM
    feat: add prod/main.tf

    Add example S3 bucket resource for prod environment.
  EOM
  overwrite_on_create = true
  lifecycle {
    ignore_changes = [content]
  }
  depends_on = [githubx_repository_file.backend_prod]
}

# Example variables.tf file for dev environment
resource "githubx_repository_file" "variables_tf_dev" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository_branch.feature.branch
  file                = "dev/variables.tf"
  content             = file("${path.module}/external/variables.tftpl")
  commit_message      = <<-EOM
    feat: add dev/variables.tf

    Add example variables file for dev environment.
  EOM
  overwrite_on_create = true
  lifecycle {
    ignore_changes = [content]
  }
  depends_on = [githubx_repository_file.main_tf_dev]
}

# Example variables.tf file for prod environment
resource "githubx_repository_file" "variables_tf_prod" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository_branch.feature.branch
  file                = "prod/variables.tf"
  content             = file("${path.module}/external/variables.tftpl")
  commit_message      = <<-EOM
    feat: add prod/variables.tf

    Add example variables file for prod environment.
  EOM
  overwrite_on_create = true
  lifecycle {
    ignore_changes = [content]
  }
  depends_on = [githubx_repository_file.main_tf_prod]
}

# Example versions.tf file for dev environment
resource "githubx_repository_file" "versions_tf_dev" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository_branch.feature.branch
  file                = "dev/versions.tf"
  content             = file("${path.module}/external/versions.tftpl")
  commit_message      = <<-EOM
    feat: add dev/versions.tf

    Define Terraform and provider version requirements for dev.
  EOM
  overwrite_on_create = true
  lifecycle {
    ignore_changes = [content]
  }
  depends_on = [githubx_repository_file.variables_tf_dev]
}

# Example versions.tf file for prod environment
resource "githubx_repository_file" "versions_tf_prod" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository_branch.feature.branch
  file                = "prod/versions.tf"
  content             = file("${path.module}/external/versions.tftpl")
  commit_message      = <<-EOM
    feat: add prod/versions.tf

    Define Terraform and provider version requirements for prod.
  EOM
  overwrite_on_create = true
  lifecycle {
    ignore_changes = [content]
  }
  depends_on = [githubx_repository_file.variables_tf_prod]
}

# Example providers.tf file for dev environment
resource "githubx_repository_file" "providers_tf_dev" {
  repository = githubx_repository.this.name
  branch     = githubx_repository_branch.feature.branch
  file       = "dev/providers.tf"
  content = templatefile("${path.module}/external/providers.tftpl", {
    region = var.region
  })
  commit_message      = <<-EOM
    feat: add dev/providers.tf

    Configure AWS and random providers for dev.
  EOM
  overwrite_on_create = true
  lifecycle {
    ignore_changes = [content]
  }
  depends_on = [githubx_repository_file.versions_tf_dev]
}

# Example providers.tf file for prod environment
resource "githubx_repository_file" "providers_tf_prod" {
  repository = githubx_repository.this.name
  branch     = githubx_repository_branch.feature.branch
  file       = "prod/providers.tf"
  content = templatefile("${path.module}/external/providers.tftpl", {
    region = var.region
  })
  commit_message      = <<-EOM
    feat: add prod/providers.tf

    Configure AWS and random providers for prod.
  EOM
  overwrite_on_create = true
  lifecycle {
    ignore_changes = [content]
  }
  depends_on = [githubx_repository_file.versions_tf_prod]
}

# Example outputs.tf file for dev environment
resource "githubx_repository_file" "outputs_tf_dev" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository_branch.feature.branch
  file                = "dev/outputs.tf"
  content             = file("${path.module}/external/outputs.tftpl")
  commit_message      = <<-EOM
    feat: add dev/outputs.tf

    Add output for S3 bucket name in dev.
  EOM
  overwrite_on_create = true
  lifecycle {
    ignore_changes = [content]
  }
  depends_on = [githubx_repository_file.providers_tf_dev]
}

# Example outputs.tf file for prod environment
resource "githubx_repository_file" "outputs_tf_prod" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository_branch.feature.branch
  file                = "prod/outputs.tf"
  content             = file("${path.module}/external/outputs.tftpl")
  commit_message      = <<-EOM
    feat: add prod/outputs.tf

    Add output for S3 bucket name in prod.
  EOM
  overwrite_on_create = true
  lifecycle {
    ignore_changes = [content]
  }
  depends_on = [githubx_repository_file.providers_tf_prod]
}

resource "githubx_repository_pull_request_auto_merge" "auto_merge_pr" {
  repository         = githubx_repository.this.name
  base_ref           = "main"
  head_ref           = githubx_repository_branch.feature.branch
  title              = "feat: add initial Terraform configuration"
  body               = <<-EOM
    This PR adds the initial Terraform configuration files for the Atlantis demo:

    - Backend configuration (S3) for dev and prod environments
    - Atlantis configuration with directory-based structure
    - Example S3 bucket resources for dev and prod
    - Supporting files (variables, versions, providers, outputs) in dev/ and prod/ directories

    Ready for Atlantis to plan and apply.
  EOM
  merge_when_ready   = true
  merge_method       = "merge"
  wait_for_checks    = false
  auto_delete_branch = true

  depends_on = [
    githubx_repository_file.backend_dev,
    githubx_repository_file.backend_prod,
    githubx_repository_file.atlantis_yaml,
    githubx_repository_file.main_tf_dev,
    githubx_repository_file.main_tf_prod,
    githubx_repository_file.variables_tf_dev,
    githubx_repository_file.variables_tf_prod,
    githubx_repository_file.versions_tf_dev,
    githubx_repository_file.versions_tf_prod,
    githubx_repository_file.providers_tf_dev,
    githubx_repository_file.providers_tf_prod,
    githubx_repository_file.outputs_tf_dev,
    githubx_repository_file.outputs_tf_prod
  ]
}

# GitHub webhook to send events to Atlantis
# This webhook is essential for GitHub to notify Atlantis about pull requests, pushes, etc.
resource "github_repository_webhook" "atlantis" {
  repository = githubx_repository.this.name
  active     = true

  configuration {
    url          = "${var.atlantis_url}/events"
    content_type = "json"
    secret       = var.github_webhook_secret
    insecure_ssl = !startswith(var.atlantis_url, "https://")
  }

  events = [
    "issue_comment",
    "pull_request",
    "pull_request_review",
    "pull_request_review_comment",
    "push"
  ]

  depends_on = [githubx_repository.this]
}
