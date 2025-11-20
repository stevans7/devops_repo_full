#!/bin/bash
set -euxo pipefail
dnf install -y nginx awscli amazon-ssm-agent python3
mkdir -p /var/www/app
aws s3 sync s3://${PROJECT}-artifacts/front/current/ /var/www/app/ || true
cat >/etc/nginx/conf.d/app.conf <<'CONF'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/app;
    index index.html index.htm;
    location / {
        try_files $uri $uri/ =404;
    }
}
CONF
rm -f /etc/nginx/conf.d/default.conf || true
systemctl enable nginx && systemctl restart nginx
systemctl enable --now amazon-ssm-agent || true
