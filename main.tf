data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  aws_region       = data.aws_region.current.region
  advertise_routes = sort(distinct(var.advertise_routes))
  authkey_ssm_name = var.create_authkey_ssm ? aws_ssm_parameter.ts_auth_key[0].name : var.custom_authkey_ssm_name
  authkey_ssm_arn  = "arn:${data.aws_partition.current.partition}:ssm:${local.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${startswith(local.authkey_ssm_name, "/") ? local.authkey_ssm_name : "/${local.authkey_ssm_name}"}"

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    dnf update -y
    dnf install -y awscli

    curl -fsSL https://tailscale.com/install.sh | sh

    printf '%s\n' \
      'net.ipv4.ip_forward = 1' \
      'net.ipv6.conf.all.forwarding = 1' \
      >/etc/sysctl.d/99-tailscale-subnet-router.conf
    sysctl --system

    systemctl enable --now tailscaled

    TS_AUTH_KEY="$(aws ssm get-parameter \
      --region "${local.aws_region}" \
      --name "${local.authkey_ssm_name}" \
      --with-decryption \
      --query 'Parameter.Value' \
      --output text)"

    tailscale up \
      --authkey "$TS_AUTH_KEY" \
      --advertise-routes="${join(",", local.advertise_routes)}" \
      --hostname="${var.name}" \
      --accept-dns=false${length(var.tailscale_extra_args) > 0 ? " \\\n      ${join(" \\\n      ", var.tailscale_extra_args)}" : ""}
  EOF
}

resource "aws_iam_instance_profile" "subnet_router" {
  name = var.name
  role = aws_iam_role.subnet_router.name
}

resource "aws_iam_role" "subnet_router" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.subnet_router_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "subnet_router_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "subnet_router" {
  name   = var.name
  role   = aws_iam_role.subnet_router.id
  policy = data.aws_iam_policy_document.subnet_router.json
}

resource "aws_iam_role_policy_attachment" "subnet_router_ssm_managed_instance_core" {
  role       = aws_iam_role.subnet_router.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "subnet_router" {
  statement {
    sid    = "ReadTailscaleAuthKey"
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
    ]

    resources = [
      local.authkey_ssm_arn,
    ]
  }
}

resource "aws_ssm_parameter" "ts_auth_key" {
  count = var.create_authkey_ssm ? 1 : 0

  name             = var.authkey_ssm_name
  description      = "tailscale subnet node auth key"
  type             = "SecureString"
  value_wo         = "DUMMY"
  value_wo_version = 1
  tags             = var.tags

  lifecycle {
    ignore_changes = [
      value_wo,
      value_wo_version
    ]
  }
}

resource "aws_security_group" "subnet_router" {
  name        = var.name
  description = "Tailscale subnet router with no inbound internet access"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_vpc_security_group_egress_rule" "ipv4_all" {
  security_group_id = aws_security_group.subnet_router.id
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow outbound internet access for Tailscale and package installation"
  ip_protocol       = "-1"

  tags = merge(var.tags, {
    Name = "${var.name}-ipv4_all"
  })
}

resource "aws_spot_instance_request" "subnet_router" {
  count = var.spot_options.enabled ? 1 : 0

  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.instance_subnet_id
  associate_public_ip_address = var.associate_public_ip_address
  source_dest_check           = false
  iam_instance_profile        = aws_iam_instance_profile.subnet_router.name
  vpc_security_group_ids      = [aws_security_group.subnet_router.id]
  user_data                   = local.user_data
  wait_for_fulfillment        = true

  instance_interruption_behavior = var.spot_options.instance_interruption_behavior
  spot_price                     = var.spot_options.price
  spot_type                      = var.spot_options.type

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  lifecycle {
    ignore_changes = [
      source_dest_check,
    ]
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_instance" "subnet_router" {
  count = var.spot_options.enabled ? 0 : 1

  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.instance_subnet_id
  associate_public_ip_address = var.associate_public_ip_address
  source_dest_check           = false
  iam_instance_profile        = aws_iam_instance_profile.subnet_router.name
  vpc_security_group_ids      = [aws_security_group.subnet_router.id]
  user_data                   = local.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_ec2_tag" "spot_instance_name" {
  for_each = var.spot_options.enabled ? { Name = var.name } : {}

  resource_id = aws_spot_instance_request.subnet_router[0].spot_instance_id
  key         = each.key
  value       = each.value
}
