resource "github_issue_label" "this" {
  for_each = local.repository_labels

  repository  = github_repository.this[each.value.repository].name
  name        = each.value.name
  color       = each.value.color
  description = each.value.description
}
