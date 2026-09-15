# terraform

This organisation, as code: repositories, labels, default branches, and the
rules that protect them.

The independent [Weblate stack](stacks/weblate/README.md) captures Kadupul's
existing DigitalOcean translation service, imports, deployment configuration,
backup automation and operational handoff. Run that stack using `-chdir` as
documented there; root-level plans manage GitHub only. Runtime versions are
pinned in `.mise.toml`; use `mise exec -- terraform ...`.

## What it manages

- Every repository in the organisation, with its settings, topics and
  description.
- Issue labels, defined once and applied to every repository.
- A ruleset on each default branch: linear history, signed commits, no force
  push, no deletion, and resolved review threads.
- Dependabot alerts.

## What it does not manage

Organisation-level settings, member access, and billing. Those need a token
with `admin:org` and a decision about whether Terraform should own them at all.
Repository contents are never managed here.

## Running it

You need a classic personal access token with `repo`, `admin:org` and
`delete_repo`. A fine-grained token cannot create rulesets.

```
export GITHUB_TOKEN=ghp_...
terraform init
terraform plan
```

Read the plan. Then apply by hand:

```
terraform apply
```

Continuous integration checks formatting and validity on every pull request and
produces a plan on `main`. It never applies. Changing who can merge across the
organisation is a decision someone makes on purpose.

## Adopting a repository that already exists

Add it to `local.repositories` in `locals.tf`, then add an import block in
`imports.tf`:

```hcl
import {
  to = github_repository.this["name"]
  id = "name"
}
```

The next plan adopts it instead of trying to create it. Import blocks are a
no-op once the resource is in state, so they can stay.

## State

State records who can merge to main. Set the `cloud` block in `versions.tf`
before the first apply so it does not live on one laptop.

## Deleting a repository

You cannot, from here. Every repository carries `prevent_destroy`. Removing it
from `locals.tf` and applying will fail on purpose. Delete a repository
deliberately, in the web interface, then remove it from this configuration.
