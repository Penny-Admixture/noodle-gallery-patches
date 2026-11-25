# noodle-gallery-patches

Penny's changes to Noodle Gallery (the `open-noodle/gallery` fork of
Immich), kept as a **patch set on top of the real upstream image** —
not a fork.

The idea: upstream stays upstream. This repo holds *only* our changes:
a Dockerfile that starts `FROM ghcr.io/open-noodle/gallery-server` and
layers the patches on, the patch files themselves, and the art they
install. When upstream releases a new version, we bump one version
tag, rebuild, and the build itself tells us if a patch stopped
applying. Our codebase stays tiny and separate; there's no fork to
keep merging.

Pinned upstream: **v5.11.1** (the version Penny's instance runs).

## What's in here

| Path | What |
|---|---|
| `Dockerfile` | The derived image: upstream gallery-server + patches |
| `build.sh` | Builds it, verifies it, fails loudly on any problem |
| `docker-compose.patches.yml` | Overlay for the live stack: derived image + the theme patcher service |
| `patches/PATCHES.md` | The manifest: every patch, what it touches, how brittle it is |
| `patches/001-outlook-sunset-theme/` | Theme patch: CSS applier + mechanism notes |
| `patches/002-logo-swap/` | Logo patch: slot mapping + stability notes |
| `assets/` | Our files: theme CSS, logo SVGs, the preserved gold theme |
| `scripts/apply-theme.sh` | Re-run the theme applier on demand |

Current patches: **001** Outlook Sunset theme (applied via the API at
stack start — never pasted by hand) and **002** logo swap (flower +
1009 collage baked into the web client, login page included).

## Use it

On the PC, in `C:\Users\llm_development\noodle-gallery`:

1. Build the derived image (this repo checked out anywhere):
   `./build.sh` — pre-flight checks, docker build, then a byte-for-byte
   verification of every patched file inside the image.
2. One-time: create an API key on an admin account
   (Administration → API Keys) and add `GALLERY_ADMIN_API_KEY=<key>`
   to the `.env` next to `docker-compose.yml`. The theme patcher
   needs it; without it, it exits with that instruction in its log.
3. Copy `docker-compose.patches.yml` next to `docker-compose.yml` and:
   `docker compose -f docker-compose.yml -f docker-compose.patches.yml up -d`
4. Eyeball it: flower in the navbar, flower + collage on the login
   page, Sunset colors and stripe, and — important — the Settings
   pages still save (nothing in this repo locks the settings UI; see
   the IMMICH_CONFIG_FILE note in patch 001's README).

## Bump the upstream version

1. `./build.sh vX.Y.Z` (new tag). If a patch no longer applies, the
   build fails and names the patch and the file — fix that patch
   (the re-check list is in `patches/PATCHES.md`), never force it.
2. Change the two `v5.11.1` tags in `docker-compose.patches.yml` to
   match, then `docker compose ... up -d` as above.

## Switch back to the gold theme

`assets/gold-theme.css` is the previous theme, preserved verbatim
from Penny's 2026-11-25 settings backup. Point the patcher at it
(`GALLERY_THEME_CSS=/patches/gold-theme.css` on the `gallery-patcher`
service) and run `scripts/apply-theme.sh`. To go fully stock, run the
stack without the overlay file at all.

## Honest limits

- **Not yet run on a real Docker host.** This repo was built and
  checked on a VM with no Docker: Dockerfile parsed, patch inputs
  verified, CSS parsed, fork paths read from source. The first
  `build.sh` + `up` on the PC is the real test — expect to eyeball
  the login page and navbar, and check `docker compose logs
  gallery-patcher` for the theme verification line.
- **The theme patcher needs the API key** (one-time, above). The logo
  patch needs nothing at runtime — it's baked into the image.
- **Don't set `IMMICH_CONFIG_FILE`** on the server: it locks the
  whole settings UI and makes the theme patcher's PUTs fail. See
  patch 001's README.
- **Mobile app is untouched** — these are web/server-side patches.
- The collage logo is opaque art (dark red background); in the wide
  slots it renders as a rectangular card. See patch 002's README.
