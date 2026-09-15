/*
 * Ambient Photos screensaver.
 *
 * Renders the installed webos-photos-slideshow app instead of the
 * upstream bouncing-logo demo. Everything else about this fork is
 * upstream: apply.sh still bind-mounts this file over the system
 * screensaver's QML, and the frontend's Autostart toggle still
 * symlinks apply.sh into /var/lib/webosbrew/init.d/.
 *
 * Usage:
 *   mount --bind ./screensaver-main.qml /usr/palm/applications/com.webos.app.screensaver/qml/main.qml
 *
 * Test launch (no way to trigger on "No signal" screen)
 *   luna-send -n 1 'luna://com.webos.service.tvpower/power/turnOnScreenSaver' '{}'
 */
import QtQuick 2.4
import Eos.Window 0.1
import QtQuick.Window 2.2
import QtWebEngine 1.5

WebOSWindow {
    id: window

    width: 1920
    height: 1080

    windowType: "_WEBOS_WINDOW_TYPE_SCREENSAVER"
    color: "black"

    title: "Screensaver"
    appId: "com.webos.app.screensaver"
    visible: true

    // Must match WEBOS_APP_ID (the value the GitHub Action injects into
    // src/appinfo.json "id" at build time), since that determines the
    // install path ares-install writes to.
    property string photosAppId: "com.nadavcoh.ambientphotos"

    Item {
        id: root
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: 'black'
        }

        WebEngineView {
            anchors.fill: parent
            url: "file:///media/developer/apps/usr/palm/applications/" +
                 window.photosAppId + "/index.html"
        }
    }
}
