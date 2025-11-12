# Guide Pas-à-Pas – Déploiement, CI/CD, Supervision et Alertes (Production + Staging)

Ce guide extrêmement détaillé décrit chaque action (clics AWS Console, commandes WSL, chemins exacts) pour déployer l’infrastructure, configurer les pipelines, publier l’application, activer la supervision et tester les alertes.

Prérequis globaux
- Compte AWS (avec droits administrateur pour la mise en place initiale)
- Un dépôt GitHub contenant ce projet (fork/clone)
- Poste Windows 10/11 avec WSL2 (Ubuntu) installé
- Un nom de projet court (ex: `monprojet`) et une région: `eu-central-1`

Nomenclature
- REGION: `eu-central-1`
- PROJECT: votre nom de projet (ex: `monprojet`)
- STAGING_PROJECT: projet staging (ex: `monprojet-staging`)
- KEY PAIR: `soutenace`

---

## 1) Préparation du poste (Windows + WSL Ubuntu)

1. Ouvrir Microsoft Store → rechercher “Ubuntu” → Installer “Ubuntu 22.04 LTS”.
2. Démarrer Ubuntu (menu Démarrer → Ubuntu) → créer l’utilisateur Linux.
3. Mettre à jour et installer outils indispensables:
   - Terminal WSL (Ubuntu):
     ```bash
     sudo apt update && sudo apt install -y terraform ansible awscli unzip jq python3-boto3 git
     ```
4. Cloner le dépôt dans WSL (en utilisant le chemin monté Windows si votre code est dans C:\):
   - Terminal WSL (Ubuntu):
     ```bash
     cd /mnt/c/Users/<VotreUtilisateurWindows>/Downloads
     git clone <URL_GITHUB_DU_DEPOT> devops_repo_full
     cd devops_repo_full
     ```

Vérification: la commande `ls -la` doit montrer les dossiers `.github`, `backend`, `frontend`, `infra`, `docs`, etc.

---

## 2) Préparation AWS (Console + CLI)

A. Créer une paire de clés EC2 (si non existante) nommée `soutenace` en eu-central-1
- AWS Console → EC2 → dans le menu latéral gauche: Network & Security → Key Pairs → bouton “Create key pair”.
- Key pair name: `soutenace`, Key pair type: RSA, Private key file format: `.pem` → Create key pair.
- Le fichier `soutenace.pem` est téléchargé (conservez-le). Copiez-le si besoin dans WSL: `~/.ssh/soutenace.pem` et faites:
  ```bash
  chmod 600 ~/.ssh/soutenace.pem
  ```

B. Créer le bucket S3 pour l’état Terraform et la table DynamoDB pour le verrouillage
- AWS Console → S3 → bouton “Create bucket”
  - Bucket name: `<project>-tfstate` (ex: `monprojet-tfstate`)
  - Region: `EU (Frankfurt) eu-central-1`
  - Laisser les options par défaut → Create bucket.
- AWS Console → DynamoDB → Tables → Create table
  - Table name: `<project>-tf-locks` (ex: `monprojet-tf-locks`)
  - Partition key: `LockID` (String) → Create table.

Note: Retenez ces valeurs, vous les passerez à Terraform: `tf_state_bucket` et `tf_lock_table`.

C. Créer/Préparer un certificat ACM pour l’ALB (HTTPS)
- AWS Console → ACM → Request a certificate → Request a public certificate.
- Domain name: votre domaine (ex: `app.example.com`). Ajoutez aussi un SAN si nécessaire.
- Valider par DNS (recommandé). Si votre domaine est dans Route53, cliquez “Create records in Route53”.
- Attendre le statut “Issued”.
- Cliquez sur le certificat → copier l’ARN (il commence par `arn:aws:acm:eu-central-1:...`).

D. Créer le rôle IAM pour GitHub Actions (OIDC) – pour CI/CD
1) Ajouter le fournisseur d’identité OIDC GitHub (si absent)
- AWS Console → IAM → Identity providers → Add provider → OpenID Connect
  - Provider URL: `https://token.actions.githubusercontent.com`
  - Audience: `sts.amazonaws.com`
  - Add provider.

2) Créer un rôle IAM assumable par GitHub Actions
- AWS Console → IAM → Roles → Create role → Trusted entity type: Web identity
  - Identity provider: `token.actions.githubusercontent.com`
  - Audience: `sts.amazonaws.com`
  - Conditions (Trust policy) → Ajouter une condition pour limiter au dépôt:
    - Cliquez “Edit trust policy” puis remplacez par:
      ```json
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Principal": {"Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"},
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
              "StringEquals": {
                "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
              },
              "StringLike": {
                "token.actions.githubusercontent.com:sub": "repo:<GITHUB_OWNER>/<REPO_NAME>:*"
              }
            }
          }
        ]
      }
      ```
      - Remplacez `<ACCOUNT_ID>`, `<GITHUB_OWNER>`, `<REPO_NAME>`.
- Permissions (Policy): pour un POC, attachez `AdministratorAccess`. En prod, utilisez un jeu minimal (ECR, S3, CodeDeploy, EKS si besoin):
  - `AmazonEC2ContainerRegistryPowerUser`
  - `AmazonS3FullAccess` (ou restreint au bucket artefacts)
  - `AWSCodeDeployFullAccess`
  - `AmazonSSMFullAccess` (pour SSM sync front)
- Nom du rôle: `github-actions-<project>` (ex: `github-actions-monprojet`). Notez l’ARN.

E. (Optionnel) Créer un domaine Route53 et un enregistrement ALIAS vers l’ALB
- AWS Console → Route53 → Hosted zones → Create hosted zone (si vous n’en avez pas).
- Après déploiement Terraform (étape suivante), créez un record `A` type Alias pointant vers l’ALB.

---

## 3) Configuration du dépôt GitHub – Secrets

Dans GitHub → votre repo → Settings → Secrets and variables → Actions → New repository secret:
- `AWS_ROLE`: l’ARN du rôle OIDC IAM (`arn:aws:iam::<account>:role/github-actions-<project>`)
- `AWS_REGION`: `eu-central-1`
- `AWS_ACCOUNT`: votre ID compte AWS (12 chiffres)
- `PROJECT`: votre `project` (ex: `monprojet`)
- `STAGING_PROJECT`: votre projet staging (ex: `monprojet-staging`)

---

## 4) Déploiement Infrastructure (Terraform)

Dans WSL (Ubuntu):
1) Aller dans le dossier Terraform
```bash
cd /mnt/c/Users/<Vous>/Downloads/devops_repo_full/infra/terraform
```
2) Initialiser Terraform avec backend S3 + table de lock DynamoDB
```bash
terraform init \
  -backend-config="bucket=<project>-tfstate" \
  -backend-config="key=<project>/tf.state" \
  -backend-config="region=eu-central-1" \
  -backend-config="dynamodb_table=<project>-tf-locks"
```
3) Planifier (remplacez les variables entre `<>`)
```bash
terraform plan \
  -var="project=<project>" \
  -var="tf_state_bucket=<project>-tfstate" \
  -var="tf_lock_table=<project>-tf-locks" \
  -var="ssh_key_name=soutenace" \
  -var="certificate_arn=arn:aws:acm:eu-central-1:...:certificate/..."
```
4) Appliquer
```bash
terraform apply \
  -var="project=<project>" \
  -var="tf_state_bucket=<project>-tfstate" \
  -var="tf_lock_table=<project>-tf-locks" \
  -var="ssh_key_name=soutenace" \
  -var="certificate_arn=arn:aws:acm:eu-central-1:...:certificate/..." \
  -auto-approve
```
5) En sortie, notez:
- `alb_dns_name`: ex. `monprojet-alb-123.eu-central-1.elb.amazonaws.com`
- `db_private_ip`: IP privée de la VM MongoDB
- `monitoring_private_ip` et `monitoring_instance_id`

Vérifications AWS Console:
- EC2 → Load balancers → `monprojet-alb` → Listeners: 80 (redirect) et 443 (HTTPS). Target groups: front/back/grafana.
- EC2 → Auto Scaling Groups: `monprojet-front-asg` et `monprojet-back-asg` (Desired=2)
- EC2 → Instances: `monprojet-db`, `monprojet-monitoring`, instances des ASG
- VPC → Subnets (2 publics, 2 privés), Route tables (public avec IGW, privé avec NAT)

---

## 5) Provisionnement VMs (Ansible via SSM)

1) Installer les collections Ansible nécessaires
```bash
ansible-galaxy collection install -r ../../infra/ansible/requirements.yml
```
2) Lancer le playbook
```bash
cd ../../infra/ansible
ansible-playbook site.yml -e region=eu-central-1
```
Attendu: installation Node Exporter (toutes VMs), NGINX (front), Docker + CodeDeploy agent (back), Mongo déjà installé par user-data, Prometheus+Grafana+Alertmanager (monitoring).

Debug inventaire:
```bash
ansible-inventory -i inventories/prod/aws_ec2.yml --graph
```
Doit lister les groupes `front`, `back`, `db`, `monitoring`.

---

## 6) CI/CD – Build

1) Pousser une modification sur `main` (ou re-pousser le code existant):
```bash
git add -A && git commit -m "test build" && git push origin main
```
2) GitHub → Actions → “Build” doit démarrer. Étapes clés à voir en vert:
- Setup Node + build frontend (copie vers `frontend/dist`)
- Login ECR
- Docker build + push image `monprojet-backend:<short_sha>`
- Sync S3 `s3://monprojet-artifacts/front/<sha>/`

---

## 7) CI/CD – Déploiement Prod

1) Créer un tag de version:
```bash
git tag v1.0.0
git push origin v1.0.0
```
2) GitHub → Actions → “Deploy Prod” démarre. Étapes clés:
- Compute backend image ref → écrit `backend/image.txt`
- Zip backend → upload S3 `s3://monprojet-artifacts/backend/<sha>.zip`
- CodeDeploy: create-deployment sur l’app `<project>-backend`
- Front: copie `front/<sha>/` → `front/current/` puis SSM RunCommand sur les VMs `Tier=front` pour `aws s3 sync ... && systemctl reload nginx`
3) AWS Console vérif:
- CodeDeploy → Applications → `<project>-backend` → Deployment groups → `<project>-backend-dg` → le déploiement passe en “Succeeded”.
- EC2 → Target groups → `<project>-tg-back` et `<project>-tg-front` → “healthy”.

---

## 8) Accès applicatif

- Frontend: navigateur → `https://<alb_dns_name>/` → 301 depuis HTTP, page index HTML affichée.
- Backend santé: navigateur → `https://<alb_dns_name>/api/healthz` → `ok`.
- Test API (création RDV): depuis WSL
```bash
curl -k -X POST "https://<alb_dns_name>/api/appointment" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alice","date":"2025-01-01T10:00:00.000Z"}'
```
Retour attendu: JSON avec l’objet créé.

---

## 9) Supervision – Grafana/Prometheus/Alertmanager

A. Accès Grafana
- Navigateur → `https://<alb_dns_name>/grafana/`
- Login: `admin` / `admin` (à changer immédiatement: Grafana → gear (cog) → Users → admin → change password)
- Dashboard: “Infra Basic” (CPU/RAM/Disk). Doit afficher vos VMs.

B. Prometheus (facultatif)
- Port-forward via SSM (terminal WSL):
```bash
aws ssm start-session --target $(terraform -chdir=../terraform output -raw monitoring_instance_id) \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["9090"],"localPortNumber":["9090"]}'
```
- Navigateur → `http://localhost:9090`.

C. Alertmanager – secrets & déploiement (script)
- Créez un fichier `smtp.json` si vous utilisez e‑mail:
```json
{"host":"smtp.example.com","port":587,"username":"user","password":"pass","from":"alerts@example.com","to":"you@example.com"}
```
- Lancez le script:
```bash
cd /mnt/c/Users/<Vous>/Downloads/devops_repo_full
./scripts/bootstrap-alerting.sh \
  --project <project> \
  --region eu-central-1 \
  --slack-webhook https://hooks.slack.com/services/XXX/YYY/ZZZ \
  --smtp-json ./smtp.json \
  --install-collections
```
- Attendu: création/MAJ param SSM Slack, secret SMTP, exécution Ansible.

---

## 10) Tester les alertes (CPU/RAM/Disk)

Monter CPU sur un nœud (via SSM RunCommand)
```bash
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets Key=tag:Project,Values=<project> Key=tag:Tier,Values=back \
  --parameters commands='["nohup sh -c \"yes > /dev/null & sleep 600\" &"]' \
  --comment "Simulate CPU high" \
  --query 'Command.CommandId' --output text --region eu-central-1
```
Attendez ~5–10 minutes. Sur Slack et/ou Email: alerte `HighCPUUsage`.

Arrêt charge CPU (si besoin):
```bash
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets Key=tag:Project,Values=<project> Key=tag:Tier,Values=back \
  --parameters commands='["killall yes || true"]' \
  --comment "Stop CPU stress" --region eu-central-1
```

Tester RAM/Disk: actions similaires (consommer mémoire, écrire sur disque). Les alertes par défaut surveillent >90% sur 10 minutes.

---

## 11) Staging (déploiement manuel)

- GitHub → Actions → “Deploy Staging” → Run workflow → (sélectionnez la branche) → Run.
- Étapes similaires à prod mais utilisant `STAGING_PROJECT`.
- En S3, vérifiez les artefacts staging, et en CodeDeploy l’application `<staging_project>-backend`.

---

## 12) Exploitation courante

- Forcer un refresh du front (hors pipeline):
```bash
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets Key=tag:Project,Values=<project> Key=tag:Tier,Values=front \
  --parameters commands='["aws s3 sync s3://<project>-artifacts/front/current/ /var/www/app/","systemctl reload nginx"]' \
  --comment "Manual front refresh" --region eu-central-1
```
- Redéployer le backend manuellement (si besoin):
  - Construire et pousser l’image ECR (via GitHub Actions Build) ou manuellement.
  - Écrire l’image dans `backend/image.txt`, zipper `backend/` et appeler CodeDeploy `create-deployment` (voir workflow prod pour la commande exacte).

---

## 13) Dépannage (Troubleshooting)

- ALB 5xx ou front vide:
  - EC2 → Target groups → front/back → vérifier le statut “healthy” et la santé `/` et `/healthz`.
  - Vérifier que `front/current/` en S3 contient bien vos fichiers.
  - Relancer SSM sync front (commande plus haut).
- Backend ne démarre pas:
  - CodeDeploy → vérifier logs `/var/log/aws/codedeploy-agent/codedeploy-agent.log` et hook `restart.sh`.
  - ECR login: le hook fait `aws ecr get-login-password`; vérifier permissions IAM instance.
  - `MONGO_URI`: produit par user-data du back; `cat /etc/backend.env`.
- Ansible (SSM):
  - IAM instance profile doit avoir `AmazonSSMManagedInstanceCore`.
  - SSM Agent doit être “Online”: AWS Console → Systems Manager → Fleet Manager → Managed instances.
- Certificat ACM:
  - Si non fourni, HTTPS listener n’existe pas et la redirection 80→443 échoue (erreur). Fournir `certificate_arn` et réappliquer Terraform.
- Coûts NAT:
  - NAT Gateway engendre un coût mensuel. Pour un POC low-cost, remplacez NAT par Instance NAT ou basculez les back en subnets publics (non recommandé en prod).

---

## 14) Nettoyage

- Supprimer la stack (attention aux données):
```bash
cd /mnt/c/Users/<Vous>/Downloads/devops_repo_full/infra/terraform
terraform destroy -var="project=<project>" -var="tf_state_bucket=<project>-tfstate" -var="tf_lock_table=<project>-tf-locks" -var="ssh_key_name=soutenace" -var="certificate_arn=arn:..." -auto-approve
```
- Vider et supprimer manuellement le bucket S3 `*-tfstate` et la table DynamoDB si plus nécessaires.

---

## 15) Options avancées

- Domaine Route53 + certificats wildcard → pointer un nom convivial vers l’ALB via un ALIAS.
- CodeDeploy Blue/Green (Server): ajouter un second Target Group back et configurer `target_group_pair_info`.
- Secrets: stocker toutes les variables sensibles (Slack/SMTP/MONGO creds si auth activée) dans SSM/Secrets Manager.
- OTel Collector: si nécessaire, ajouter le repo AWS OTel dans le rôle Ansible `otel` pour AL2023.

---

## 16) Récapitulatif de validation (checklist)

- [ ] Terraform apply OK (ALB DNS affiché)
- [ ] Ansible playbook OK (node_exporter/prometheus/grafana/alertmanager installés)
- [ ] Build pipeline OK (image ECR + artefacts S3)
- [ ] Deploy Prod OK (CodeDeploy + SSM refresh front)
- [ ] HTTPS OK (redirect 301; HSTS actif)
- [ ] Grafana OK (`/grafana/`), dashboard visible
- [ ] Alertes Slack/Email reçues après test CPU

Vous pouvez maintenant démontrer l’ensemble du cycle: infra → déploiement → supervision → alertes.
