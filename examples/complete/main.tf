module "tailscale_subnet_router" {
  source = "../.."

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
