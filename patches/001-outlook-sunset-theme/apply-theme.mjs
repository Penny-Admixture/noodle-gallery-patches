#!/usr/bin/env node
// Patch 001 — Outlook Sunset theme applier.
//
// Sets theme.customCss on a running Noodle Gallery server to the contents
// of the theme CSS file, through the server's own system-config API —
// the exact same value the admin UI would save if the CSS were pasted
// into Theme Settings by hand, except nobody pastes anything.
//
// Verified against open-noodle/gallery v5.11.1 source:
//   web route: PUT /api/system-config (server/src/controllers/
//   system-config.controller.ts, @Put, admin + SystemConfigUpdate),
//   service: updateAdminConfig (server/src/services/
//   system-config.service.ts). This script GETs the full config, changes
//   only theme.customCss, and PUTs the full config back — identical to
//   what the admin UI sends, so it does not depend on partial-update
//   merge semantics.
//
// Idempotent: if the server's Custom CSS already equals the file, it
// logs that and exits 0 without writing.
//
// Environment:
//   GALLERY_ADMIN_API_KEY  (required) an API key from an ADMIN account
//                          (Administration -> API Keys). Sent as the
//                          x-api-key header.
//   GALLERY_BASE_URL       default http://immich-server:2283
//                          (the compose service name; use
//                          http://localhost:2283 for host-side runs)
//   GALLERY_THEME_CSS      default /patches/outlook-sunset.css
//                          (point it at /patches/gold-theme.css — mounted
//                          the same way — to switch back; see README)
//
// Exit codes: 0 = applied, already applied. 1 = anything else, with the
// reason on stderr. Loud on purpose.

import { readFile } from 'node:fs/promises';

const baseUrl = (process.env.GALLERY_BASE_URL || 'http://immich-server:2283').replace(/\/+$/, '');
const apiKey = process.env.GALLERY_ADMIN_API_KEY || '';
const cssPath = process.env.GALLERY_THEME_CSS || '/patches/outlook-sunset.css';

const log = (...args) => console.log('[patch-001]', ...args);
const fail = (message) => {
  console.error('[patch-001] FAILED:', message);
  process.exit(1);
};

if (!apiKey) {
  fail(
    'GALLERY_ADMIN_API_KEY is not set, so the theme was NOT applied. ' +
      'Create an API key in the Gallery UI (Administration -> API Keys, on an admin account), ' +
      'add GALLERY_ADMIN_API_KEY=<the key> to the .env file next to docker-compose.yml, ' +
      'then re-run the patcher (scripts/apply-theme.sh).',
  );
}

let css;
try {
  css = await readFile(cssPath, 'utf8');
} catch (error) {
  fail(`cannot read the theme file ${cssPath}: ${error.message}`);
}
if (!css || !css.trim()) {
  fail(`the theme file ${cssPath} is empty. Theme NOT applied.`);
}

const headers = { 'x-api-key': apiKey, 'content-type': 'application/json' };
const api = (path, options = {}) =>
  fetch(`${baseUrl}/api${path}`, { ...options, headers: { ...headers, ...(options.headers || {}) } });

// Wait for the server. The compose overlay already gates this service on
// the server being healthy; the retry loop is belt-and-braces so a slow
// start is never reported as a failed patch.
let config = null;
for (let attempt = 1; attempt <= 30; attempt++) {
  try {
    const res = await api('/system-config');
    if (res.ok) {
      config = await res.json();
      break;
    }
    if (res.status === 401 || res.status === 403) {
      fail(
        `the server rejected the API key (HTTP ${res.status}). ` +
          'The key must belong to an admin account. Theme NOT applied.',
      );
    }
    log(`server answered HTTP ${res.status}; retry ${attempt}/30 in 5s...`);
  } catch (error) {
    log(`server not reachable yet (${error.cause?.code || error.message}); retry ${attempt}/30 in 5s...`);
  }
  await new Promise((resolve) => setTimeout(resolve, 5000));
}
if (!config) {
  fail('the server did not answer after 30 retries. Theme NOT applied.');
}

const current = config?.theme?.customCss ?? '';
if (current === css) {
  log('the server already has this exact Custom CSS. Nothing to do.');
  process.exit(0);
}

config.theme = { ...(config.theme || {}), customCss: css };
const put = await api('/system-config', { method: 'PUT', body: JSON.stringify(config) });
if (!put.ok) {
  fail(`PUT /system-config answered HTTP ${put.status}: ${await put.text()}`);
}

// Read it back and compare — "the API said OK" is not proof.
const check = await api('/system-config');
const after = check.ok ? (await check.json())?.theme?.customCss : null;
if (after !== css) {
  fail('verification failed: the Custom CSS on the server does not match the theme file after the PUT.');
}
log(`applied ${cssPath} as theme.customCss and verified it by reading it back.`);
