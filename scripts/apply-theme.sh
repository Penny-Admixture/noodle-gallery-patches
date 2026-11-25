#!/usr/bin/env bash
# Run the Patch 001 theme applier once, on demand.
#
# Run this from the folder that holds docker-compose.yml and
# docker-compose.patches.yml. It runs the same applier the stack runs
# at startup — there is no second code path to drift out of sync.
#
# To switch back to the previous (gold) theme instead, set
# GALLERY_THEME_CSS=/patches/gold-theme.css on the gallery-patcher
# service in docker-compose.patches.yml and run this script.
# (assets/gold-theme.css is Penny's pre-Sunset theme, preserved verbatim
# from her 2026-11-25 settings backup.)
set -euo pipefail
docker compose -f docker-compose.yml -f docker-compose.patches.yml run --rm gallery-patcher
