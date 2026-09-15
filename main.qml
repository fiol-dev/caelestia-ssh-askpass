import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import M3Shapes

PanelWindow {
    id: window

    readonly property string prompt: Quickshell.env("ASKPASS_PROMPT") || "Enter your password:"
    readonly property string fifoPath: Quickshell.env("ASKPASS_FIFO")
    property string buffer: ""

    // ssh/ssh-add reuse the askpass prompt text to signal a failed retry
    // (e.g. "Bad passphrase, try again for /home/user/.ssh/id_ed25519:"), so
    // parse it into a short one-line label plus an optional key name instead
    // of showing the whole sentence as the title.
    readonly property var parsed: {
        const raw = window.prompt.trim();
        const bad = raw.match(/^bad passphrase, try again for (.+):$/i);
        if (bad)
            return {
                error: true,
                label: "Wrong passphrase, try again",
                keyName: bad[1].split("/").pop()
            };
        const enter = raw.match(/^enter passphrase for (?:key )?['"]?(.+?)['"]?:$/i);
        if (enter)
            return {
                error: false,
                label: "Enter your passphrase",
                keyName: enter[1].split("/").pop()
            };
        return {
            error: false,
            label: raw,
            keyName: ""
        };
    }

    // Used until scheme.json loads (or if it's missing entirely).
    readonly property var fallbackPalette: ({
        surfaceContainer: "#221716",
        onSurface: "#f9e0dd",
        onSurfaceVariant: "#bca6a3",
        primary: "#f9b6ad",
        onPrimary: "#61332e",
        outline: "#84716e",
        error: "#f97386"
    })
    property var palette: fallbackPalette

    // Each askpass invocation is its own short-lived process, so there's no
    // channel back from ssh telling us whether what we submit is accepted —
    // the only feedback we ever get is indirect, via the *next* invocation's
    // prompt (see `parsed` above). So logging here is necessarily best-effort:
    // we can log a rejection as soon as we learn about it (next invocation
    // starts with an error prompt), and log that a passphrase was submitted,
    // but never "accepted" — that fact never reaches an askpass at all.
    function logPrefixed(message: string): void {
        console.log(`[caelestia-ssh-askpass] ${message}`);
    }

    Component.onCompleted: {
        if (window.parsed.error)
            window.logPrefixed(`Passphrase rejected for '${window.parsed.keyName}'; prompting again.`);
    }

    function finish(text: string): void {
        const key = window.parsed.keyName || "key";
        if (text.length === 0)
            logPrefixed(`Cancelled the prompt for '${key}'.`);
        else
            logPrefixed(`Passphrase submitted for '${key}'.`);

        // Argv-passed, not shell-interpolated, so the password can contain any character safely.
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" > \"$2\"", "_", text, fifoPath]);
        Qt.quit();
    }

    WlrLayershell.namespace: "caelestia-ssh-askpass"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    FileView {
        id: schemeFile

        path: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/caelestia/scheme.json`

        onLoaded: {
            try {
                const c = JSON.parse(text()).colours;
                window.palette = {
                    surfaceContainer: `#${c.surfaceContainer}`,
                    onSurface: `#${c.onSurface}`,
                    onSurfaceVariant: `#${c.onSurfaceVariant}`,
                    primary: `#${c.primary}`,
                    onPrimary: `#${c.onPrimary}`,
                    outline: `#${c.outline}`,
                    error: `#${c.error}`
                };
            } catch (e) {
                // Keep fallbackPalette.
            }
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        implicitWidth: 440
        implicitHeight: layout.implicitHeight + 56
        radius: 32
        color: window.palette.surfaceContainer
        border.width: 1
        border.color: Qt.alpha(window.parsed.error ? window.palette.error : window.palette.outline, window.parsed.error ? 0.7 : 0.4)

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }

        SequentialAnimation {
            id: shake

            loops: 1
            NumberAnimation {
                target: card
                property: "anchors.horizontalCenterOffset"
                from: 0
                to: 10
                duration: 45
            }
            NumberAnimation {
                target: card
                property: "anchors.horizontalCenterOffset"
                from: 10
                to: -10
                duration: 90
            }
            NumberAnimation {
                target: card
                property: "anchors.horizontalCenterOffset"
                from: -10
                to: 0
                duration: 45
            }
        }

        Component.onCompleted: if (window.parsed.error)
            shake.start()

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: 28
            spacing: 22

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    text: window.parsed.label
                    color: window.parsed.error ? window.palette.error : window.palette.onSurface
                    font.pixelSize: 20
                    font.bold: true
                    font.letterSpacing: 0.2
                    font.family: "Google Sans Flex"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 13
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    visible: !!window.parsed.keyName
                    text: window.parsed.keyName
                    color: window.palette.onSurfaceVariant
                    font.pixelSize: 13
                    font.family: "Google Sans Flex"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.NoWrap
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                }
            }

            // Password field: mirrors the lock screen's approach of representing each
            // typed character as an animated MaterialShape blob rather than a plain
            // masked TextField, using the same M3Shapes module caelestia-shell uses.
            Rectangle {
                id: inputBox

                Layout.fillWidth: true
                implicitHeight: 68
                radius: height / 2
                color: Qt.darker(window.palette.surfaceContainer, 1.15)
                border.width: inputArea.activeFocus || window.parsed.error ? 2 : 1
                border.color: {
                    if (window.parsed.error)
                        return window.palette.error;
                    return inputArea.activeFocus ? window.palette.primary : Qt.alpha(window.palette.outline, 0.5);
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: inputArea.forceActiveFocus()
                }

                Item {
                    id: inputArea

                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    focus: true

                    readonly property list<int> shapeQueue: {
                        const shapes = [MaterialShape.Slanted, MaterialShape.Arch, MaterialShape.Fan, MaterialShape.Arrow, MaterialShape.SemiCircle, MaterialShape.Triangle, MaterialShape.Diamond, MaterialShape.ClamShell, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.Sunny, MaterialShape.VerySunny, MaterialShape.Cookie4Sided, MaterialShape.Ghostish, MaterialShape.SoftBurst];
                        for (let i = shapes.length - 1; i > 0; i--) {
                            const j = Math.floor(Math.random() * (i + 1));
                            [shapes[i], shapes[j]] = [shapes[j], shapes[i]];
                        }
                        return shapes;
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            window.finish("");
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            window.finish(window.buffer);
                        } else if (event.key === Qt.Key_Backspace) {
                            window.buffer = (event.modifiers & Qt.ControlModifier) ? "" : window.buffer.slice(0, -1);
                        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            // Leave unaccepted so Keys.onTabPressed/onBacktabPressed below handle it.
                            event.accepted = false;
                            return;
                        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
                            window.buffer += event.text;
                        }
                        event.accepted = true;
                    }
                    Keys.onTabPressed: cancelButton.forceActiveFocus()
                    Keys.onBacktabPressed: unlockButton.forceActiveFocus()

                    Component.onCompleted: forceActiveFocus()

                    Text {
                        anchors.centerIn: parent
                        text: "Enter your password"
                        color: window.palette.onSurfaceVariant
                        font.pixelSize: 18
                        font.family: "Google Sans Flex"
                        opacity: window.buffer ? 0 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 12

                        Repeater {
                            model: window.buffer.length

                            delegate: CharBlob {}
                        }
                    }

                    component CharBlob: Item {
                        id: charItem

                        readonly property real blobSize: 30

                        implicitWidth: blobSize
                        implicitHeight: blobSize

                        MaterialShape {
                            id: shape

                            anchors.centerIn: parent
                            implicitSize: charItem.blobSize
                            shape: inputArea.shapeQueue[index % inputArea.shapeQueue.length] ?? MaterialShape.Circle
                            color: window.palette.onSurface
                            scale: 0
                            opacity: 0

                            Component.onCompleted: popIn.start()

                            SequentialAnimation {
                                id: popIn

                                ParallelAnimation {
                                    NumberAnimation {
                                        target: shape
                                        property: "scale"
                                        to: 1.25
                                        duration: 180
                                        easing.type: Easing.OutBack
                                    }
                                    NumberAnimation {
                                        target: shape
                                        property: "opacity"
                                        to: 1
                                        duration: 120
                                    }
                                }
                                PauseAnimation {
                                    duration: 90
                                }
                                ParallelAnimation {
                                    NumberAnimation {
                                        target: shape
                                        property: "scale"
                                        to: 0.85
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }
                                    PropertyAction {
                                        target: shape
                                        property: "shape"
                                        value: MaterialShape.Circle
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                Item {
                    Layout.fillWidth: true
                }

                // Both buttons share the same implicit height (via padding, not a
                // fixed implicitHeight) so their pill shape and focus ring match
                // regardless of label width. The ring itself is drawn as a halo
                // just outside each button rather than as its own border, so it
                // always sits against the card's surfaceContainer background
                // instead of (for Unlock) the primary fill it would otherwise
                // have almost no contrast against.
                FocusRing {
                    control: cancelButton

                    Button {
                        id: cancelButton

                        anchors.centerIn: parent
                        text: "Cancel"
                        flat: true
                        padding: 12
                        onClicked: window.finish("")

                        Keys.onTabPressed: unlockButton.forceActiveFocus()
                        Keys.onBacktabPressed: inputArea.forceActiveFocus()
                        Keys.onEscapePressed: window.finish("")

                        contentItem: Text {
                            text: "Cancel"
                            color: window.palette.onSurfaceVariant
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            implicitHeight: 40
                            radius: height / 2
                            color: "transparent"
                        }
                    }
                }

                FocusRing {
                    control: unlockButton

                    Button {
                        id: unlockButton

                        anchors.centerIn: parent
                        text: "Unlock"
                        padding: 12
                        onClicked: window.finish(window.buffer)

                        Keys.onTabPressed: inputArea.forceActiveFocus()
                        Keys.onBacktabPressed: cancelButton.forceActiveFocus()
                        Keys.onEscapePressed: window.finish("")

                        contentItem: Text {
                            text: "Unlock"
                            color: window.palette.onPrimary
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            implicitWidth: 88
                            implicitHeight: 40
                            radius: height / 2
                            color: window.palette.primary
                        }
                    }
                }
            }

            component FocusRing: Item {
                id: ring

                required property Item control

                implicitWidth: control.implicitWidth + 8
                implicitHeight: control.implicitHeight + 8

                Rectangle {
                    anchors.centerIn: parent
                    width: ring.control.width + 8
                    height: ring.control.height + 8
                    radius: height / 2
                    color: "transparent"
                    border.width: ring.control.activeFocus ? 2 : 0
                    border.color: window.palette.primary
                }
            }
        }
    }
}
