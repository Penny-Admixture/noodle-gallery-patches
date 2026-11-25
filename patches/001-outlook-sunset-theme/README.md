# Patch 001 — Outlook Sunset theme

Ships Penny's Outlook Sunset theme (dark charcoal, white text, teal
accents, sunset-gradient stripe across the top) **inside the derived
image**, applied automatically. Nobody pastes CSS into Theme Settings
ever again.

The theme file itself is `assets/outlook-sunset.css` (its design source
and limits are documented in the file's header comment; it was verified
before it landed here: clean CSS parse, and every selector/variable in
it read out of the fork at v5.11.1).

## The mechanism (chosen): an API applier in a one-shot service

Custom CSS is not a file. It is the `theme.customCss` field of the
server's system config, stored in the database and served to the web
app at runtime (`getCustomCss()` in
`server/src/services/system-config.service.ts`). So there is nothing
to COPY into place — the value has to be *set*.

`apply-theme.mjs` sets it through the server's own API:

1. `GET /api/system-config` with an admin API key (`x-api-key` header).
2. If `theme.customCss` already equals the theme file, log and exit 0.
3. Otherwise set `theme.customCss` on the full config object and
   `PUT /api/system-config` — the same request the admin UI sends.
4. GET again and compare. Mismatch = exit 1.

It runs as the `gallery-patcher` service in
`docker-compose.patches.yml`: a one-shot container (same derived
image) gated on the server being healthy, then it exits. Idempotent,
so every `docker compose up` re-checks the theme and repairs it if
someone changed it in the UI.

**One-time setup:** the applier needs an API key from an admin account
(Administration → API Keys), stored as `GALLERY_ADMIN_API_KEY` in the
`.env` next to the compose file. Without it the patcher exits 1 with
instructions in the log — loud, not silent.

## Alternatives considered

- **IMMICH_CONFIG_FILE (rejected).** The server can load its whole
  system config from a file pointed to by `IMMICH_CONFIG_FILE`, which
  would let us bake the theme into a config file. Rejected because of
  what else it does: while a config file is in use, the server
  **rejects all config updates** — `updateAdminConfig` throws
  `BadRequestException: Cannot update configuration while
  IMMICH_CONFIG_FILE is in use` (verified in the fork source above).
  Every settings page locks, for every setting, forever. Far too big a
  blast radius for a theme.
- **Inject the CSS into the built web app (rejected).** There is no
  static slot for Custom CSS in the built client — the app fetches it
  from the server config at runtime. Injecting would mean patching
  built, minified JS under hashed filenames: the most brittle option
  on the table, and it would fight the server's own CSS on every page.
- **Update the database directly (rejected as primary).** The config
  lives in Postgres. A raw SQL update bypasses the server's
  validation, its config cache, and the `ConfigUpdate` event that
  tells the running server the config changed — the theme could sit
  unapplied until a restart, or worse. Kept only as a documented
  last-resort if the API ever disappears.
- **Paste it into Theme Settings by hand (the old way).** Works, but
  it's manual, it's lost the moment anyone experiments in that box,
  and it's exactly what this repo exists to replace. The file is still
  paste-able in an emergency — it's plain CSS.

## Interaction with Patch 002

The Sunset CSS also contains a logo rule (it swaps the navbar `img`
via a data-URI of the same flower). With Patch 002 active the image
files already *are* the flower, so the CSS rule is redundant — same
art, no conflict. The CSS rule's brightness filter still applies on
top in the navbar, which is the look the theme was tuned for.

## Switching back to the gold theme

`assets/gold-theme.css` is Penny's previous theme, preserved
**verbatim** from the settings backup she exported on 2026-11-25
(the `theme.customCss` value, byte for byte). To switch back: set
`GALLERY_THEME_CSS=/patches/gold-theme.css` on the `gallery-patcher`
service in `docker-compose.patches.yml` and run
`scripts/apply-theme.sh`. Same applier, same verification.

## Limits

- Needs the one-time API key (above). No key, no theme — by design,
  and the patcher says so in its log.
- If someone sets `IMMICH_CONFIG_FILE` on the server later, this patch
  stops working (the server will reject the PUT). Don't.
- The theme itself inherits the limits in its own header comment:
  web UI only, mobile app untouched.
