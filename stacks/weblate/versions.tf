# SPDX-FileCopyrightText: 2026 Thomas Vincent <thomasvincent@gmail.com>
# SPDX-License-Identifier: MIT

terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.107.0"
    }
  }

  # Configure an encrypted, access-controlled shared backend before applying.
  # A local plan can verify imports without writing production state.
}

# Read DIGITALOCEAN_TOKEN from the operator's environment. Never pass secrets
# through Terraform variables, user-data, provisioners, or checked-in files.
provider "digitalocean" {}
