import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: window

    readonly property string prompt: Quickshell.env("ASKPASS_PROMPT") || "Enter your password:"
    readonly property string fifoPath: Quickshell.env("ASKPASS_FIFO")

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
        implicitWidth: 380
        implicitHeight: layout.implicitHeight + 48
        radius: 28
        color: window.palette.surfaceContainer
        border.width: 1
        border.color: Qt.alpha(window.palette.outline, 0.4)

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "🔒"
                font.pixelSize: 26
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                text: window.prompt
                color: window.palette.onSurface
                font.pixelSize: 15
                font.family: "Google Sans Flex"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: height / 2
                color: Qt.darker(window.palette.surfaceContainer, 1.15)
                border.width: field.activeFocus ? 2 : 1
                border.color: field.activeFocus ? window.palette.primary : Qt.alpha(window.palette.outline, 0.5)

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                TextField {
                    id: field

                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: window.palette.onSurface
                    selectionColor: window.palette.primary
                    font.pixelSize: 16
                    selectByMouse: true
                    background: null

                    Keys.onEscapePressed: window.finish("")
                    Keys.onReturnPressed: window.finish(text)
                    Keys.onEnterPressed: window.finish(text)

                    Component.onCompleted: forceActiveFocus()
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
                    onClicked: window.finish(field.text)

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
