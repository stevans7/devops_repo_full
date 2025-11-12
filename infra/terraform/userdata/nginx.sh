#!/bin/bash
set -euxo pipefail
yum install -y nginx awscli amazon-ssm-agent
mkdir -p /var/www/app
aws s3 sync s3://${PROJECT}-artifacts/front/current/ /var/www/app/ || true
systemctl enable nginx && systemctl restart nginx
systemctl enable --now amazon-ssm-agent || true
