resource "github_repository" "this" {
  for_each = local.repositories

  name        = each.key
  description = each.value.description
  topics      = each.value.topics

  visibility = "private"

  has_issues      = true
  has_discussions = each.value.has_discussions
  has_wiki        = false
  has_projects    = false
  is_template     = each.key == "template"

  allow_merge_commit     = false
  allow_squash_merge     = true
  allow_rebase_merge     = true
  allow_auto_merge       = true
  delete_branch_on_merge = true

  # Every commit carries a DCO sign-off, including ones made in the web editor.
  web_commit_signoff_required = true

  lifecycle {
    # Removing a block from this file must never delete a repository.
    prevent_destroy = true

    # Visibility is flipped deliberately by a human, not by a plan.
    ignore_changes = [visibility]
  }
}

resource "github_branch_default" "main" {
  for_each   = github_repository.this
  repository = each.value.name
  branch     = "main"
}

resource "github_repository_vulnerability_alerts" "this" {
  for_each   = github_repository.this
  repository = each.value.name
  enabled    = true
}
