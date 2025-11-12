# Runbook – Démo et Exploitation

## Pré-requis (WSL Ubuntu)
- Paquets: `sudo apt update && sudo apt install -y terraform ansible awscli unzip jq python3-boto3`
- AWS CLI configuré: `aws configure` (region `eu-central-1`)
- Paire EC2 existante: `soutenace` (clé `.pem` gardée en local)

## Déploiement Infra (Terraform)
1. Se placer dans `infra/terraform`
2. `terraform init -backend-config="bucket=<tf_state_bucket>" -backend-config="key=<project>/tf.state" -backend-config="region=eu-central-1" -backend-config="dynamodb_table=<tf_lock_table>"`
3. `terraform apply -var="project=<project>" -var="tf_state_bucket=<bucket>" -var="tf_lock_table=<table>" -var="ssh_key_name=soutenace" -var="certificate_arn=arn:aws:acm:eu-central-1:..."`

Sorties importantes: `alb_dns_name`, `db_private_ip`, `monitoring_private_ip`.

## Provisionnement VM (Ansible via SSM)
1. Installer collections: `ansible-galaxy collection install -r infra/ansible/requirements.yml`
2. Configurer alertes (Slack/Email) dans `infra/ansible/group_vars/all.yml`:
   - Slack direct: `alertmanager_slack_webhook_url`, `alertmanager_slack_channel`
   - OU Slack via SSM: `alertmanager_slack_webhook_url_ssm_parameter=/prod/alerting/slack_webhook`
   - Email direct: `alertmanager_email_*`
   - OU Email via Secrets Manager (JSON: host,port,username,password,from,to): `alertmanager_email_smtp_secret_arn=arn:...`
3. `ansible-playbook infra/ansible/site.yml -e region=eu-central-1`

## CI/CD (GitHub Actions)
Secrets à créer: `AWS_ROLE`, `AWS_REGION=eu-central-1`, `AWS_ACCOUNT`, `PROJECT=<project>`, `STAGING_PROJECT=<project-staging>`.
- Build (main + tags): image ECR + artefacts S3
- Prod (tag vX.Y.Z): CodeDeploy backend (IN_PLACE) + SSM refresh front
- Staging (manuel): même mécanique, isolée par `STAGING_PROJECT`

## Accès et Tests
- Front: `https://<alb_dns_name>/` (HTTP redirigé 80→443)
- API: `https://<alb_dns_name>/api/` (health `/healthz`)
- Grafana: `https://<alb_dns_name>/grafana/` (admin/admin – à changer)
- Prometheus: via SSM port-forward `9090` vers l’instance monitoring si besoin

Générer une alerte (exemples):
- CPU: sur une VM (via SSM), `yes > /dev/null &` puis observer Slack/Email
- RAM: allouer mémoire ou lancer un stress test

## Sécurité
- HTTPS activé (listener 443 sur ALB), HSTS (incl. preload) côté NGINX et Grafana
- SGs segmentés (ALB/front/back/db/monitoring), MongoDB privé
- SSM pour accès (pas d’IP publique requise)

## Exploitation
- Refresh front manuel (si besoin): `SSM RunCommand` exécute `aws s3 sync ... /var/www/app/ && systemctl reload nginx`
- Déploiement back manuel: créer un ZIP CodeDeploy de `backend/` avec `backend/image.txt` contenant l’image ECR, appeler `aws deploy create-deployment ...`

## Remarques
- CodeDeploy est en déploiement IN_PLACE (serveur). Blue/Green côté serveur nécessite 2 TGs et une config pair; je peux l’activer si requis.
- Le module EKS et le chart Helm existent pour une extension future (non requis en VM/Staging présent).
