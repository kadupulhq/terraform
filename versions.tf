terraform {
  required_version = ">= 1.10.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }

  # State describes who can merge to main across the organisation, so it does
  # not belong on one laptop. Fill this in before the first apply.
  # cloud {
  #   organization = "kadupul"
  #   workspaces { name = "github" }
  # }
}
