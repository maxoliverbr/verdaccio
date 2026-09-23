#!/usr/bin/env bash
set -euo pipefail

image=${1:?usage: test-docker-image.sh IMAGE}
container="verdaccio-image-test-$$"
test_dir=$(mktemp -d)

cleanup() {
  docker logs "$container" 2>&1 || true
  docker stop "$container" >/dev/null 2>&1 || true
  rm -rf "$test_dir"
}
trap cleanup EXIT

docker run -d --rm --name "$container" -p 127.0.0.1::4873 "$image" >/dev/null
port=$(docker port "$container" 4873/tcp | sed -n 's/.*://p' | head -1)
registry="http://127.0.0.1:$port"

ready=false
for attempt in $(seq 1 60); do
  if curl --fail --silent "$registry/-/ping" >/dev/null; then
    ready=true
    break
  fi
  if [ "$(docker inspect -f '{{.State.Running}}' "$container")" != true ]; then
    echo 'Container exited before readiness' >&2
    exit 1
  fi
  sleep 2
done
[ "$ready" = true ] || { echo 'Registry did not become ready' >&2; exit 1; }

curl --fail --silent -H 'Accept: text/html' "$registry/" -o "$test_dir/index.html"
grep -q '<script' "$test_dir/index.html"
curl --fail --silent "$registry/-/static/ui-options.js" -o "$test_dir/ui-options.js"
grep -q '__VERDACCIO_BASENAME_UI_OPTIONS' "$test_dir/ui-options.js"

cd "$test_dir"
printf '{"name":"verdaccio-image-smoke","version":"1.0.0","private":true}\n' > package.json
npm install --ignore-scripts --no-audit --no-fund --cache "$test_dir/npm-cache" --registry "$registry" lodash@4.17.21
node -e "if (require('lodash').VERSION !== '4.17.21') process.exit(1)"
echo 'Built image serves the registry, UI, and an npm package install.'
