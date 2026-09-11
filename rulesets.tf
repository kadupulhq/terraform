# Rulesets rather than branch protection: branch protection is the older API and
# GitHub's own tooling has moved on. Required status checks are deliberately
# absent until each repository has had a green run; naming a check that has
# never reported blocks every merge.
resource "github_repository_ruleset" "main" {
  for_each = github_repository.this

  name        = "main"
  repository  = each.value.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  bypass_actors {
    # Repository admins can still push directly. This is a small project and a
    # locked branch with one maintainer is a foot-gun, not a control.
    actor_id    = 5
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  rules {
    deletion         = true
    non_fast_forward = true

    required_linear_history = true

    required_signatures = true

    pull_request {
      required_approving_review_count   = 0
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = false
      required_review_thread_resolution = true
    }
  }
}
