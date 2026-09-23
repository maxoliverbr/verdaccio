#!/usr/bin/env bash
set -euo pipefail

published=${PUBLISHED_PACKAGES:?changesets/action did not return publishedPackages}
echo "$published" | jq -e 'type == "array"' >/dev/null

while IFS=$'\t' read -r name version; do
  [ -n "$name" ] || continue
  found=false
  for attempt in $(seq 1 6); do
    metadata=$(npm view "$name@$version" dist.attestations --json \
      --registry=https://registry.npmjs.org --prefer-online 2>/dev/null || true)
    if jq -e '.url | type == "string"' <<<"$metadata" >/dev/null 2>&1 &&
       jq -e '.provenance.predicateType == "https://slsa.dev/provenance/v1"' <<<"$metadata" >/dev/null 2>&1; then
      found=true
      echo "Verified npm provenance: $name@$version"
      break
    fi
    sleep 5
  done
  if [ "$found" != true ]; then
    echo "::error::Missing npm provenance attestation for $name@$version" >&2
    exit 1
  fi
done < <(jq -r '.[] | [.name, .version] | @tsv' <<<"$published")
