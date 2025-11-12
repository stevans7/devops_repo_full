#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/generate-doc.sh \
  --project <name> \
  --staging <name> \
  --account <12digits> \
  --owner <github_owner> \
  --repo <github_repo> \
  [--region eu-central-1] \
  [--win-user <WindowsUser>] \
  [--domain <app.example.com>] \
  [--pdf]

Fills docs/STEP_BY_STEP_FULL.md placeholders and writes docs/STEP_BY_STEP_<project>.md
Optionally generates a PDF (requires pandoc + wkhtmltopdf or LaTeX engine).

Examples:
  scripts/generate-doc.sh --project monprojet --staging monprojet-staging \
    --account 123456789012 --owner myorg --repo devops_repo_full --pdf
EOF
}

PROJECT=""; STAGING=""; ACCOUNT=""; OWNER=""; REPO=""; REGION="eu-central-1"; WIN_USER=""; DOMAIN=""; PDF=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2;;
    --staging) STAGING="$2"; shift 2;;
    --account) ACCOUNT="$2"; shift 2;;
    --owner) OWNER="$2"; shift 2;;
    --repo) REPO="$2"; shift 2;;
    --region) REGION="$2"; shift 2;;
    --win-user) WIN_USER="$2"; shift 2;;
    --domain) DOMAIN="$2"; shift 2;;
    --pdf) PDF=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

if [[ -z "$PROJECT" || -z "$STAGING" || -z "$ACCOUNT" || -z "$OWNER" || -z "$REPO" ]]; then
  echo "Missing required args" >&2; usage; exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
SRC_MD="$ROOT_DIR/docs/STEP_BY_STEP_FULL.md"
OUT_MD="$ROOT_DIR/docs/STEP_BY_STEP_${PROJECT}.md"

if [[ ! -f "$SRC_MD" ]]; then
  echo "Template not found: $SRC_MD" >&2; exit 1
fi

REPO_URL="https://github.com/${OWNER}/${REPO}.git"

cp "$SRC_MD" "$OUT_MD"

# Targeted replacements
sed -i \
  -e "s|<project>|${PROJECT}|g" \
  -e "s|<staging_project>|${STAGING}|g" \
  -e "s|<ACCOUNT_ID>|${ACCOUNT}|g" \
  -e "s|<GITHUB_OWNER>|${OWNER}|g" \
  -e "s|<REPO_NAME>|${REPO}|g" \
  -e "s|<URL_GITHUB_DU_DEPOT>|${REPO_URL}|g" \
  "$OUT_MD"

if [[ -n "$WIN_USER" ]]; then
  sed -i -e "s|<Vous>|${WIN_USER}|g" "$OUT_MD"
fi

if [[ -n "$DOMAIN" ]]; then
  # Add a helpful note at the top with the domain
  sed -i "1i > Domaine cible: ${DOMAIN}\n" "$OUT_MD"
fi

echo "Generated: $OUT_MD"

if $PDF; then
  OUT_PDF="${OUT_MD%.md}.pdf"
  echo "Attempting PDF generation: $OUT_PDF"
  if command -v pandoc >/dev/null 2>&1; then
    if command -v wkhtmltopdf >/dev/null 2>&1; then
      pandoc "$OUT_MD" -o "$OUT_PDF" --pdf-engine=wkhtmltopdf || true
    else
      pandoc "$OUT_MD" -o "$OUT_PDF" || true
    fi
    if [[ -f "$OUT_PDF" ]]; then
      echo "PDF generated: $OUT_PDF"
    else
      echo "PDF generation failed. Install 'pandoc' and optionally 'wkhtmltopdf' or LaTeX packages." >&2
      exit 1
    fi
  else
    echo "pandoc not installed. Install with: sudo apt install -y pandoc" >&2
    exit 1
  fi
fi

exit 0

