# SPDX-FileCopyrightText: 2026 Thomas Vincent <thomasvincent@gmail.com>
# SPDX-License-Identifier: MIT

output "url" {
  value = "https://translate.kadupul.net"
}
output "origin_ipv4" {
  value = digitalocean_droplet.weblate.ipv4_address
}
output "ssh_command" {
  value = "ssh kadupul-admin@${digitalocean_droplet.weblate.ipv4_address}"
}
