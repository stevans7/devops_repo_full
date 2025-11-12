#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap-alerting.sh --project <name> [--region eu-central-1] \
  [--slack-webhook <url> | --slack-ssm-name </path/param>] \
  [--smtp-json <file.json> | --smtp-secret-arn <arn>] \
  [--install-collections]

Creates Slack/SMTP secrets (SSM/Secrets Manager) then runs Ansible to deploy
Prometheus + Alertmanager + Grafana with proper wiring.

Examples:
  ./scripts/bootstrap-alerting.sh --project myproj --slack-webhook https://hooks.slack.com/services/XXX/YYY/ZZZ --smtp-json ./smtp.json
  ./scripts/bootstrap-alerting.sh --project myproj --slack-ssm-name /myproj/alerting/slack_webhook --smtp-secret-arn arn:aws:secretsmanager:eu-central-1:123:secret:alertmanager-smtp-abc
EOF
}

PROJECT=""
REGION="eu-central-1"
SLACK_WEBHOOK=""
SLACK_SSM_NAME=""
SMTP_JSON=""
SMTP_SECRET_ARN=""
INSTALL_COLLECTIONS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2;;
    --region) REGION="$2"; shift 2;;
    --slack-webhook) SLACK_WEBHOOK="$2"; shift 2;;
    --slack-ssm-name) SLACK_SSM_NAME="$2"; shift 2;;
    --smtp-json) SMTP_JSON="$2"; shift 2;;
    --smtp-secret-arn) SMTP_SECRET_ARN="$2"; shift 2;;
    --install-collections) INSTALL_COLLECTIONS=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

if [[ -z "$PROJECT" ]]; then
  echo "--project is required" >&2; usage; exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT_DIR"

# Slack webhook -> SSM param (if provided)
if [[ -n "$SLACK_WEBHOOK" ]]; then
  if [[ -z "$SLACK_SSM_NAME" ]]; then
    SLACK_SSM_NAME="/${PROJECT}/alerting/slack_webhook"
  fi
  echo "Storing Slack webhook in SSM: $SLACK_SSM_NAME"
  aws ssm put-parameter --name "$SLACK_SSM_NAME" --type "SecureString" --value "$SLACK_WEBHOOK" --overwrite --region "$REGION" 1>/dev/null
fi

# SMTP JSON -> Secrets Manager (if provided)
if [[ -n "$SMTP_JSON" ]]; then
  if [[ ! -f "$SMTP_JSON" ]]; then
    echo "SMTP JSON file not found: $SMTP_JSON" >&2; exit 1
  fi
  SECRET_NAME="alertmanager-smtp-${PROJECT}"
  echo "Creating/Updating SMTP secret in Secrets Manager: $SECRET_NAME"
  set +e
  EXISTING_ARN=$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --query ARN --output text --region "$REGION" 2>/dev/null)
  RC=$?
  set -e
  if [[ $RC -eq 0 && -n "$EXISTING_ARN" ]]; then
    aws secretsmanager update-secret --secret-id "$SECRET_NAME" --secret-string file://"$SMTP_JSON" --region "$REGION" 1>/dev/null
    SMTP_SECRET_ARN="$EXISTING_ARN"
  else
    SMTP_SECRET_ARN=$(aws secretsmanager create-secret --name "$SECRET_NAME" --secret-string file://"$SMTP_JSON" --query ARN --output text --region "$REGION")
  fi
fi

echo "Summary:"
echo "  Project: $PROJECT"
echo "  Region:  $REGION"
echo "  Slack SSM param: ${SLACK_SSM_NAME:-<none>}"
echo "  SMTP Secret ARN: ${SMTP_SECRET_ARN:-<none>}"

if $INSTALL_COLLECTIONS; then
  echo "Installing Ansible collections..."
  ansible-galaxy collection install -r infra/ansible/requirements.yml
fi

echo "Running Ansible playbook via SSM..."
ansible-playbook infra/ansible/site.yml \
  -e region="$REGION" \
  -e project="$PROJECT" \
  -e alertmanager_slack_webhook_url_ssm_parameter="${SLACK_SSM_NAME:-}" \
  -e alertmanager_email_smtp_secret_arn="${SMTP_SECRET_ARN:-}"

echo "Done. Check Grafana and alert delivery in Slack/Email."
