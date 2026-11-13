#!/usr/bin/env bash
# Usage: COMPANY_NAME="Acme Ltd" CONTACT_EMAIL="privacy@acme.com" ./tools/render_legal.sh
set -euo pipefail
cd "$(dirname "$0")/.."
: "${COMPANY_NAME:?Set COMPANY_NAME}"
: "${CONTACT_EMAIL:?Set CONTACT_EMAIL}"
mkdir -p hosting/public
for name in privacy delete-account; do
  python3 - "$name" <<'PY'
import os, sys, datetime
name = sys.argv[1]
s = open(f"hosting/{name}.template.html", encoding="utf-8").read()
s = s.replace("@@COMPANY@@", os.environ["COMPANY_NAME"]).replace("@@EMAIL@@", os.environ["CONTACT_EMAIL"])
s = s.replace("@@DATE@@", datetime.date.today().isoformat())
open(f"hosting/public/{name}.html", "w", encoding="utf-8").write(s)
PY
done
cp hosting/public/privacy.html hosting/public/index.html
echo "Rendered hosting/public. Deploy with: firebase deploy --only hosting"
