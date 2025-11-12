#!/bin/bash
set -euxo pipefail
yum install -y docker awscli ruby wget curl amazon-ssm-agent
systemctl enable docker && systemctl start docker

# Install/ensure CodeDeploy agent for blue/green deploys
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | sed -n 's/.*"region"\s*:\s*"\([^"]*\)".*/\1/p')
cd /tmp
curl -O https://aws-codedeploy-${REGION}.s3.${REGION}.amazonaws.com/latest/install
chmod +x ./install
./install auto || ./install auto
systemctl enable codedeploy-agent && systemctl restart codedeploy-agent

# Optional backend env file (e.g., MONGO_URI) injected via Terraform template
MONGO_URI_VALUE="${MONGO_URI}"
if [ -n "$MONGO_URI_VALUE" ]; then
  echo "MONGO_URI=$MONGO_URI_VALUE" > /etc/backend.env
fi
systemctl enable --now amazon-ssm-agent || true
