# CLAUDE.md — session recovery notes

This file exists so a new Claude session can get oriented on this
project quickly, without re-reading the whole chat history. It
summarizes *why* things are built the way they are — README.md/
FORK-NOTES.md cover *how* to set them up.

## What this is

A fork of `webosbrew/custom-screensaver` that makes the sibling
project `webos-photos-slideshow` run as a true system-level screensaver
on a rooted LG webOS TV, instead of a manually-launched app. Not a new
project — a thin, deliberately minimal patch on top of an existing
open-source homebrew framework.

## The one insight that shaped everything else

The initial ask (from outside this repo) assumed a custom background
service listening for idle-timeout hooks on the Luna service bus —
something like a `service.js` daemon. **That doesn't exist and isn't
needed.** `com.webos.service.tvpower` already runs its own idle timer
and already launches the system app `com.webos.app.screensaver` when
it expires. That app's entire behavior is one file:
`/usr/palm/applications/com.webos.app.screensaver/qml/main.qml`.
Upstream's `assets/apply.sh` just `mount --bind`s a different QML file
over that path. The OS still thinks it's launching its own
screensaver — it's executing ours instead.

Consequence: don't reintroduce a custom idle-detection mechanism if a
future request asks for one. The correct move is always "what does the
QML do when it's launched," not "how do we get it launched."

Similarly: there is no `appinfo.json` privilege flag that grants root.
Root already exists on this TV via Homebrew Channel. What upstream's
frontend app actually does is call `org.webosbrew.hbchannel.service`'s
`exec` LS2 method (already root) to run `apply.sh`, and its Autostart
toggle just symlinks `apply.sh` into
`/var/lib/webosbrew/init.d/50-<name>` (Homebrew Channel runs everything
there as root on every boot). Don't invent a `services.json` or a
custom native service for either of these — they're both already
solved by the framework.

## What changed vs. upstream, and why each commit is separate

1. **`assets/screensaver-main.qml`** (required) — replaced the
   bouncing-logo demo with a `WebEngineView` pointed at the installed
   `webos-photos-slideshow` app via `file://`. Net *fewer* lines than
   the animation it replaced.
   - Originally built as `http://127.0.0.1:8090` via a local BusyBox
     `httpd` daemon, on the assumption that `file://` blocks
     `fetch()`/QR rendering the way desktop Chrome does when testing
     locally (per that project's own README). **That assumption was
     wrong for the actual TV runtime** — corrected by the user, who
     confirmed the TV doesn't apply that restriction. Simplified back
     down to a direct `file://` URL; no daemon needed. If this ever
     needs revisiting, the fallback (embed a browser engine at all) is
     `import QtWebEngine 1.5` first, `import QtWebKit 3.0` /
     `WebView` if that module isn't present on the firmware, and if
     *neither* is present, a QML stub that calls
     `luna://com.webos.applicationManager/launch` on the installed app
     instead of embedding a browser at all (this alternate QML was
     drafted once as `screensaver-main-launch-wam.qml` but is not part
     of this fork's history — recreate it from this description if
     needed, don't assume a file with that name exists).
2. **Rebrand under its own app id** (optional) — `appinfo.json`,
   `package.json`, `frontend/views/MainPanel.js`. Lets this coexist
   with upstream instead of overwriting it. `basePath`/`linkPath` in
   `MainPanel.js` must move in lockstep with the `appinfo.json` id or
   the Autostart toggle silently points at the wrong path.
3. **Modernize `release.yml`** (optional, only matters if cutting
   GitHub releases) — `checkout@v5`/`setup-node@v5`/Node 22,
   `softprops/action-gh-release@v2` replacing two archived actions,
   `permissions: contents: write`, a version-mismatch guard (tag vs.
   `package.json` vs. `appinfo.json` — previously silent), fixed a
   dead `icon160.png` reference in `tools/gen-manifest.js` (repo only
   ever had icon80/icon130), and repointed `package.json`'s
   `repository.url` to a fork placeholder (upstream's URL was still
   there, which would've made the manifest advertise upstream's repo
   as the source). **Untested** — `enyo-dev`/enyojs deps couldn't
   actually be installed in the sandbox this was built in, so `npm ci`
   on Node 22 is unverified. If it fails, pin `node-version` to `20`
   before debugging further.
4. **New `deploy-webos.yml`** — build + Tailscale + `ares-install` to
   the TV, mirroring `webos-photos-slideshow`'s own
   `deploy-webos.yml` pattern exactly (same TV, same novacom key,
   same secret-injection-at-build-time approach). Injects one
   placeholder: `photosAppId` in `screensaver-main.qml`
   (`"com.yourname.ambientphotos"`) from a `PHOTOS_WEBOS_APP_ID`
   secret. **This must equal** whatever `WEBOS_APP_ID` the
   `webos-photos-slideshow` repo's own deploy workflow injects into
   *its* `appinfo.json` — that's the id this screensaver looks up
   under `/media/developer/apps/usr/palm/applications/<id>/index.html`.
   Also injects `appinfo.json`'s `vendor` from
   `github.repository_owner`, same pattern as the sibling repo.
   Installing does **not** enable the screensaver or autostart — that
   toggle is still manual, in the app's own UI on the TV
   (`Autostart` / `Apply temporarily` / `Test run screensaver`). The
   `ares-launch` relaunch line is deliberately left commented out
   rather than wiring root `exec` calls into unattended CI.

Delivered as tarballs of just the new/changed files throughout (per
standing preference), not as a cloned repo — commits 1–3 were also
generated as a real local git history + `git format-patch` output at
one point, in case those `.patch` files are still around and useful,
but the tarball is the artifact actually handed over each time.

## Repo layout (post-fork)

```
appinfo.json                          ← id/vendor/title rebranded (commit 2)
package.json                          ← name rebranded (commit 2); repository.url fixed (commit 3)
assets/
  apply.sh                              unmodified from upstream — already generic
  screensaver-main.qml                  rewritten (commit 1) — WebEngineView, file://
  icon80.png, icon130.png               unmodified
frontend/
  App.js, index.js, views/MainView.js   unmodified
  views/MainPanel.js                    basePath/linkPath/title updated (commit 2)
tools/
  gen-manifest.js                       icon160.png → icon130.png fix (commit 3)
  sync-version.js                       unmodified
.github/workflows/
  main.yml                              unmodified (build & test on push/PR)
  release.yml                           modernized (commit 3)
  deploy-webos.yml                      new — push-to-TV (item 4 above)
```

## Full secret inventory for `deploy-webos.yml`

Reused from `webos-photos-slideshow` (same TV, same keypair):
`TS_OAUTH_CLIENT_ID`, `TS_OAUTH_SECRET`, `WEBOS_TV_HOST`,
`WEBOS_TV_SSH_KEY_B64`, `TV_PASSPHRASE`.

New to this repo: `PHOTOS_WEBOS_APP_ID` (must match the other repo's
`WEBOS_APP_ID` secret value exactly).

## Open items / things a new session might need to pick up

- None of this has been applied to a real fork or run against real CI
  yet — everything above was authored and validated locally (QML
  syntax by inspection, workflow YAML parsed with PyYAML) but not
  exercised against an actual `enyo pack` build or a real device.
- `QtWebEngine` module availability on the actual TV's firmware has
  not been confirmed. This is the single biggest risk to commit 1
  actually working — check with
  `ssh ... "ls /usr/lib/qt5/qml | grep -i web"` before relying on it,
  and fall back per the note under item 1 above if it's missing.
- `repository.url` in `package.json` still needs to be set to the
  real fork URL (currently a `yourname` placeholder) before any real
  tag/release is cut.
- The rebrand commit (2) is optional and hasn't been confirmed as
  wanted long-term vs. just overwriting upstream's own app id — revisit
  if that decision changes.
