# MINIMAP — noodle-gallery-patches

A patch set, not a fork. Start from the real upstream image, layer our
changes on top, fail loudly if a patch stops applying.

## Current state — Build 1 (2026-11-25)

- Upstream pinned: `open-noodle/gallery` **v5.11.1**,
  image `ghcr.io/open-noodle/gallery-server:v5.11.1`.
- Derived image: `noodle-gallery-server-patched:v5.11.1`.
- Patch 001 (theme): API applier, one-shot `gallery-patcher` service.
- Patch 002 (logo): 8 files replaced in `/build/www`, build-time
  existence check + post-build sha256 verification.
- Verified on the VM: Dockerfile parses (dockerfile-parse), build.sh
  pre-flight passes, theme CSS parses (tinycss2, 0 errors), all SVGs
  well-formed, dark logo variant proven fill-only, gold theme proven
  byte-identical to Penny's 2026-11-25 backup, every upstream path
  read from fork source at v5.11.1 (Logo.svelte, AuthPageLayout,
  server/Dockerfile, system-config controller/service, web/static —
  the 8 Logo.svelte filenames match the 8 web/static files exactly).
  apply-theme.mjs passed a mock-server test (no key → exit 1 with
  instructions; bad key → exit 1; good key → applies + read-back
  verified; second run → idempotent no-op).
- NOT verified: docker build/run (no Docker on the VM). First PC run
  is the real test — see README "Honest limits".

## Map

- `Dockerfile` — the whole patch application for files: patch 002
  COPYs + patch 001's payload (`/patches/` in the image).
- `build.sh` — pre-flight → docker build → in-image sha256 verify.
  `CHECK_ONLY=1` runs pre-flight only.
- `docker-compose.patches.yml` — overlay: server uses the derived
  image; `gallery-patcher` one-shot applies the theme.
- `patches/PATCHES.md` — manifest + brittleness + re-check lists.
- `patches/001-outlook-sunset-theme/apply-theme.mjs` — GET config,
  compare, PUT full config with new `theme.customCss`, GET-verify.
  Env: `GALLERY_ADMIN_API_KEY` (required), `GALLERY_BASE_URL`,
  `GALLERY_THEME_CSS`.
- `patches/002-logo-swap/README.md` — the 8-file mapping table.
- `assets/` — `outlook-sunset.css`, `gold-theme.css` (switch-back),
  `spirograph-flower-mark.svg`, `logo-mark-dark.svg` (generated
  variant — regenerate with `sed s/#1E3CDC/#8FB0FF/` on the flower),
  `1009-collage-logo.svg`.
- `scripts/apply-theme.sh` — on-demand patcher run via compose.

## Key facts to not re-derive

- The web UI ships **inside** the gallery-server image at
  `/build/www` (fork's server/Dockerfile). There is no web container.
- Logo filenames come from `web/static/` → verbatim, unhashed, stable.
- Custom CSS is a DB config value (`theme.customCss`), set via
  `PUT /api/system-config` with an admin `x-api-key`.
- `IMMICH_CONFIG_FILE` locks the entire settings UI — never use it
  for theming (patch 001 README has the source citation).
