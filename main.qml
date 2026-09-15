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

    function finish(text: string): void {
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
        border.color: Qt.alpha(window.palette.outline, 0.4)

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: 28
            spacing: 22

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "🔒"
                font.pixelSize: 32
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                text: window.prompt
                color: window.palette.onSurface
                font.pixelSize: 22
                font.bold: true
                font.letterSpacing: 0.2
                font.family: "Google Sans Flex"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
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
                border.width: inputArea.activeFocus ? 2 : 1
                border.color: inputArea.activeFocus ? window.palette.primary : Qt.alpha(window.palette.outline, 0.5)

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
                        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
                            window.buffer += event.text;
                        }
                        event.accepted = true;
                    }

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
                spacing: 12

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    text: "Cancel"
                    flat: true
                    onClicked: window.finish("")

                    contentItem: Text {
                        text: "Cancel"
                        color: window.palette.onSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: "transparent"
                    }
                }

                Button {
                    text: "Unlock"
                    onClicked: window.finish(window.buffer)

                    contentItem: Text {
                        text: "Unlock"
                        color: window.palette.onPrimary
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        implicitWidth: 88
                        implicitHeight: 36
                        radius: height / 2
                        color: window.palette.primary
                    }
                }
            }
        }
    }
}
