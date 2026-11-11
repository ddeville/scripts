pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQml.Models
import Quickshell
import "../../ui"
import "../../services"

ShellPopup {
    id: root

    required property Agents backend
    readonly property string homePath: Quickshell.env("HOME")

    implicitWidth: 500
    padding: 12
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

    SortFilterProxyModel {
        id: filteredAgents

        sourceModel: root.backend.agents
        filters: ValueFilter {
            roleName: "needsAttention"
            value: true
            enabled: attentionFilter.checked
        }
    }

    contentItem: Column {
        spacing: 10

        RowLayout {
            width: parent.width
            spacing: 8

            Icon {
                name: "agent"
                color: Theme.selected
            }

            Text {
                Layout.fillWidth: true
                text: "Agents"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: 14
            }

            Button {
                id: attentionFilter

                text: "Needs you · " + root.backend.attention
                checkable: true
                selected: checked
                foreground: checked ? Theme.selected : Theme.muted
                tooltip: checked ? "Show all agents" : "Show only agents that need attention"
                onClicked: agents.forceActiveFocus(Qt.OtherFocusReason)
            }

            Button {
                symbol: "close"
                tooltip: "Close agents"
                foreground: Theme.muted
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
            model: filteredAgents
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationWraps: true
            section.property: "path"
            section.criteria: ViewSection.FullString
            section.delegate: Text {
                required property string section

                width: agents.width
                height: 28
                text: section.startsWith(root.homePath + "/") ? "~" + section.slice(root.homePath.length) : section || "Unknown location"
                textFormat: Text.PlainText
                elide: Text.ElideLeft
                color: Theme.tertiary
                font.family: Theme.font
                font.pixelSize: 10
                verticalAlignment: Text.AlignVCenter
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_J) {
                    incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_K) {
                    decrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                    attentionFilter.checked = false;
                    event.accepted = true;
                } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                    attentionFilter.checked = true;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (currentIndex >= 0 && currentIndex < count) {
                        const sourceIndex = filteredAgents.mapToSource(filteredAgents.index(currentIndex, 0));
                        root.backend.open(root.backend.agents.get(sourceIndex.row).threadId);
                    }
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
                required property string preview
                required property bool isChild
                required property string project
                required property string path
                required property string status
                required property string error

                width: agents.width - (agents.contentHeight > agents.height ? 10 : 0)
                implicitHeight: implicitContentHeight + topPadding + bottomPadding
                padding: 8
                enabled: root.backend.available && !root.backend.busy
                highlighted: ListView.isCurrentItem && agents.activeFocus
                onClicked: {
                    agents.currentIndex = index;
                    root.backend.open(threadId);
                }
                Accessible.name: title + " · " + root.backend.label(status) + " · " + project

                contentItem: RowLayout {
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 3
                        Layout.fillHeight: true
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                        radius: 1.5
                        color: root.backend.color(agent.status)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                Layout.fillWidth: true
                                text: (agent.isChild ? "↳ " : "") + agent.title
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: agent.status === "idle" ? Theme.foreground : root.backend.color(agent.status)
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            Text {
                                text: root.backend.label(agent.status)
                                color: root.backend.color(agent.status)
                                font.family: Theme.font
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: agent.error || agent.preview
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
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
                        text: agent.title + "\n" + agent.path + " · " + (({
                                    codex: "Codex",
                                    claude: "Claude"
                                })[agent.agentType] || "Unknown") + (agent.error ? "\n" + agent.error : "")
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
            text: root.backend.actionError || (root.backend.busy ? "Opening agent…" : agents.count > 0 ? "h/l filter · j/k navigate · Enter open" : root.backend.available && attentionFilter.checked ? "No agents need your attention." : "Your running tmux agents will appear here.")
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
