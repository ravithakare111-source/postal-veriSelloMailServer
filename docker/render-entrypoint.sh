#!/bin/bash
# Entrypoint used when running Postal on Render (see render.yaml).
#
# Render has no way to mount a secret file shared by several services, so the
# RSA signing key is passed in through the POSTAL_SIGNING_KEY_BASE64
# environment variable and written to disk here before Postal starts.
set -e

if [ -n "$POSTAL_SIGNING_KEY_BASE64" ]; then
  key_path="${POSTAL_SIGNING_KEY_PATH:-/opt/postal/app/tmp/signing.key}"
  mkdir -p "$(dirname "$key_path")"
  echo "$POSTAL_SIGNING_KEY_BASE64" | base64 -d > "$key_path"
  chmod 600 "$key_path"
  export POSTAL_SIGNING_KEY_PATH="$key_path"
fi

exec /docker-entrypoint.sh "$@"
