#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname -- "$SCRIPT_DIR")
ENV_FILE=${SPOTS_ENV_FILE:-"$PROJECT_DIR/.env"}
TARGET=${1:-appbundle}

if [ "$#" -gt 0 ]; then
  shift
fi

case "$TARGET" in
  appbundle|apk) ;;
  *)
    echo "Usage: tools/build_release.sh [appbundle|apk] [options Flutter]" >&2
    exit 64
    ;;
esac

if [ ! -f "$ENV_FILE" ]; then
  echo "Fichier de configuration introuvable: $ENV_FILE" >&2
  echo "Copiez .env.example vers .env et renseignez les valeurs Release." >&2
  exit 66
fi

cd "$PROJECT_DIR"
python3 tools/encrypt_spots.py --check --env-file "$ENV_FILE"

exec flutter build "$TARGET" \
  --release \
  --dart-define-from-file="$ENV_FILE" \
  "$@"
