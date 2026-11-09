pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../../ui"
import "../../services"

ShellPopup {
    id: root

    required property Agents backend

    implicitWidth: 420
    implicitHeight: body.implicitHeight + 24
    onOpened: {
        backend.actionError = "";
        agents.forceActiveFocus(Qt.PopupFocusReason);
    }

    Connections {
        target: root.backend
        function onAgentOpened() {
            root.close();
        }
    }

    Column {
        id: body

        x: 12
        y: 12
        width: root.width - 24
        spacing: 10

        Row {
            width: parent.width
            spacing: 8

            Icon {
                name: "agent"
                color: Theme.selected
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                width: parent.width - Theme.iconSize - closeButton.width - 16
                text: "Agents"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }

            Button {
                id: closeButton

                symbol: "close"
                tooltip: "Close agents"
                foreground: Theme.muted
                interactive: true
                onClicked: root.close()
            }
        }

        Text {
            width: parent.width
            text: root.backend.summary
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.backend.color(root.backend.indicatorState)
            font.family: Theme.font
            font.pixelSize: 11
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        ListView {
            id: agents

            width: parent.width
            height: Math.min(480, contentHeight)
            visible: count > 0
            model: root.backend.agents
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationWraps: true
            section.property: "section"
            section.criteria: ViewSection.FullString
            section.delegate: Text {
                required property string section

                height: 26
                text: section.toUpperCase()
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 9
                font.letterSpacing: 0.5
                verticalAlignment: Text.AlignVCenter
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_J) {
                    incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_K) {
                    decrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (currentIndex >= 0 && currentIndex < count)
                        root.backend.open(root.backend.agents.get(currentIndex).threadId);
                    event.accepted = true;
                }
            }

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                policy: Controls.ScrollBar.AsNeeded
            }

            delegate: Controls.ItemDelegate {
                id: agent

                required property int index
                required property string threadId
                required property string agentType
                required property string title
                required property string project
                required property string path
                required property string status
                required property string error

                width: agents.width - (agents.contentHeight > agents.height ? 10 : 0)
                height: 46
                padding: 8
                enabled: root.backend.available && !root.backend.busy
                highlighted: ListView.isCurrentItem && agents.activeFocus
                onClicked: {
                    agents.currentIndex = index;
                    root.backend.open(threadId);
                }
                Accessible.name: title + " · " + root.backend.label(status) + " · " + project

                contentItem: Row {
                    spacing: 8

                    Rectangle {
                        width: 3
                        height: parent.height - 4
                        radius: 1.5
                        color: root.backend.color(agent.status)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - 105
                        spacing: 3

                        Text {
                            width: parent.width
                            text: agent.title
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                        Text {
                            width: parent.width
                            text: (({
                                        codex: "Codex",
                                        claude: "Claude"
                                    })[agent.agentType] || "Unknown") + " · " + agent.project
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 10
                        }
                    }

                    Text {
                        width: 86
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.backend.label(agent.status)
                        horizontalAlignment: Text.AlignRight
                        color: root.backend.color(agent.status)
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                }

                background: Rectangle {
                    radius: 5
                    color: agent.hovered || agent.highlighted ? Theme.hover : Theme.surface
                }

                Controls.ToolTip {
                    visible: agent.hovered
                    delay: 700
                    popupType: Controls.Popup.Item
                    padding: 8
                    contentItem: Text {
                        text: agent.title + "\n" + agent.path + (agent.error ? "\n" + agent.error : "")
                        textFormat: Text.PlainText
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                    background: Rectangle {
                        color: Theme.background
                        radius: 5
                        border.width: 1
                        border.color: Theme.border
                    }
                }
            }
        }

        Text {
            width: parent.width
            text: root.backend.actionError || (root.backend.busy ? "Opening agent…" : root.backend.agents.count > 0 ? "Click an agent to open it in tmux" : "Your running tmux agents will appear here.")
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.backend.actionError ? Theme.alert : Theme.muted
            font.family: Theme.font
            font.pixelSize: 10
        }
    }

    background: Rectangle {
        radius: 10
        color: Theme.background
        border.width: 1
        border.color: Theme.border
    }
}
