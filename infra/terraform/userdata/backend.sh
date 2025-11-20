#!/bin/bash
set -euxo pipefail
# Base tools (avoid curl vs curl-minimal conflicts)
dnf install -y awscli ruby wget dnf-plugins-core python3 || true

# Ensure SSM agent is installed and running (mandatory for Ansible/SSM)
dnf install -y amazon-ssm-agent
systemctl enable --now amazon-ssm-agent

# Docker (Amazon Linux 2023 compatible): try native, then Docker CE repo, then convenience script
if ! command -v docker >/dev/null 2>&1; then
  dnf install -y docker || {
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true
    dnf install -y docker-ce docker-ce-cli containerd.io || curl -fsSL https://get.docker.com | sh
  }
fi
systemctl enable docker && systemctl start docker

# Install/ensure CodeDeploy agent for blue/green deploys
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | sed -n 's/.*"region"\s*:\s*"\([^"]*\)".*/\1/p')
cd /tmp
curl -O https://aws-codedeploy-$${REGION}.s3.$${REGION}.amazonaws.com/latest/install
chmod +x ./install
./install auto || ./install auto
systemctl enable codedeploy-agent || true
systemctl restart codedeploy-agent || true

# Optional backend env file (e.g., MONGO_URI) injected via Terraform template
MONGO_URI_VALUE="${MONGO_URI}"
if [ -n "$MONGO_URI_VALUE" ]; then
  echo "MONGO_URI=$MONGO_URI_VALUE" > /etc/backend.env
fi
# SSM already enabled above; keep idempotency
systemctl enable --now amazon-ssm-agent || true
