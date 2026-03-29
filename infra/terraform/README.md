# Terraform Scaffold For DigitalOcean

This directory provides baseline Terraform scaffolding for the unfinished `safe` objective item:

- create a DigitalOcean VPC
- create a firewall for SSH ingress + outbound egress
- create an Ubuntu 24.04 droplet for the `safe` runtime boundary

After provisioning, bootstrap the host with the existing control-plane script at `LINUX/bootstrap_remote.sh`.

## Prerequisites

- Terraform `>= 1.6`
- DigitalOcean API token with permission to manage Droplets/VPC/Firewalls/SSH keys
- SSH keypair available on the control-plane machine

## Quick Start

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Set your DigitalOcean token as an env var:

```bash
export TF_VAR_do_token="<digitalocean-token>"
```

Then initialize and apply:

```bash
terraform init
terraform plan
terraform apply
```

When apply completes, use the generated output:

```bash
terraform output bootstrap_command
```

Run the printed command from the repo root to install Docker/users/helpers on the new host:

```bash
cd ../..
# paste command from terraform output bootstrap_command
```

## Notes

- `allowed_ssh_cidrs` defaults to `0.0.0.0/0`; tighten this before production use.
- `terraform.tfvars` is gitignored to keep local values and key material out of version control.
- State should be remote-backed (for example, Terraform Cloud or object storage) before team use.
