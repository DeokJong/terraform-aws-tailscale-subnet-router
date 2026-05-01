output "instance_id" {
  description = "EC2 instance ID currently fulfilling the Spot request."
  value       = try(aws_spot_instance_request.subnet_router[0].spot_instance_id, aws_instance.subnet_router[0].id, null)
}

output "spot_instance_id" {
  description = "EC2 instance ID currently fulfilling the Spot request. Null when spot_options.enabled is false."
  value       = try(aws_spot_instance_request.subnet_router[0].spot_instance_id, null)
}

output "spot_request_id" {
  description = "Spot instance request ID. Null when spot_options.enabled is false."
  value       = try(aws_spot_instance_request.subnet_router[0].id, null)
}

output "security_group_id" {
  description = "Security group ID attached to the subnet router."
  value       = aws_security_group.subnet_router.id
}

output "iam_role_name" {
  description = "IAM role name attached to the subnet router instance profile."
  value       = aws_iam_role.subnet_router.name
}

output "iam_instance_profile_name" {
  description = "IAM instance profile name attached to the subnet router."
  value       = aws_iam_instance_profile.subnet_router.name
}

output "authkey_ssm_name" {
  description = "SSM parameter name used by user data to read the Tailscale auth key."
  value       = local.authkey_ssm_name
}

output "advertise_routes" {
  description = "CIDR blocks advertised through Tailscale."
  value       = local.advertise_routes
}

output "instance_subnet_id" {
  description = "Subnet ID selected for the EC2 instance."
  value       = var.instance_subnet_id
}
