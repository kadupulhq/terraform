# Preserve existing label assignments while renaming the labels in place.

moved {
  from = github_issue_label.this["kadupul/upstream-cacti"]
  to   = github_issue_label.this["kadupul/shared-code"]
}

moved {
  from = github_issue_label.this["website/upstream-cacti"]
  to   = github_issue_label.this["website/shared-code"]
}

moved {
  from = github_issue_label.this["template/upstream-cacti"]
  to   = github_issue_label.this["template/shared-code"]
}

moved {
  from = github_issue_label.this["terraform/upstream-cacti"]
  to   = github_issue_label.this["terraform/shared-code"]
}
