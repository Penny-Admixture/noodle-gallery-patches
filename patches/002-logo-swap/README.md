# Patch 002 — Logo swap

Replaces the gallery logo **in the built web image itself** — navbar,
sidebar, loading states, and the login page. This is the job Custom
CSS cannot do: CSS can restyle an `<img>`, but the login page's wide
slots and backdrop are outside what a pasted stylesheet should be
trusted to reach, and a file swap covers every slot at once,
permanently, with no per-page selectors to maintain.

## The mapping

All 8 logo files the app can request, and what each becomes:

| Upstream file (in `/build/www/`) | Slot | Becomes |
|---|---|---|
| `gallery-logo-mark.svg` | icon, light | spirograph flower |
| `gallery-logo-mark-dark.svg` | icon, dark | flower, lightened |
| `gallery-loader.svg` | icon (transparent), light — login card logo, loading states | spirograph flower |
| `gallery-loader-dark.svg` | icon (transparent), dark | flower, lightened |
| `gallery-logo-stacked.svg` | stacked lockup, light | 1009 collage logo |
| `gallery-logo-stacked-dark.svg` | stacked lockup, dark | 1009 collage logo |
| `gallery-logo-inline-light.svg` | inline lockup, light | 1009 collage logo |
| `gallery-logo-inline-dark.svg` | inline lockup, dark | 1009 collage logo |

Art: `assets/spirograph-flower-mark.svg` (the flower),
`assets/logo-mark-dark.svg` (the same flower with only the fill
changed, `#1E3CDC` → `#8FB0FF` — `build.sh` proves fill-only on every
run), `assets/1009-collage-logo.svg` (the stacked collage).

## Choices, and why

- **Square slots get the flower** — it's a square mark (260×260) and
  it's the agreed small mark. The login page's giant blurred backdrop
  (`AuthPageLayout.svelte` uses `/gallery-logo-mark.svg` full-bleed
  behind a 200px blur) becomes a field of flower, which suits a
  blurred backdrop.
- **Dark slots get a lightened variant, not the raw flower.** The
  flower's fill is deep blue `#1E3CDC`; on dark charcoal chrome it
  would sit nearly invisible without the Sunset CSS's brightness
  filter — and this patch has to stand on its own even if the theme
  is off or switched back to gold. `#8FB0FF` reads on dark chrome.
  It's a color variant of her own art, generated mechanically, not
  new artwork.
- **Wide slots get the collage** — it's the agreed stacked/wide logo.
  Honest caveat: the collage is **opaque** (its background is a solid
  `#870015` dark red, 909×827), so in the inline/stacked slots it
  renders as a small rectangular card rather than a transparent
  lockup. That's what the art is; if a transparent wide lockup exists
  later, swapping it in is a one-file change in `assets/` plus this
  table.

## Why this patch is stable

Every path was verified against `open-noodle/gallery` **v5.11.1**:

- `web/src/lib/components/shared-components/Logo.svelte` — the logo
  `src` is derived from exactly the 8 filenames above, by variant
  (icon / inline / stacked, plus the `transparent` loader pair) and
  light/dark theme. No other logo paths exist in the component.
- `web/static/` — all 8 files confirmed present there at v5.11.1.
  SvelteKit copies `static/` **verbatim** into the build output, so
  these names carry no content hash. (The hashed files under
  `_app/immutable/assets/` are a different story — this patch touches
  none of them, on purpose.)
- `server/Dockerfile` — `COPY --from=web /usr/src/app/web/build
  /build/www`: the web client ships inside the **server** image at
  `/build/www`. There is no separate web container in the compose
  file; the server serves the UI on 2283.
- `web/src/lib/components/layouts/AuthPageLayout.svelte` — the login
  page: backdrop `<img src="/gallery-logo-mark.svg">` and header
  `<Logo variant="icon" size="giant" transparent />`.

## How it fails loudly

The Dockerfile checks all 8 target files exist in `/build/www`
**before** replacing any of them. If an upstream release renames a
file or moves the web root, the build stops and names the missing
file. `build.sh` then verifies the built image byte-for-byte
(sha256 of every replaced file against `assets/`).

**Re-check on every upstream bump:** the filename table in
`Logo.svelte`, and the `/build/www` destination in
`server/Dockerfile`. Two greps; they're the whole re-check.
