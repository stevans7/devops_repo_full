#!/bin/bash
set -euxo pipefail
dnf install -y awscli amazon-ssm-agent
systemctl enable --now amazon-ssm-agent || true
echo 'Monitoring host initialized'
