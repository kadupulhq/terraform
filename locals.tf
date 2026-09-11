locals {
  # Labels every repository gets. Colours are grouped by meaning: red for
  # things that are wrong, blue for things to build, grey for process.
  common_labels = {
    "bug"              = { color = "d73a4a", description = "Behaviour differs from what is documented" }
    "security"         = { color = "b60205", description = "Security impact, handled under SECURITY.md" }
    "regression"       = { color = "e99695", description = "Worked in an earlier release" }
    "enhancement"      = { color = "0075ca", description = "Proposed change in behaviour" }
    "documentation"    = { color = "0e8a16", description = "Documentation only" }
    "dependencies"     = { color = "1d76db", description = "Dependency updates" }
    "ci"               = { color = "5319e7", description = "Build, test and release plumbing" }
    "breaking-change"  = { color = "b60205", description = "Requires a major release" }
    "good first issue" = { color = "7057ff", description = "Small and well defined" }
    "help wanted"      = { color = "008672", description = "Maintainers would welcome a hand" }
    "needs-repro"      = { color = "fbca04", description = "Cannot act until it reproduces" }
    "upstream-cacti"   = { color = "c5def5", description = "Inherited from Cacti" }
    "wontfix"          = { color = "6a737d", description = "Deliberately not changing this" }
    "duplicate"        = { color = "6a737d", description = "Already tracked elsewhere" }
  }

  # Labels only the application repository needs.
  app_labels = {
    "poller"     = { color = "fef2c0", description = "Data collection: cmd.php, spine, SNMP" }
    "graphs"     = { color = "fef2c0", description = "RRDtool, graph templates, rendering" }
    "plugin-api" = { color = "d4c5f9", description = "Touches the interface plugins depend on" }
    "database"   = { color = "fef2c0", description = "Schema, migrations, queries" }
    "migration"  = { color = "0052cc", description = "Importing an existing Cacti install" }
  }

  repositories = {
    kadupul = {
      description     = "Network monitoring and graphing. A fork of Cacti."
      topics          = ["monitoring", "network-monitoring", "snmp", "rrdtool", "graphing", "php", "cacti"]
      labels          = merge(local.common_labels, local.app_labels)
      has_discussions = true
    }
    website = {
      description     = "Documentation site for Kadupul"
      topics          = ["documentation", "astro", "static-site"]
      labels          = local.common_labels
      has_discussions = false
    }
    template = {
      description     = "Starting point for a new repository: versioning, releases, Dependabot"
      topics          = ["template"]
      labels          = local.common_labels
      has_discussions = false
    }
    terraform = {
      description     = "This organisation, as code"
      topics          = ["terraform", "infrastructure-as-code"]
      labels          = local.common_labels
      has_discussions = false
    }
  }

  # repo/label pairs, so one resource covers every repository.
  repository_labels = merge([
    for repo, cfg in local.repositories : {
      for name, label in cfg.labels :
      "${repo}/${name}" => merge(label, { repository = repo, name = name })
    }
  ]...)
}
