variable "vpc_id" {
  type        = string
  description = "VPC ID where the Tailscale subnet router will be deployed."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name used for the EC2 instance, IAM resources, security group, and tags."
  default     = "tailscale-subnet-router"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the subnet router."
  default     = "t3.micro"
}

variable "tailscale_extra_args" {
  type        = list(string)
  description = "Additional arguments passed to tailscale up."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to supported resources."
  default     = {}
}

variable "spot_options" {
  type = object({
    enabled                        = optional(bool, true)
    instance_interruption_behavior = optional(string, "terminate")
    type                           = optional(string, "persistent")
    price                          = optional(string)
  })
  description = "Spot instance options. Set enabled to false to use an on-demand EC2 instance."
  default     = {}

  validation {
    condition     = contains(["terminate", "stop", "hibernate"], var.spot_options.instance_interruption_behavior)
    error_message = "spot_options.instance_interruption_behavior must be one of: terminate, stop, hibernate."
  }

  validation {
    condition     = contains(["persistent", "one-time"], var.spot_options.type)
    error_message = "spot_options.type must be one of: persistent, one-time."
  }
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Whether to associate a public IPv4 address with the EC2 instance."
  default     = true
}

variable "instance_subnet_id" {
  type        = string
  description = "Subnet ID where the Tailscale subnet router EC2 instance will be deployed."
  nullable    = false
}

variable "advertise_routes" {
  type        = list(string)
  description = "CIDR routes to advertise through Tailscale."
  nullable    = false

  validation {
    condition     = length(var.advertise_routes) > 0
    error_message = "advertise_routes must contain at least one CIDR block."
  }

  validation {
    condition = alltrue([
      for route in var.advertise_routes : can(cidrhost(route, 0))
    ])
    error_message = "advertise_routes must contain only valid CIDR blocks."
  }
}

variable "create_authkey_ssm" {
  type        = bool
  description = "Whether this module should create an SSM SecureString placeholder for the Tailscale auth key."
  default     = true
}

variable "authkey_ssm_name" {
  type        = string
  description = "SSM parameter name to create when create_authkey_ssm is true."
  default     = "tailscale_auth_key"
}

variable "custom_authkey_ssm_name" {
  type        = string
  description = "Existing SSM parameter name to read when create_authkey_ssm is false."
  default     = null

  validation {
    condition     = var.create_authkey_ssm || var.custom_authkey_ssm_name != null
    error_message = "custom_authkey_ssm_name must be set when create_authkey_ssm is false."
  }
}
