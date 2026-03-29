terraform {
  required_version = ">= 1.6.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  tags        = distinct(concat([var.project_name, var.environment, "safe"], var.extra_tags))
}

resource "digitalocean_ssh_key" "control_plane" {
  name       = "${local.name_prefix}-control"
  public_key = var.ssh_public_key
}

resource "digitalocean_vpc" "safe" {
  name    = "${local.name_prefix}-vpc"
  region  = var.region
  ip_range = var.vpc_cidr
}

resource "digitalocean_droplet" "safe" {
  name      = "${local.name_prefix}-runner"
  region    = var.region
  size      = var.droplet_size
  image     = var.droplet_image
  vpc_uuid  = digitalocean_vpc.safe.id
  ssh_keys  = [digitalocean_ssh_key.control_plane.fingerprint]
  monitoring = true
  ipv6       = false
  backups    = var.enable_backups
  tags       = local.tags

  # Preseed Python so Ansible bootstrap can run immediately.
  user_data = <<-EOT
    #cloud-config
    package_update: true
    packages:
      - python3
      - python3-venv
      - python3-pip
      - ca-certificates
      - curl
      - git
  EOT
}

resource "digitalocean_firewall" "safe" {
  name = "${local.name_prefix}-fw"

  droplet_ids = [digitalocean_droplet.safe.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.allowed_ssh_cidrs
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
