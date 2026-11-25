#!/usr/bin/env bash
# noodle-gallery-patches — build the derived Noodle Gallery server image.
#
# Usage:
#   ./build.sh [upstream-tag]     default upstream tag: v5.11.1
#   CHECK_ONLY=1 ./build.sh       pre-flight checks only (no docker needed)
#
# The build FAILS LOUDLY at the first problem. That is the maintenance
# contract of this repo: if upstream moves something a patch touches,
# you find out here, at build time — never silently in the running app.
set -euo pipefail
cd "$(dirname "$0")"

UPSTREAM_TAG="${1:-v5.11.1}"
IMAGE="noodle-gallery-server-patched:${UPSTREAM_TAG}"

echo "== noodle-gallery-patches pre-flight =="

# 1. Every file the Dockerfile COPYs must exist and be non-empty.
required=(
  assets/outlook-sunset.css
  assets/spirograph-flower-mark.svg
  assets/logo-mark-dark.svg
  assets/1009-collage-logo.svg
  assets/gold-theme.css
  patches/001-outlook-sunset-theme/apply-theme.mjs
  Dockerfile
)
for f in "${required[@]}"; do
  if [ ! -s "$f" ]; then
    echo "PRE-FLIGHT FAILED: $f is missing or empty." >&2
    exit 1
  fi
done
echo "ok: all patch inputs present"

# 2. The theme CSS must parse (tinycss2 if available, brace balance else).
python3 - <<'PYEOF'
import sys
css = open('assets/outlook-sunset.css').read()
try:
    import tinycss2
    rules = tinycss2.parse_stylesheet(css, skip_comments=True, skip_whitespace=True)
    errors = [r for r in rules if r.type == 'error']
    derr = 0
    for r in rules:
        if r.type == 'qualified-rule':
            derr += sum(1 for d in tinycss2.parse_declaration_list(r.content) if d.type == 'error')
    if errors or derr:
        print(f'PRE-FLIGHT FAILED: outlook-sunset.css: {len(errors)} parse errors, {derr} declaration errors.', file=sys.stderr)
        sys.exit(1)
    print(f'ok: outlook-sunset.css parses ({len(rules)} rules, 0 errors)')
except ImportError:
    if css.count('{') != css.count('}'):
        print('PRE-FLIGHT FAILED: outlook-sunset.css braces are unbalanced.', file=sys.stderr)
        sys.exit(1)
    print('ok: outlook-sunset.css braces balanced (tinycss2 unavailable for a full parse)')
PYEOF

# 3. Every SVG must be well-formed XML.
python3 - <<'PYEOF'
import glob, sys
import xml.etree.ElementTree as ET
for path in sorted(glob.glob('assets/*.svg')):
    try:
        ET.parse(path)
    except Exception as e:
        print(f'PRE-FLIGHT FAILED: {path} is not well-formed XML: {e}', file=sys.stderr)
        sys.exit(1)
    print(f'ok: {path} is well-formed XML')
PYEOF

# 4. The dark logo variant must be the flower with ONLY the fill changed.
if ! sed 's/#8FB0FF/#1E3CDC/g' assets/logo-mark-dark.svg | cmp -s - assets/spirograph-flower-mark.svg; then
  echo "PRE-FLIGHT FAILED: assets/logo-mark-dark.svg is not the flower with only the fill color changed." >&2
  exit 1
fi
echo "ok: logo-mark-dark.svg is the flower, fill-only change"

if [ "${CHECK_ONLY:-0}" = "1" ]; then
  echo "== pre-flight OK (CHECK_ONLY=1, stopping before docker) =="
  exit 0
fi

# 5. Docker build.
if ! command -v docker >/dev/null 2>&1; then
  echo "BUILD FAILED: docker is not on PATH. Run this where Docker Desktop is running." >&2
  exit 1
fi
echo "== docker build: $IMAGE (FROM ghcr.io/open-noodle/gallery-server:${UPSTREAM_TAG}) =="
docker build --build-arg "UPSTREAM_TAG=${UPSTREAM_TAG}" -t "$IMAGE" .

# 6. Post-build verification: the files inside the image must be OUR files,
#    byte for byte. A build that "succeeded" with the wrong logo in place
#    is a failed build.
echo "== verifying patched files inside $IMAGE =="
FLOWER_SHA="$(sha256sum assets/spirograph-flower-mark.svg | cut -d' ' -f1)"
DARK_SHA="$(sha256sum assets/logo-mark-dark.svg | cut -d' ' -f1)"
COLLAGE_SHA="$(sha256sum assets/1009-collage-logo.svg | cut -d' ' -f1)"
CSS_SHA="$(sha256sum assets/outlook-sunset.css | cut -d' ' -f1)"
docker run --rm --entrypoint /bin/bash \
  -e FLOWER_SHA="$FLOWER_SHA" -e DARK_SHA="$DARK_SHA" \
  -e COLLAGE_SHA="$COLLAGE_SHA" -e CSS_SHA="$CSS_SHA" \
  "$IMAGE" -c '
set -eu
check() {
  actual="$(sha256sum "$1" | cut -d" " -f1)"
  if [ "$actual" != "$2" ]; then
    echo "VERIFY FAILED: $1 sha256=$actual, expected $2" >&2
    exit 1
  fi
  echo "ok: $1"
}
check /build/www/gallery-logo-mark.svg "$FLOWER_SHA"
check /build/www/gallery-loader.svg "$FLOWER_SHA"
check /build/www/gallery-logo-mark-dark.svg "$DARK_SHA"
check /build/www/gallery-loader-dark.svg "$DARK_SHA"
check /build/www/gallery-logo-stacked.svg "$COLLAGE_SHA"
check /build/www/gallery-logo-stacked-dark.svg "$COLLAGE_SHA"
check /build/www/gallery-logo-inline-light.svg "$COLLAGE_SHA"
check /build/www/gallery-logo-inline-dark.svg "$COLLAGE_SHA"
check /patches/outlook-sunset.css "$CSS_SHA"
test -s /patches/apply-theme.mjs
echo "all patched files verified inside the image"
'
echo "== OK: $IMAGE built and verified =="
echo "Next: docker compose -f docker-compose.yml -f docker-compose.patches.yml up -d"
