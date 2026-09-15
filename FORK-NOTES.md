# Ambient Photos screensaver — as a fork of webosbrew/custom-screensaver

## What actually changed

Commit 1 (**the only required one**): `assets/screensaver-main.qml`,
18 insertions / 54 deletions. Net *negative* — the boing animation was
more code than a web view.

Commit 2 (**optional, cosmetic**): rebrand under a separate app id so
the fork can coexist with upstream instead of replacing it. Touches
`appinfo.json`, `package.json`, `frontend/views/MainPanel.js`.

Nothing else is needed. In particular, all of these turned out to be
unnecessary once I read the upstream code properly:

- **No `init.d` installer script.** `MainPanel.js`'s `autostartToggle`
  already does `ln -sf <applyPath> /var/lib/webosbrew/init.d/50-...`
  via the Homebrew Channel's root `exec` service. Autostart is a
  toggle in the app's own UI.
- **No `apply.sh` changes.** It's already generic — it bind-mounts
  whatever `screensaver-main.qml` sits beside it.
- **No local http server.** Per your correction, `file://` is fine on
  the TV.
- **No idle-detection service.** `com.webos.service.tvpower` already
  launches `com.webos.app.screensaver` on idle; the bind-mount means
  it launches your QML.

## Applying

```bash
git clone --recursive https://github.com/webosbrew/custom-screensaver ambient-screensaver
cd ambient-screensaver
git am /path/to/0001-*.patch          # required
git am /path/to/0002-*.patch          # optional rebrand
```

Then set `photosAppId` in `assets/screensaver-main.qml` to whatever
`WEBOS_APP_ID` your GitHub Action injects into `src/appinfo.json`.

## Build & install

Upstream's own npm scripts, unchanged:

```bash
npm ci
npm run build -- --production
npm run package
npm run deploy      # ares-install
npm run launch      # ares-launch
```

Then in the app on the TV: toggle **Autostart** → tap **Test run
screensaver**.

## The one real risk

`QtWebEngine 1.5` must exist on your firmware. Check before building:

```bash
ssh -i ~/.ssh/<device>/webos_rsa -p 9922 root@<tv-ip> \
  "ls /usr/lib/qt5/qml | grep -i web"
```

If you see `QtWebEngine`, you're set. If you only see `QtWebKit`, swap
the import to `import QtWebKit 3.0` and `WebEngineView` → `WebView`
(same `url` / `anchors.fill` API), though that engine is old enough
that your app's async/fetch code may not run cleanly. If neither is
present, fall back to the launcher approach — QML stub that calls
`luna://com.webos.applicationManager/launch` on the installed app —
which was `screensaver-main-launch-wam.qml` in the previous archive.
