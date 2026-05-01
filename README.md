# terraform-aws-tailscale-subnet-router

Terraform module that creates an EC2-based Tailscale subnet router for an AWS VPC.

The module creates:

- EC2 instance or persistent Spot Instance Request
- Security group with no inbound rules and outbound internet access
- IAM role and instance profile for reading a Tailscale auth key from SSM Parameter Store
- Optional SSM SecureString placeholder for the Tailscale auth key
- User data that installs Tailscale, enables IP forwarding, and advertises routes

## Usage

```hcl
module "tailscale_subnet_router" {
  source = "DeokJong/tailscale-subnet-router/aws"

  name               = "tailscale-subnet-router"
  vpc_id             = "vpc-xxxxxxxxxxxxxxxxx"
  instance_subnet_id = "subnet-xxxxxxxxxxxxxxxxx"

  advertise_routes = [
    "10.0.0.2/32",
    "10.0.128.0/20",
    "10.0.144.0/20",
    "10.0.160.0/20",
  ]

  create_authkey_ssm      = false
  custom_authkey_ssm_name = "/foundation/tailscale-subnet-router/ts-authkey"

  spot_options = {
    enabled = true
  }

  tags = {
    Project = "foundation"
  }
}
```

## Tailscale Auth Key

If `create_authkey_ssm = true`, this module creates a SecureString placeholder with a write-only dummy value. The real auth key should be written outside Terraform to avoid storing it in Terraform configuration or state:

```bash
aws ssm put-parameter \
  --name /foundation/tailscale-subnet-router/ts-authkey \
  --type SecureString \
  --value "tskey-auth-..." \
  --overwrite
```

If `create_authkey_ssm = false`, provide `custom_authkey_ssm_name`.

## Tailscale ACL

For unattended subnet routing, use a tagged auth key and configure route auto-approval in your tailnet ACL. Example:

```json
{
  "autoApprovers": {
    "routes": {
      "10.0.0.0/16": ["tag:aws-subnet-router"]
    }
  }
}
```

## DNS

For AWS Route 53 private hosted zones, clients often need access to the VPC resolver address. In a `10.0.0.0/16` VPC, that address is usually `10.0.0.2`, so include `10.0.0.2/32` in `advertise_routes` when using Tailscale split DNS for private Route 53 zones.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpc_id | VPC ID where the subnet router will be deployed. | `string` | n/a | yes |
| instance_subnet_id | Subnet ID where the EC2 instance will be deployed. | `string` | n/a | yes |
| advertise_routes | CIDR routes to advertise through Tailscale. | `list(string)` | n/a | yes |
| name | Name used for resources and Tailscale hostname. | `string` | `"tailscale-subnet-router"` | no |
| instance_type | EC2 instance type. | `string` | `"t3.micro"` | no |
| associate_public_ip_address | Whether to associate a public IPv4 address. | `bool` | `true` | no |
| tailscale_extra_args | Additional arguments passed to `tailscale up`. | `list(string)` | `[]` | no |
| spot_options | Spot instance options. Set `enabled = false` for On-Demand. | `object` | `{}` | no |
| create_authkey_ssm | Whether to create an SSM SecureString placeholder. | `bool` | `true` | no |
| authkey_ssm_name | SSM parameter name to create when `create_authkey_ssm` is true. | `string` | `"tailscale_auth_key"` | no |
| custom_authkey_ssm_name | Existing SSM parameter name when `create_authkey_ssm` is false. | `string` | `null` | no |
| tags | Tags to apply to supported resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | EC2 instance ID currently fulfilling the router. |
| spot_instance_id | EC2 instance ID currently fulfilling the Spot request. |
| spot_request_id | Spot instance request ID. |
| security_group_id | Security group ID attached to the router. |
| iam_role_name | IAM role name. |
| iam_instance_profile_name | IAM instance profile name. |
| authkey_ssm_name | SSM parameter name used by user data. |
| advertise_routes | CIDR blocks advertised through Tailscale. |
| instance_subnet_id | Subnet ID used by the instance. |
