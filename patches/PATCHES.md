# Patch manifest — noodle-gallery-patches

Every patch in this repo, in apply order: what it touches upstream, why,
and how brittle it is. "Brittle" = how likely an upstream release is to
break it, and how we find out when it does.

The maintenance contract: **a patch that stops applying fails loudly** —
at `docker build` time, or in the patcher's exit code and logs. Nothing
in this repo fails silently. If a build goes green, the patches are in.

Upstream: `open-noodle/gallery` (the Noodle Gallery fork of Immich).
Pinned version: **v5.11.1**. Every path and selector below was read out
of the fork's source at that tag with `gh-fetch.py`, not guessed.

---

## 001 — Outlook Sunset theme

- **What:** sets the server's Custom CSS (`theme.customCss`) to
  `assets/outlook-sunset.css` — dark charcoal, white text, teal accents,
  the sunset-gradient stripe across the top, flower logo in the navbar.
- **Touches upstream files:** none. Custom CSS lives in the server's
  system config (database), not in any file, so there is nothing to
  COPY. The patch ships the CSS + an applier (`apply-theme.mjs`) inside
  the derived image, and a one-shot compose service runs the applier
  against the server API once the server is healthy.
- **Upstream surface it depends on** (verified in fork source v5.11.1):
  - `PUT /api/system-config` — `server/src/controllers/system-config.controller.ts`
    (`@Put()`, admin + `SystemConfigUpdate` permission)
  - `updateAdminConfig` — `server/src/services/system-config.service.ts`
  - the `theme.customCss` config field; auth via the `x-api-key` header
  - the applier GETs the full config, changes only `theme.customCss`,
    PUTs the full config back, then GETs again and compares — the same
    request shape the admin UI sends.
- **Brittleness: LOW.** The API and the config field are public,
  versioned surface. What to re-check on an upstream bump: the route,
  the field name, and that API keys still authenticate with `x-api-key`.
- **Failure mode:** the patcher exits 1 with the reason in its logs
  (`docker compose logs gallery-patcher`). The gallery itself still runs
  — it just keeps whatever theme it already had.
- **Detail:** `patches/001-outlook-sunset-theme/README.md`

## 002 — Logo swap

- **What:** replaces all 8 logo files in the built web client with
  Penny's art — the spirograph flower in the square slots, a lightened
  flower variant in the dark square slots, the stacked 1009 collage in
  the wide slots. This includes the login page, which Custom CSS
  cannot fully reach.
- **Touches upstream files:** 8 files in `/build/www/` inside the
  gallery-server image:
  `gallery-logo-mark.svg`, `gallery-logo-mark-dark.svg`,
  `gallery-logo-inline-light.svg`, `gallery-logo-inline-dark.svg`,
  `gallery-logo-stacked.svg`, `gallery-logo-stacked-dark.svg`,
  `gallery-loader.svg`, `gallery-loader-dark.svg`.
- **Why those paths are stable** (verified in fork source v5.11.1):
  - `web/src/lib/components/shared-components/Logo.svelte` builds the
    logo `src` from exactly these 8 root-relative filenames, chosen by
    variant (icon / inline / stacked / transparent) and light/dark.
  - The files live in `web/static/`, which SvelteKit copies **verbatim**
    into the build output — no content hashing (unlike the JS/CSS under
    `_app/immutable/assets/`, whose names change every build).
  - `server/Dockerfile` copies the web build into the server image at
    `/build/www` (`COPY --from=web /usr/src/app/web/build /build/www`).
  - All 8 files were confirmed present in `web/static/` at v5.11.1.
  - Login page usage verified in
    `web/src/lib/components/layouts/AuthPageLayout.svelte`: the blurred
    backdrop is `/gallery-logo-mark.svg`, and the card header is
    `<Logo variant="icon" transparent>` → the `gallery-loader*.svg`
    files. Both are covered by this patch.
- **Brittleness: LOW–MEDIUM.** Stable as long as upstream keeps the
  static-file layout and the Logo component's filename table. The
  Dockerfile checks all 8 files exist **before** overwriting any of
  them and fails the build with a named file if one is gone — so a
  breaking upstream change is a loud build failure, never a silent
  stock logo.
- **What to re-check on an upstream bump:** the 8 filenames in
  `Logo.svelte`, and the `/build/www` path in `server/Dockerfile`.
- **Detail:** `patches/002-logo-swap/README.md`

---

## Not patches (and why)

- **Profile avatar picture** — already built into the app (open a photo
  → ••• → "Set as profile picture"). Nothing to patch.
- **Mobile app logo/theme** — web-side patches cannot reach the mobile
  app. Out of scope, permanently, for this repo.
- **Server behavior** — no patch touches the gallery-server code. If a
  future change needs one, it becomes patch 003+ with its own entry
  here, its own loud failure, and its own re-check list.
