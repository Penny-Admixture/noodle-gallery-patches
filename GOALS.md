# GOALS — noodle-gallery-patches

## Build 1 — patch-set foundation (2026-11-25)

Penny's ask, in her words: "couldn't we have a little thing where
it's like you pull the real version of image or whatever and then our
thing just kind of like goes through and makes its changes after that
so we might have to update it if they change something out from
underneath us but like more or less like we would keep our code base
separate and just have it be like a patch set" — approved with
"Yes, set up the patch repo" (2026-11-25 ~03:36 EST).

**Done when:**

- [x] Repo tree exists: Dockerfile (derived from
  `ghcr.io/open-noodle/gallery-server:v5.11.1`), `patches/` with a
  manifest, `assets/`, `build.sh`, README/MINIMAP/GOALS.
- [x] Patch 001: Outlook Sunset theme ships in the image and is
  applied via the system-config API by a one-shot patcher — never
  pasted by hand. Mechanism + rejected alternatives documented.
- [x] Patch 002: all 8 logo files in the built web client replaced
  (flower square slots, lightened flower for dark, 1009 collage for
  wide slots), login page included. Every path verified against fork
  source at v5.11.1.
- [x] `build.sh` fails loudly: pre-flight checks, the Dockerfile's
  own missing-file check, post-build sha256 verification.
- [x] Gold theme preserved (`assets/gold-theme.css`, byte-identical
  to Penny's 2026-11-25 backup) with a documented switch-back.
- [x] VM verification done: Dockerfile parse, pre-flight run, CSS
  parse, SVG well-formedness, variant/backup byte checks.
- [ ] Repo created on GitHub (`Penny-Admixture/noodle-gallery-patches`)
  and Build 1 merged to main with read-back verification.
- [ ] First run on Penny's PC: `build.sh`, compose overlay up, eyeball
  navbar + login page + theme, confirm Settings still save, check
  patcher logs. (Needs Docker — cannot be done on the VM.)

## Later (only on Penny's word)

- Patch 003+: whatever else she wants changed in the gallery — she
  said there's a bunch. Each gets a manifest entry, a loud failure,
  and a re-check list, same as 001/002.
- A transparent wide lockup to replace the opaque collage in the
  inline/stacked slots, if the card look bothers her.
