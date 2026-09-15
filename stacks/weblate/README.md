# Kadupul Weblate infrastructure

This independent Terraform root captures the existing service at
https://translate.kadupul.net in the owner-selected **Relenz** DigitalOcean team.
It does not share state or provider credentials with the GitHub root at the top
of this repository. Configuration and a live adoption plan were validated on
2026-09-15; **no Terraform apply or state adoption has been performed**.

## Ownership and scope

| Item | Configuration / existing identity | Ownership |
| --- | --- | --- |
| Team | Relenz, `3b2f3d4514494e62ac337d6221ba474dbf02a36d` | Existing account; checked by project postcondition |
| Project | Kadupul, `2d803cfc-9618-4830-9627-9a6c206d7ada` | Terraform import; includes Droplet assignment |
| Droplet | `kadupul-weblate-01`, `600537369` | Terraform import |
| Compute | `sfo3`, `s-2vcpu-4gb`, Ubuntu 24.04, 2 CPU / 4 GB / 80 GB | Terraform |
| Network | Origin `64.23.171.186`, private `10.124.0.3`; IPv6 disabled | Droplet outputs |
| VPC | `60a80fc6-4809-4fa4-b8fd-8863cfc1d70d` | Shared existing VPC, referenced only |
| SSH key | `m3 laptop`, ID `46721354` | Shared existing key, data source only |
| Firewall | `f33c3d71-c246-45f8-a8a1-96a8db96bce2` | Terraform import |
| Tag | `kadupul-weblate` | Terraform import; firewall targets this tag |
| Backup policy | Daily, 08:00 UTC start, four-hour window, seven-day retention | Terraform policy; window/retention supplied by DigitalOcean |
| DNS | Cloudflare-proxied `translate.kadupul.net A 64.23.171.186` | Existing owner-managed record; documented, not imported |
| Application | Pinned Weblate, PostgreSQL, Valkey and Caddy containers | [Deployment files and runbook](deployment/README.md), installed over SSH |
| Database backups | Daily 07:00 UTC systemd timer, seven-day local retention | Deployment files |
| GitHub integration | Kadupul Translations App, website-only installation | Weblate/GitHub settings, documented below |

No DigitalOcean DNS zone is created for the Cloudflare-managed hostname. No
GitHub App private key, database password, admin password, API token, application
database, backup archive or production `.env` belongs in Terraform state or Git.
Terraform does not install containers or manage Weblate's database records.

The deployment files were copied from website commit
`1faa4b9f51c976c6f8c63e6c1df982265da6ca86` (merged website PR #4), together with
the backup behavior tests. This directory is the infrastructure maintenance
location going forward. The original website copies remain as historical setup
material; use these files for future infrastructure changes. Translation catalogs,
source hashes, review metadata and site generation remain in the website repo.

## Validate and plan

Run from this repository's root, using the pinned mise runtimes:

```sh
mise install
mise exec -- terraform fmt -check -recursive
mise exec -- terraform -chdir=stacks/weblate init -backend=false -input=false -lockfile=readonly
mise exec -- terraform -chdir=stacks/weblate validate
mise exec -- node --test stacks/weblate/tests/backup.test.mjs
```

Supply `DIGITALOCEAN_TOKEN` at runtime from the owner's existing credential store
or the selected doctl configuration. Do not type a token literal into shell
history, pass it with `-var`, or enable provider HTTP/trace logging. Confirm
`doctl account get` identifies Relenz before planning. CI validates this stack
without credentials and does not plan or apply DigitalOcean changes.

```sh
umask 077
mise exec -- terraform -chdir=stacks/weblate plan -input=false -out=tfplan
```

The verified initial plan is **4 imports, 0 creates, 1 in-place update,
0 destroys**. Provider 2.100.0 does not read `backup_policy` into imported state,
so the one update explicitly reapplies the already-verified `daily` / hour `8`
policy; it also records the local `graceful_shutdown=false` default. This is not
a zero-change plan. Its backup-policy read limitation also means a clean future
Terraform plan alone does not prove the live schedule: verify it separately with
`doctl compute droplet backup-policies get 600537369`.

The import API reports the OS image as `ubuntu-24-04-x64`, so the configuration
uses that slug; specifying the original image ID `235153036` instead caused a
replacement proposal and was rejected by `prevent_destroy` during validation.
Keep that guard in place. Rebuilds need a separate recovery plan and data restore.

All four managed resources have `prevent_destroy`. Creation-only `ssh_keys` and
`user_data` are ignored after adoption because the API cannot recover them and
the original cloud-init predates live SSH hardening. The checked-in hardened
template is rendered for new provisioning, but editing it does not change this
running host. Restrict SSH to the current administrator IPv4 `/32` in both the
cloud firewall and host UFW. When changing IP, establish console/existing SSH
access and update host UFW before applying the cloud rule; confirm a second SSH
session before removing the old host rule.

Before the first apply, configure an encrypted, access-controlled shared backend
with locking for this stack, initialize it, and generate a fresh reviewed plan.
This repository has no selected production state backend yet. Do not apply the
local validation plan or use the existing GitHub workspace for this stack.
Import blocks are repeatable once the resources are in that state. Never commit
state or saved plans; they are ignored, and should still be treated as sensitive.

Provider references:
[Droplet](https://registry.terraform.io/providers/digitalocean/digitalocean/2.100.0/docs/resources/droplet),
[project](https://registry.terraform.io/providers/digitalocean/digitalocean/2.100.0/docs/resources/project),
[provider import/read implementation](https://github.com/digitalocean/terraform-provider-digitalocean/blob/v2.100.0/digitalocean/droplet/resource_droplet.go).

## Application and integration handoff

The host uses `kadupul-admin` with key-only SSH and sudo. Root SSH and password
authentication are disabled. Files live in `/opt/kadupul-weblate`; secrets live
in `/etc/kadupul-weblate/secrets` (root-only directory). The active stack uses
base `compose.yaml`, with outgoing email disabled and registration closed.
Do not add the initial-admin bootstrap override to routine restarts: it resets
the admin credential. Its server-side password file was removed after login
verification. The admin credential remains in macOS **Keychain Access**, login
keychain, service `kadupul-weblate-admin`, account `admin`, label
`Kadupul Weblate administrator`; it may not appear in the Passwords app.

Caddy terminates origin TLS and Weblate trusts only Caddy's fixed container IP.
Cloudflare is a DNS/proxy service here, not an access-control boundary. Origin
80/443 are public; Weblate itself authenticates access. See the deployment
runbook before adding any Cloudflare-only access controls or enabling SMTP.

The GitHub App **Kadupul Translations** (`kadupul-translations`, App ID `4957563`)
has installation `162017500`, limited to **kadupulhq/website**. Permissions are
`contents:write`, `pull_requests:write`, `metadata:read`; workflow-write and
organization-administration access were removed. App secrets remain solely in
Weblate's database. Its workspace is Kadupul, ID
`535512a7-4893-4be1-b84d-7c682b9b638e`.

The [site-label component](https://translate.kadupul.net/projects/kadupul/site/)
tracks `https://github.com/kadupulhq/website.git`, branch `main`, with GitHub App
VCS, editing unlocked and push-on-commit enabled. The backend creates PRs through
`weblate-kadupul-site`; it does not push directly to `main`. The live source was
verified against website merge commit `1faa4b9f51c976c6f8c63e6c1df982265da6ca86`.
File mask is `translations/site/*.json`, source template
`translations/site/en.json`, format JSON, source language English. Translation
review is enabled; new-language creation and shared translation memory are off.

There are **22 catalogs / 330 site-label units**, including `en`, `zh-cn`, `hi`,
`es`, `ar`, `fr`, `de`, `ja`, `es-419`, `fr-ca`, `sw`, `ha`, `pt-pt`, `pt-br`,
`yo`, `it`, `ko`, `id`, `nl`, `pl`, `bn`, and `si`. Regional catalogs use those
lowercase BCP-47 filenames, while Weblate may display internal codes such as
`es_419`, `fr_CA`, `pt_BR`, `pt_PT` and `zh_Hans`. Translations remain drafts
until fluent review; automated language support is not evidence of approval.

A real App push/PR round trip was verified with [website PR #5](https://github.com/kadupulhq/website/pull/5),
then reverted and closed with no final content changes. The temporary branch was
removed. Webhooks returned successful responses. The website's default-branch
ruleset `22963676` requires `build` and `SonarCloud Code Analysis`, strict status
checks and PRs, with no bypass actors. Those existing settings are documented
here, not changed by this DigitalOcean stack; do not use the separate GitHub
root's generic ruleset as an exact representation of those live settings.

## Evidence and remaining work

- Public HTTPS, origin TLS, admin login after restart and Django deployment
  checks passed. Editing, PR synchronization and the disabled email backend were
  rechecked during this capture.
- First DigitalOcean backup: `245565731`, completed 2026-09-15 08:28 UTC. Daily
  policy and project assignment were rechecked through the API.
- The database backup service succeeded. A dump restored into an isolated
  temporary database reproduced 330 units and two components; that database was
  removed. This is a database restore test, not a full Droplet recovery test.
- The six backup tests exercise readiness retries, successful
  publication/permissions/retention, dump failure, invalid archive failure, and
  interrupted publication, plus recovery of stale partial archives. Website PR #4's
  [final CI run](https://github.com/kadupulhq/website/actions/runs/35021872323)
  separately passed 83 tests (including the interruption regression) with 100%
  measured first-party JS/TS/Astro coverage; that percentage does not measure
  Terraform or shell paths in this repository.
- Full Droplet restore, external alerts/error collection, enabled email and a
  complete contributor-to-fluent-review-to-export workflow remain pending.
- [Website issue #3](https://github.com/kadupulhq/website/issues/3) tracks broader
  Weblate migration, regional inheritance, reviewer history export and content
  validation. It remains open. Read the website's
  [translation guide](https://github.com/kadupulhq/website/blob/main/TRANSLATING.md)
  for catalog/source-hash checks and generated runtime artifacts.

At deployment, the verified size was $24/month plus 30% daily backups ($31.20
before tax and overages). This is a dated estimate, not a price guarantee. There
is no managed database, extra volume, load balancer or AI-provider subscription
in this setup. Email and recovery-test resources are not included.
