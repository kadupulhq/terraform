import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, readdirSync, chmodSync, statSync, utimesSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

function fixture(t) {
	const root = mkdtempSync(join(tmpdir(), 'weblate-backup-'));
	t.after(() => rmSync(root, { recursive: true, force: true }));
	const backups = join(root, 'backups');
	mkdirSync(backups);
	const counter = join(root, 'attempts');
	writeFileSync(counter, '0');
	const docker = join(root, 'docker');
	writeFileSync(docker, `#!/bin/sh
case "$*" in
  *pg_isready*) count=$(cat "$READY_COUNTER"); count=$((count + 1)); printf '%s' "$count" > "$READY_COUNTER"; test "$count" -gt "$READY_FAILURES";;
  *pg_dump*) test "$FAIL_AT" != dump || exit 1; printf 'test archive';;
  *pg_restore*) test "$FAIL_AT" != validate || exit 1; cat >/dev/null;;
  *) exit 99;;
esac
`);
	chmodSync(docker, 0o700);
	const sleep = join(root, 'sleep');
	writeFileSync(sleep, '#!/bin/sh\nexit 0\n');
	chmodSync(sleep, 0o700);
	const find = join(root, 'find');
	writeFileSync(find, '#!/bin/sh\nif [ "$FAIL_AT" = signal ]; then kill -TERM "$PPID"; exit 0; fi\nexec /usr/bin/find "$@"\n');
	chmodSync(find, 0o700);
	const original = readFileSync(new URL('../deployment/backup-database.sh', import.meta.url), 'utf8');
	const script = original.replace('cd /opt/kadupul-weblate', `cd '${root}'`)
		.replace('backup_dir=/var/backups/kadupul-weblate', `backup_dir='${backups}'`)
		.replaceAll('/usr/bin/docker', `'${docker}'`);
	assert.ok(!script.includes('/opt/kadupul-weblate') && !script.includes('/var/backups/kadupul-weblate') && !script.includes('/usr/bin/docker'), 'All production paths must be isolated');
	const path = join(root, 'backup.sh');
	writeFileSync(path, script);
	const old = join(backups, 'database-20000101T000000Z.dump');
	writeFileSync(old, 'previous backup');
	const expired = new Date(Date.now() - 9 * 86400000);
	utimesSync(old, expired, expired);
	const run = (env = {}) => spawnSync('/bin/sh', [path], {
		encoding: 'utf8', timeout: 10000,
		env: { ...process.env, PATH: `${root}:${process.env.PATH}`, READY_COUNTER: counter, READY_FAILURES: '0', FAIL_AT: '', ...env },
	});
	return { backups, old, counter, run };
}

test('backup waits for database startup and publishes a private archive before pruning old dumps', (t) => {
	const { backups, counter, run } = fixture(t);
	const result = run({ READY_FAILURES: '2' });
	assert.equal(result.status, 0, result.stderr);
	assert.equal(readFileSync(counter, 'utf8'), '3');
	const files = readdirSync(backups);
	assert.equal(files.length, 1);
	assert.match(files[0], /^database-\d{8}T\d{6}Z\.dump$/);
	assert.equal(readFileSync(join(backups, files[0]), 'utf8'), 'test archive');
	assert.equal(statSync(join(backups, files[0])).mode & 0o777, 0o600);
});

for (const failure of ['dump', 'validate']) {
	test(`backup preserves existing dumps and cleans temporary files when ${failure} fails`, (t) => {
		const { backups, old, run } = fixture(t);
		const result = run({ FAIL_AT: failure });
		assert.notEqual(result.status, 0);
		assert.deepEqual(readdirSync(backups), ['database-20000101T000000Z.dump']);
		assert.equal(readFileSync(old, 'utf8'), 'previous backup');
	});
}

test('backup bounds readiness retries and preserves backups when the database stays unavailable', (t) => {
	const { backups, counter, run } = fixture(t);
	const result = run({ READY_FAILURES: '100' });
	assert.equal(result.status, 1);
	assert.match(result.stderr, /not ready after 60 attempts/);
	assert.equal(readFileSync(counter, 'utf8'), '60');
	assert.deepEqual(readdirSync(backups), ['database-20000101T000000Z.dump']);
});


test('interruption after archive publication exits nonzero without announcing success', (t) => {
	const { backups, run } = fixture(t);
	const result = run({ FAIL_AT: 'signal' });
	assert.equal(result.status, 143);
	assert.doesNotMatch(result.stdout, /backup completed/);
	assert.equal(readdirSync(backups).filter((name) => name.startsWith('database-')).length, 2);
	assert.ok(!readdirSync(backups).some((name) => name.startsWith('.database-')));
});
