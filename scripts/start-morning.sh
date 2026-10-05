#!/usr/bin/env bash
# start-morning.sh : Verification des identifiants et initialisation du backend
set -e

echo "=== Verification de l'identite AWS ==="
aws sts get-caller-identity

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Initialisation de DEV ==="
cd "$ROOT_DIR/envs/dev"
terraform init -upgrade
terraform plan

echo "=== Pret pour le travail developpeur ==="
