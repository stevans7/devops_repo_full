#!/bin/bash
set -euxo pipefail
dnf install -y yum-utils amazon-ssm-agent
cat >/etc/yum.repos.d/mongodb-org-7.0.repo <<'EOF'
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc
EOF
dnf install -y mongodb-org
sed -i 's/^\s*bindIp:.*$/  bindIp: 0.0.0.0/' /etc/mongod.conf || true
systemctl enable mongod && systemctl restart mongod
systemctl enable --now amazon-ssm-agent || true
