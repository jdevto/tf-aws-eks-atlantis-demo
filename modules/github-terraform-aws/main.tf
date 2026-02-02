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

# Grant platform team access to the repository
data "github_team" "platform" {
  slug = "platform"
}

resource "github_team_repository" "platform" {
  team_id    = data.github_team.platform.id
  repository = githubx_repository.this.name
  permission = "maintain"
}

# Grant devops team access to the repository
data "github_team" "devops" {
  slug = "devops"
}

resource "github_team_repository" "devops" {
  team_id    = data.github_team.devops.id
  repository = githubx_repository.this.name
  permission = "push"
}

# CODEOWNERS file
resource "githubx_repository_file" "codeowners_main" {
  repository = githubx_repository.this.name
  branch     = githubx_repository.this.default_branch
  file       = ".github/CODEOWNERS"
  content = templatefile("${path.module}/external/CODEOWNERS.tftpl", {
    github_owner = var.github_owner
  })
  commit_message      = "docs: add CODEOWNERS"
  overwrite_on_create = true

  depends_on = [githubx_repository.this]
}

# Branch protection for main branch
resource "github_branch_protection" "main" {
  repository_id = githubx_repository.this.name
  pattern       = "main"

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = false
  }

  depends_on = [
    githubx_repository.this,
    github_team_repository.platform,
    github_team_repository.devops,
    githubx_repository_file.codeowners_main
  ]
}

# Atlantis configuration file
resource "githubx_repository_file" "atlantis_yaml" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository.this.default_branch
  file                = "atlantis.yaml"
  content             = file("${path.module}/external/atlantis.yaml")
  commit_message      = "docs: add atlantis.yaml"
  overwrite_on_create = true

  depends_on = [github_branch_protection.main]
}

# Conftest policy file for Atlantis policy checks
resource "githubx_repository_file" "conftest_policy" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository.this.default_branch
  file                = ".atlantis/policies/main.rego"
  content             = file("${path.module}/external/policies/main.rego")
  commit_message      = "feat: add Conftest policy for Atlantis"
  overwrite_on_create = true

  depends_on = [githubx_repository_file.atlantis_yaml]
}

# Backend configuration file for dev environment
resource "githubx_repository_file" "backend_dev" {
  repository = githubx_repository.this.name
  branch     = githubx_repository.this.default_branch
  file       = "dev/backend.tf"
  content = templatefile("${path.module}/external/backend.tftpl", {
    state_bucket_name = var.state_bucket_name
    repository_name   = var.repository_name
    region            = var.region
    environment       = "dev"
  })
  commit_message      = "docs: add dev/backend.tf"
  overwrite_on_create = true

  depends_on = [githubx_repository_file.atlantis_yaml]
}

# Backend configuration file for prod environment
resource "githubx_repository_file" "backend_prod" {
  repository = githubx_repository.this.name
  branch     = githubx_repository.this.default_branch
  file       = "prod/backend.tf"
  content = templatefile("${path.module}/external/backend.tftpl", {
    state_bucket_name = var.state_bucket_name
    repository_name   = var.repository_name
    region            = var.region
    environment       = "prod"
  })
  commit_message      = "docs: add prod/backend.tf"
  overwrite_on_create = true

  depends_on = [githubx_repository_file.atlantis_yaml]
}

# Example main.tf file for dev environment
resource "githubx_repository_file" "main_tf_dev" {
  repository = githubx_repository.this.name
  branch     = githubx_repository.this.default_branch
  file       = "dev/main.tf"
  content = templatefile("${path.module}/external/main.tftpl", {
    state_bucket_name = "${var.state_bucket_name}"
    environment       = "dev"
  })
  commit_message      = "feat: add dev/main.tf"
  overwrite_on_create = true

  depends_on = [githubx_repository_file.backend_dev]
}

# Example main.tf file for prod environment
resource "githubx_repository_file" "main_tf_prod" {
  repository = githubx_repository.this.name
  branch     = githubx_repository.this.default_branch
  file       = "prod/main.tf"
  content = templatefile("${path.module}/external/main.tftpl", {
    state_bucket_name = "${var.state_bucket_name}"
    environment       = "prod"
  })
  commit_message      = "feat: add prod/main.tf"
  overwrite_on_create = true

  depends_on = [githubx_repository_file.backend_prod]
}

# Example variables.tf file for dev environment
resource "githubx_repository_file" "variables_tf_dev" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository.this.default_branch
  file                = "dev/variables.tf"
  content             = file("${path.module}/external/variables.tftpl")
  commit_message      = "feat: add dev/variables.tf"
  overwrite_on_create = true

  depends_on = [githubx_repository_file.main_tf_dev]
}

# Example variables.tf file for prod environment
resource "githubx_repository_file" "variables_tf_prod" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository.this.default_branch
  file                = "prod/variables.tf"
  content             = file("${path.module}/external/variables.tftpl")
  commit_message      = "feat: add prod/variables.tf"
  overwrite_on_create = true

  depends_on = [githubx_repository_file.main_tf_prod]
}

# Example versions.tf file for dev environment
resource "githubx_repository_file" "versions_tf_dev" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository.this.default_branch
  file                = "dev/versions.tf"
  content             = file("${path.module}/external/versions.tftpl")
  commit_message      = "feat: add dev/versions.tf"
  overwrite_on_create = true

  depends_on = [githubx_repository_file.variables_tf_dev]
}

# Example versions.tf file for prod environment
resource "githubx_repository_file" "versions_tf_prod" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository.this.default_branch
  file                = "prod/versions.tf"
  content             = file("${path.module}/external/versions.tftpl")
  commit_message      = "feat: add prod/versions.tf"
  overwrite_on_create = true

  depends_on = [githubx_repository_file.variables_tf_prod]
}

# Example providers.tf file for dev environment
resource "githubx_repository_file" "providers_tf_dev" {
  repository = githubx_repository.this.name
  branch     = githubx_repository.this.default_branch
  file       = "dev/providers.tf"
  content = templatefile("${path.module}/external/providers.tftpl", {
    region = var.region
  })
  commit_message      = "feat: add dev/providers.tf"
  overwrite_on_create = true

  depends_on = [githubx_repository_file.versions_tf_dev]
}

# Example providers.tf file for prod environment
resource "githubx_repository_file" "providers_tf_prod" {
  repository = githubx_repository.this.name
  branch     = githubx_repository.this.default_branch
  file       = "prod/providers.tf"
  content = templatefile("${path.module}/external/providers.tftpl", {
    region = var.region
  })
  commit_message      = "feat: add prod/providers.tf"
  overwrite_on_create = true

  depends_on = [githubx_repository_file.versions_tf_prod]
}

# Example outputs.tf file for dev environment
resource "githubx_repository_file" "outputs_tf_dev" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository.this.default_branch
  file                = "dev/outputs.tf"
  content             = file("${path.module}/external/outputs.tftpl")
  commit_message      = "feat: add dev/outputs.tf"
  overwrite_on_create = true

  depends_on = [githubx_repository_file.providers_tf_dev]
}

# Example outputs.tf file for prod environment
resource "githubx_repository_file" "outputs_tf_prod" {
  repository          = githubx_repository.this.name
  branch              = githubx_repository.this.default_branch
  file                = "prod/outputs.tf"
  content             = file("${path.module}/external/outputs.tftpl")
  commit_message      = "feat: add prod/outputs.tf"
  overwrite_on_create = true

  depends_on = [githubx_repository_file.providers_tf_prod]
}

# GitHub webhook to send events to Atlantis
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
