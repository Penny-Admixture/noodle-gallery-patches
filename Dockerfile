# noodle-gallery-patches — derived image for Noodle Gallery (open-noodle/gallery).
#
# This is NOT a fork. The image starts FROM the real upstream gallery-server
# image and layers ONLY our patches on top. Our whole codebase is this repo:
# this Dockerfile, the patches/ folder, and the assets/ folder.
#
# Why gallery-server and not a separate web image: in this fork the web UI
# is built INTO the server image. Verified against open-noodle/gallery
# v5.11.1, server/Dockerfile:
#     COPY --from=web /usr/src/app/web/build /build/www
# so the built web client lives at /build/www, and the files from
# web/static/ land there verbatim — stable filenames, no content hashing.
# Penny's compose has no separate web service; the server serves the UI
# on port 2283. See patches/PATCHES.md for the full patch manifest.
#
# Bump the upstream version with:  ./build.sh vX.Y.Z
# (build.sh passes UPSTREAM_TAG through and re-tags the derived image.)

ARG UPSTREAM_TAG=v5.11.1
FROM ghcr.io/open-noodle/gallery-server:${UPSTREAM_TAG}

# --- Patch 002: logo swap ---------------------------------------------------
# Fail loudly if upstream moved or renamed any of the 8 logo files.
# A silent miss here is exactly the maintenance failure this repo exists
# to prevent: the build stops and says which file is gone.
RUN set -eu; \
    for f in gallery-logo-mark.svg gallery-logo-mark-dark.svg \
             gallery-logo-inline-light.svg gallery-logo-inline-dark.svg \
             gallery-logo-stacked.svg gallery-logo-stacked-dark.svg \
             gallery-loader.svg gallery-loader-dark.svg; do \
      if [ ! -f "/build/www/$f" ]; then \
        echo "PATCH 002 FAILED: /build/www/$f not found in the upstream image." >&2; \
        echo "Upstream changed the web layout. Re-check the path table in" >&2; \
        echo "web/src/lib/components/shared-components/Logo.svelte against" >&2; \
        echo "patches/002-logo-swap/README.md, then fix this Dockerfile." >&2; \
        exit 1; \
      fi; \
    done; \
    echo "patch 002: all 8 upstream logo files found in /build/www"

# Square slots -> the spirograph flower mark.
#   gallery-logo-mark.svg   navbar icon; also the login page's blurred
#                           backdrop (AuthPageLayout.svelte, verified).
#   gallery-loader.svg      login card logo (Logo variant="icon",
#                           transparent=true) and other loading states.
COPY assets/spirograph-flower-mark.svg /build/www/gallery-logo-mark.svg
COPY assets/spirograph-flower-mark.svg /build/www/gallery-loader.svg
# Dark square slots -> the lightened flower variant
# (assets/logo-mark-dark.svg: same art, fill #1E3CDC -> #8FB0FF, so the
# mark stays readable on dark chrome without any CSS filter).
COPY assets/logo-mark-dark.svg /build/www/gallery-logo-mark-dark.svg
COPY assets/logo-mark-dark.svg /build/www/gallery-loader-dark.svg
# Wide slots -> the stacked 1009 collage logo.
COPY assets/1009-collage-logo.svg /build/www/gallery-logo-stacked.svg
COPY assets/1009-collage-logo.svg /build/www/gallery-logo-stacked-dark.svg
COPY assets/1009-collage-logo.svg /build/www/gallery-logo-inline-light.svg
COPY assets/1009-collage-logo.svg /build/www/gallery-logo-inline-dark.svg

# --- Patch 001: Outlook Sunset theme ----------------------------------------
# Custom CSS lives in the server's system config (theme.customCss), not in
# a file, so it cannot be COPYed into place. Instead the CSS and its
# applier ship inside the image, and the one-shot gallery-patcher service
# (docker-compose.patches.yml) runs the applier against the server API
# once the server is healthy. See patches/001-outlook-sunset-theme/.
COPY assets/outlook-sunset.css /patches/outlook-sunset.css
COPY assets/gold-theme.css /patches/gold-theme.css
COPY patches/001-outlook-sunset-theme/apply-theme.mjs /patches/apply-theme.mjs
RUN set -eu; \
    test -s /patches/outlook-sunset.css; \
    test -s /patches/gold-theme.css; \
    test -s /patches/apply-theme.mjs; \
    echo "patch 001: theme CSS + applier in place at /patches"
