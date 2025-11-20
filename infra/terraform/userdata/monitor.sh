#!/bin/bash
set -euxo pipefail
dnf install -y awscli amazon-ssm-agent python3
systemctl enable --now amazon-ssm-agent || true
echo 'Monitoring host initialized (Ansible will install Prometheus/Grafana/Alertmanager)'
