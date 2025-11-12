# Projet DevOps – Prise de rendez-vous (VM + EKS + HA + CI/CD + Sécurité)

## Architecture
- **Prod**: EC2/ALB (front & back en ASG, min=2), WAF, CodeDeploy blue/green (backend), artefacts S3 (front)
- **Staging**: EKS (Helm chart backend, Ingress), scans & tests avant promotion
- **MongoDB Atlas** (peering VPC), **ECR** (images), **S3** (artefacts/logs/tfstate)

## Déploiement
1. `infra/terraform` → `terraform init` (backend S3) + `terraform apply` (VPC, ALB, ASG, ECR, S3, WAF, EKS, IAM, CodeDeploy)
2. Provision VMs via `infra/ansible/site.yml` (agents, nginx, docker)
3. **Build** (push sur main) → artefacts S3 + image ECR
4. **Staging** auto (Helm EKS) + ZAP baseline
5. **Prod** (tag `vX.Y.Z`) → CodeDeploy backend + sync front S3 → front VMs

## Sécurité
- WAF (AWSManagedRulesCommonRuleSet), TLS via ACM (renseigner `certificate_arn`)
- IAM least-privilege (EC2 SSM/CW/S3/ECR, CodeDeploy role), secrets via Secrets Manager (à brancher)
- CI: CodeQL, npm audit, gitleaks; Images: scan ECR (scan_on_push)

## Observabilité
- CloudWatch Logs/Alarms (EC2/ALB)
- OTel Collector (traces → X-Ray) sur back VMs
- (Staging) Prometheus/Grafana/Loki à ajouter si souhaité

## Variables GitHub Secrets
`AWS_ROLE`, `AWS_REGION`, `AWS_ACCOUNT`, `PROJECT`

## Dossiers
- `frontend/` (static + nginx)
- `backend/` (Node/Express + Dockerfile + CodeDeploy hooks)
- `infra/terraform/` (modules + userdata)
- `infra/ansible/` (roles: codedeploy-agent, nginx, node, cwagent, otel)
- `k8s/charts/rdv/` (Helm backend)
- `.github/workflows/` (CI, Build, Deploy Staging, Deploy Prod)

## Notes
- Remplacer `PROJECT` dans scripts/userdata par le nom réel (ou exporter la variable dans EC2).
- Ajouter `certificate_arn` pour activer HTTPS listener dans le module ALB (facultatif ici).
