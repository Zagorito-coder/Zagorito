#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname -- "$SCRIPT_DIR")
ENV_FILE=${SPOTS_ENV_FILE:-"$PROJECT_DIR/.env"}

if [ ! -f "$ENV_FILE" ]; then
  echo "Fichier de configuration introuvable: $ENV_FILE" >&2
  echo "Le lancement est annulé avant de remplacer l'application installée." >&2
  echo "Copiez .env.example vers .env et renseignez les valeurs locales." >&2
  exit 66
fi

cd "$PROJECT_DIR"

# Refuse d'installer une application inutilisable si la clé et le catalogue
# chiffré ne correspondent pas.
python3 tools/encrypt_spots.py --check --env-file "$ENV_FILE"

exec flutter run \
  --dart-define-from-file="$ENV_FILE" \
  "$@"
