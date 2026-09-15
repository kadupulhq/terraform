data "digitalocean_ssh_key" "administrator" {
  name = "m3 laptop"
}

locals {
  # Shared Relenz VPC: referenced, not owned by this stack.
  vpc_uuid = "60a80fc6-4809-4fa4-b8fd-8863cfc1d70d"
  cloud_init = replace(replace(
    file("${path.module}/deployment/cloud-init.yaml"),
    "ADMIN_SSH_CIDR", var.admin_ssh_cidr
  ), "ADMIN_SSH_PUBLIC_KEY", data.digitalocean_ssh_key.administrator.public_key)
}

resource "digitalocean_tag" "weblate" {
  name = "kadupul-weblate"
  lifecycle {
    prevent_destroy = true
  }
}

resource "digitalocean_droplet" "weblate" {
  name       = "kadupul-weblate-01"
  region     = "sfo3"
  size       = "s-2vcpu-4gb"
  image      = "ubuntu-24-04-x64" # Import API returns the slug, not image ID 235153036.
  vpc_uuid   = local.vpc_uuid
  ipv6       = false
  monitoring = true
  backups    = true
  ssh_keys   = [data.digitalocean_ssh_key.administrator.id]
  user_data  = local.cloud_init
  tags       = [digitalocean_tag.weblate.name]

  backup_policy {
    plan = "daily"
    hour = 8
  }

  lifecycle {
    prevent_destroy = true
    # These creation-only fields cannot be recovered through the import API.
    # The original user-data predates live SSH hardening; replacing it would
    # replace the server. Future host changes require the runbook's SSH steps.
    ignore_changes = [ssh_keys, user_data]
  }
}

resource "digitalocean_project" "kadupul" {
  name        = "Kadupul"
  description = "Kadupul open-source project infrastructure"
  purpose     = "Operational / Developer tooling"
  environment = "Production"
  resources   = [digitalocean_droplet.weblate.urn]
  lifecycle {
    prevent_destroy = true
    postcondition {
      condition     = self.owner_uuid == "3b2f3d4514494e62ac337d6221ba474dbf02a36d"
      error_message = "The Kadupul project must belong to the selected Relenz team."
    }
  }
}

resource "digitalocean_firewall" "weblate" {
  name = "kadupul-weblate"
  tags = [digitalocean_tag.weblate.name]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = [var.admin_ssh_cidr]
  }
  dynamic "inbound_rule" {
    for_each = ["80", "443"]
    content {
      protocol         = "tcp"
      port_range       = inbound_rule.value
      source_addresses = ["0.0.0.0/0"]
    }
  }
  dynamic "outbound_rule" {
    for_each = ["tcp", "udp"]
    content {
      protocol              = outbound_rule.value
      port_range            = "1-65535"
      destination_addresses = ["0.0.0.0/0"]
    }
  }
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0"]
  }
  lifecycle {
    prevent_destroy = true
  }
}
