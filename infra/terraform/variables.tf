variable "do_token" {
  description = "DigitalOcean API token."
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Short project name used in resource names and tags."
  type        = string
  default     = "safe"
}

variable "environment" {
  description = "Environment suffix used in resource names."
  type        = string
  default     = "sandbox"
}

variable "region" {
  description = "DigitalOcean region slug."
  type        = string
  default     = "nyc3"
}

variable "droplet_size" {
  description = "DigitalOcean droplet size slug."
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "droplet_image" {
  description = "Droplet image slug."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the VPC network."
  type        = string
  default     = "10.20.0.0/16"
}

variable "ssh_public_key" {
  description = "Public SSH key content used for root access to the droplet."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Local private key path for the generated bootstrap command."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH into the droplet."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_backups" {
  description = "Whether to enable automatic droplet backups."
  type        = bool
  default     = false
}

variable "extra_tags" {
  description = "Additional tags to attach to created resources."
  type        = list(string)
  default     = []
}
