provider "github" {
  owner = var.organization
  # Token comes from GITHUB_TOKEN. It needs repo, admin:org and delete_repo.
  # A fine-grained token will not do: organisation rulesets need the classic
  # admin:org scope.
}
