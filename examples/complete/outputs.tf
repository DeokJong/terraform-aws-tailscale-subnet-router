output "instance_id" {
  description = "EC2 instance ID currently fulfilling the router."
  value       = module.tailscale_subnet_router.instance_id
}

output "security_group_id" {
  description = "Security group ID attached to the router."
  value       = module.tailscale_subnet_router.security_group_id
}

output "authkey_ssm_name" {
  description = "SSM parameter name used by the router."
  value       = module.tailscale_subnet_router.authkey_ssm_name
}
