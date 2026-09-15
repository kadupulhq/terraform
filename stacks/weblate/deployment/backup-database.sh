#!/bin/sh
# Run as root on the Weblate host. Credentials stay inside the database container.
set -eu
umask 077
cd /opt/kadupul-weblate
backup_dir=/var/backups/kadupul-weblate
install -d -m 0700 "$backup_dir"
# Docker can be active before PostgreSQL is ready after a reboot.
attempt=0
until /usr/bin/docker compose exec -T database pg_isready -U weblate -d weblate </dev/null >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 60 ]; then
        printf 'Database was not ready after 60 attempts; previous backups retained.\n' >&2
        exit 1
    fi
    sleep 5
done
# Recover orphaned partial dumps from power loss or an uncatchable signal.
# The service timeout is 30 minutes; keep recent files in case a backup is active.
find "$backup_dir" -maxdepth 1 -type f -name '.database-??????' -mmin +1440 -delete
backup_file="$backup_dir/database-$(date -u +%Y%m%dT%H%M%SZ).dump"
backup_temp=$(mktemp "$backup_dir/.database-XXXXXX")
trap 'rm -f "$backup_temp"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
/usr/bin/docker compose exec -T database pg_dump -U weblate -Fc weblate </dev/null > "$backup_temp"
test -s "$backup_temp"
/usr/bin/docker compose exec -T database pg_restore --list < "$backup_temp" > /dev/null
mv "$backup_temp" "$backup_file"
# Prune only completed dumps, and only after a new dump succeeds.
find "$backup_dir" -maxdepth 1 -type f -name 'database-????????T??????Z.dump' -mmin +10080 -delete
printf 'Database backup completed: %s\n' "$backup_file"
