output "droplet_name" {
  description = "Created droplet name."
  value       = digitalocean_droplet.safe.name
}

output "droplet_ipv4_address" {
  description = "Public IPv4 address of the runner droplet."
  value       = digitalocean_droplet.safe.ipv4_address
}

output "vpc_id" {
  description = "ID of the VPC created for safe runtime resources."
  value       = digitalocean_vpc.safe.id
}

output "bootstrap_command" {
  description = "Command to run from the safe control-plane repo after apply."
  value       = "TARGET_HOST=${digitalocean_droplet.safe.ipv4_address} TARGET_USER=root SSH_KEY=${var.ssh_private_key_path} bash LINUX/bootstrap_remote.sh"
}
