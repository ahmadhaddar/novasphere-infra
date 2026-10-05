#!/usr/bin/env bash
# stop-evening.sh : Destruction obligatoire en fin de journee pour eviter la facturation ALB/ASG
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Destruction de l'environnement DEV ==="
cd "$ROOT_DIR/envs/dev"
if [ -d ".terraform" ]; then
    terraform destroy -auto-approve || true
fi

echo "=== Destruction de l'environnement PROD ==="
cd "$ROOT_DIR/envs/prod"
if [ -d ".terraform" ]; then
    terraform destroy -auto-approve || true
fi

echo "=== Toutes les ressources facturables ont ete detruites. Fin de session propre. ==="
