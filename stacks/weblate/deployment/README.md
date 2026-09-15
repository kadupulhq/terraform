# DigitalOcean Weblate deployment

Status: server provisioned in the owner-selected Relenz DigitalOcean team;
Weblate is deployed at `https://translate.kadupul.net`; outgoing email is
intentionally disabled. GitHub App repository access and a test push/PR round
trip are verified; production editing and PR synchronization now track `main`.
The separate Kadupul project is `2d803cfc-9618-4830-9627-9a6c206d7ada`.
The hostname is `translate.kadupul.net`. DNS uses the Cloudflare proxy, with origin `64.23.171.186`. The owner chose to defer email configuration.

## Provisioned server

- Droplet: `kadupul-weblate-01`, ID `600537369`, IPv4 `64.23.171.186`.
- Cloud firewall: `f33c3d71-c246-45f8-a8a1-96a8db96bce2`, dedicated tag
  `kadupul-weblate`. Cloud and host SSH rules use the same administrator IP.
- SSH: `kadupul-admin` using the owner's existing `m3 laptop` key; root SSH,
  password and keyboard-interactive login disabled. Sudo access verified. Update both allowlists if the administrator's public IP changes.
- Daily backup policy confirmed: 08:00–12:00 UTC window, seven-day retention.
  First Droplet backup completed at 2026-09-15 08:28 UTC (ID `245565731`).
  Full Droplet restore validation remains pending.
- Cloud-init completed successfully; user-data schema validated. Docker and the
  DigitalOcean monitoring agent are active. Alert policies remain pending.
- Configuration is at `/opt/kadupul-weblate`; secrets are in the root-only
  directory documented below. The administrator credential is in the owner's
  macOS Keychain, service `kadupul-weblate-admin`, account `admin`.
- Outgoing email uses Django's dummy backend. No email is sent or logged;
  invitations and password-reset delivery are unavailable. Registration is closed.
- Configured DNS record: `translate.kadupul.net A 64.23.171.186`.

## Resource plan

| Resource | Configuration |
| --- | --- |
| Project | Separate Kadupul project in the selected team |
| Droplet | `kadupul-weblate-01`, Ubuntu 24.04 LTS, `sfo3` |
| Size | `s-2vcpu-4gb`: 2 vCPUs, 4 GB RAM, 80 GB SSD |
| Backups | Daily DigitalOcean backups and an explicit daily database-dump timer |
| Monitoring | DigitalOcean monitoring agent active; disk, memory and health alerts pending |
| Network | TCP 80/443 public; TCP 22 restricted to administrator IPs in the cloud firewall |
| DNS | A record `translate.kadupul.net` pointing to the new Droplet |

The checked account currently offers this size at $24/month. Basic daily backups
add 30%, for $31.20/month before tax, email service fees and any usage overages.
No managed database, load balancer, extra volume or paid AI provider is required
for the initial deployment. DNS is configured through Cloudflare. Email configuration is intentionally deferred.

## Configuration

The Compose stack uses immutable image digests verified from the registries:
Weblate 2026.9.1.0, PostgreSQL 18, Valkey 9.1.2 and Caddy 2.11.4. Caddy terminates
HTTPS. Weblate has no published port; it trusts only Caddy's fixed container IP.
The database and cache are on an internal network without published ports.
Origin HTTPS remains publicly reachable, including directly by IP with the
correct hostname. Cloudflare currently provides DNS/proxy service, not an access
control boundary: Weblate itself enforces authentication and permissions. No
Cloudflare-only access or WAF protection is claimed. If such controls are added,
restrict origin ingress to Cloudflare or require authenticated origin connections
before relying on them.
Check that `172.30.91.0/24` does not conflict with the selected host's networks.

Keep this deployment directory on the server at `/opt/kadupul-weblate`. Copy
`.env.example` to `.env` there and replace its non-secret settings. SMTP expects STARTTLS on an explicitly selected provider-supported port.
DigitalOcean blocks ports 25, 465 and 587. The example uses 2525; verify that the
chosen provider supports STARTTLS there, or configure its supported alternative.
Do not deploy the example SMTP hostname or assume email delivery works. Store passwords in `/etc/kadupul-weblate/secrets`, outside Git:

- `db_password`: a generated database password shared by PostgreSQL and Weblate.
- `admin_password`: a generated initial administrator password.
- `smtp_password`: only required when enabling the optional SMTP configuration.

The secrets directory must be owned by root with mode 0700. Compose mounts only
the named secret files into the containers, read-only. Their contents must be
readable by container users (mode 0444 inside the root-only host directory).
Keep the admin credential in the owner's password manager or Keychain and never
print it in terminal output. Use `compose.bootstrap.yaml` only for initial administrator creation: supplying
the password on each startup resets the account to that credential. Verify admin
login, then recreate Weblate with only the base Compose file and delete the
bootstrap secret from the server. Retain the credential in Keychain.

Never put credentials in cloud-init user-data, repository files, command-line
arguments or logs. Weblate data and backups contain credentials and must be
treated as sensitive. Registrations remain closed during setup.

## Provisioning sequence

1. Confirm the DigitalOcean team, create a separate Kadupul project, and choose an
   administrator SSH key whose private key is available to the owner.
2. Create a cloud firewall for a dedicated Weblate tag. Allow public TCP 80/443,
   allow TCP 22 only from administrator IP ranges, and allow required outbound
   traffic. Do not attach it to existing unrelated Droplets.
3. Create the Droplet in that project with the selected SSH key, monitoring,
   daily backups and a rendered copy of `cloud-init.yaml`. Replace the literal
   `ADMIN_SSH_CIDR` with the same administrator CIDR used by the cloud firewall
   and `ADMIN_SSH_PUBLIC_KEY` with the owner's public SSH key (never the private
   key) before passing the file as user-data. Never pass the unrendered template.
   The cloud-init file contains no secrets. If the administrator IP changes,
   update both firewall allowlists through an existing SSH session or the console.
4. Wait for `cloud-init status --wait` to succeed. Confirm SSH key access,
   firewall rules, Docker startup, disk capacity, memory and backup policy.
5. Stage non-secret deployment files in `/home/kadupul-admin`, then use
   `sudo install -o root -g root -m 0644` to install them under
   `/opt/kadupul-weblate` (use mode 0600 for `.env`). Send generated secrets
   through SSH standard input to a privileged installer with `sudo`; write them
   directly inside `/etc/kadupul-weblate/secrets`, without staging plaintext
   secrets in the user home directory. Keep that directory root-owned 0700 and
   secret files root-owned 0444. Use the owner's existing secret store as the source
   for external credentials. Generate the database and bootstrap admin passwords
   without printing them.
6. Have the DNS owner create the A record. Check its public resolution and any
   inherited CAA restrictions before requesting the HTTPS certificate.
7. From `/opt/kadupul-weblate`, run `sudo docker compose config --quiet`,
   `sudo docker compose pull`, and for the first start only,
   `sudo docker compose -f compose.yaml -f compose.bootstrap.yaml up -d`. After verifying
   admin access, run `sudo docker compose -f compose.yaml up -d` to remove the bootstrap
   password mount and prevent password resets on future restarts. Do not print rendered Compose
   configuration after adding secrets through any local overrides.
8. Validate HTTPS, administrator login and `sudo docker compose exec --user weblate
   weblate weblate check --deploy`. Resolve actionable failures before inviting
   contributors. Do not silence deployment checks merely to obtain a clean result.
9. Email is disabled for the initial deployment. When enabled later, verify the
   email provider configuration and ask the owner to authorize a test
   message before sending one. Invitations and password resets remain unverified
   until an authorized message is delivered.
10. Configure the GitHub integration with access limited to `kadupulhq/website`,
    PR-based synchronization and reviewer permissions as described in
    [TRANSLATING.md](https://github.com/kadupulhq/website/blob/main/TRANSLATING.md). Complete the live review round trip
    before marking issue #3 complete.

## Deployment checks

The public HTTPS login page, administrator login after restart, and origin TLS
certificate were checked. The bootstrap password mount and server-side bootstrap
secret were removed; the credential remains in Keychain. Django's
`check --deploy` reports no errors or warnings, with two informational notices:
external error collection is not configured, and Weblate's own backup integration
is not configured. DigitalOcean daily backups are enabled separately. An initial
PostgreSQL custom-format dump was created under `/var/backups/kadupul-weblate`
and its archive listing validated. A later scheduled-script dump passed the
isolated database restore test described below; full Droplet recovery is pending.
The default upstream silenced-check list was not changed.

## Enabling email later

The base stack uses `django.core.mail.backends.dummy.EmailBackend`. To enable
email, configure the SMTP variables from `.env.example`, install `smtp_password`
and use `sudo docker compose -f compose.yaml -f compose.smtp.yaml up -d`. Verify a
provider-supported STARTTLS port and sender; do not add the bootstrap override.
Ask the owner before sending a test message. Delivery remains unverified until
an authorized message is received.

## Backups and restore validation

The deployed `kadupul-weblate-backup.timer` runs at 07:00 UTC each day, before
the 08:00–12:00 UTC Droplet backup window. `Persistent=true` catches a missed run
after downtime. Before dumping, the script waits up to five minutes for
PostgreSQL readiness (60 attempts at five-second intervals); a startup failure
retains existing backups and leaves a failed service result. Its service runs `backup-database.sh` as root and records success
or failure in the systemd journal. The script creates a PostgreSQL custom-format
dump, validates its archive listing, then atomically installs the completed file
under `/var/backups/kadupul-weblate/database-<UTC timestamp>.dump` with mode 0600.
Only after success does it prune completed dumps older than seven days. Failed
runs preserve previous dumps. Passwords never appear in process arguments.

Install the script under `/opt/kadupul-weblate` with owner root and mode 0644.
Install the supplied `.service` and `.timer` files under `/etc/systemd/system`,
also root-owned 0644, then run:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now kadupul-weblate-backup.timer
sudo systemctl start kadupul-weblate-backup.service
sudo systemctl show kadupul-weblate-backup.service -p Result -p ExecMainStatus
sudo systemctl list-timers kadupul-weblate-backup.timer
sudo journalctl -u kadupul-weblate-backup.service
```

The first service run succeeded. Its dump was restored into a separate temporary
database, reproducing 330 translation units and two components; the temporary
database was then removed. This database-only test does not replace full Droplet
recovery testing. Failure, cleanup, retention and file-permission checks also
passed with isolated fixtures. Check for a successful run and a nonempty dump
less than 26 hours old during operational checks; outward failure notifications
remain pending while email is disabled. The timer's presence alone is not proof
of a successful backup. The Docker volumes, deployment `.env`, root-only secrets
and database dumps are covered by the whole-Droplet backup.

`WEBLATE_DATABASE_BACKUP=plain` selects Weblate's own on-demand dump format; it
is not relied upon to schedule daily backups. The on-demand
`/app/data/backups/database.sql` was verified separately. DigitalOcean's first
backup completed, but the complete restore test remains pending.

Before relying on backups, restore one to an isolated recovery Droplet with
restricted networking. Keep the restored Weblate application stopped while
checking the database and files so it cannot send mail, push translations or
process duplicate jobs. Verify the administrator account, translation records,
review history, Weblate data directory and a matching database dump. Only then
perform a controlled application test. Record the backup timestamp, restore
duration, tested record counts and result in the operational handoff. Restore
testing and recovery Droplet costs are not included in the base monthly estimate.

For a logical restore into a fresh PostgreSQL instance, use the matching pinned
Compose version, restore the saved Weblate data volume and original secrets,
and load a scheduled `.dump` using `pg_restore --exit-on-error` before starting
Weblate. For an on-demand plain `database.sql`, use `psql --set ON_ERROR_STOP=on`.
Preserve Weblate data ownership (UID 1000). Do not replace a live database or remove
production volumes while testing recovery. A working GitHub repository alone does
not recover Weblate accounts, suggestions or review history.

## Validation and upgrades

The pinned Weblate image's `/app/bin/start` loads `POSTGRES_PASSWORD_FILE`,
`WEBLATE_ADMIN_PASSWORD_FILE` and `WEBLATE_EMAIL_HOST_PASSWORD_FILE` before
initializing the application. This was verified directly in the pinned image;
the file settings are handled by the entrypoint, not Django's settings module.
The password-file mounts are therefore supported without a custom wrapper.

`sudo docker compose --env-file .env.example config --quiet` validates the Compose
model without real credentials. Local model-only validation can omit `sudo`;
operational commands on the server require it because `kadupul-admin` is not in
the Docker group. Proxy configuration can be checked using the
pinned Caddy image with `caddy adapt --validate`. Cloud-init YAML parsing alone
does not prove that Ubuntu provisioning succeeds; record the cloud-init result
on the actual host. Server provisioning, application health, HTTPS and admin
login checks passed. The full restore test has not run yet.

Update image digests deliberately, after taking a backup and testing the new
version. A PostgreSQL major-version change requires a planned database migration;
replacing the image tag is not an upgrade procedure. Do not configure automatic
container updates. OS security updates run automatically; review reboot needs
and schedule restarts.

Sources: [Weblate Docker installation](https://docs.weblate.org/en/latest/admin/install/docker.html),
[Weblate backups](https://docs.weblate.org/en/latest/admin/backup.html),
[DigitalOcean server pricing](https://www.digitalocean.com/pricing/droplets),
[DigitalOcean backup pricing](https://docs.digitalocean.com/products/backups/details/pricing/),
and [DigitalOcean SMTP restrictions](https://docs.digitalocean.com/support/why-is-smtp-blocked/).
