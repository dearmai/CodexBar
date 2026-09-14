import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Shared/Usage.js" as Usage

ApplicationWindow {
    id: window
    title: qsTr("Usage & Spend")
    width: 820; height: 700
    minimumWidth: 480; minimumHeight: 420
    property int selectedTab: 0
    readonly property bool refreshing: selectedTab === 0 ? desktop.busy : desktop.costBusy
    function refreshCurrent() {
        if (selectedTab === 0) desktop.refresh();
        else desktop.refreshCosts();
    }
    onClosing: function(event) { event.accepted = false; hide(); }
    Shortcut { sequence: "Ctrl+R"; onActivated: window.refreshCurrent() }
    Shortcut { sequence: "Ctrl+,"; onActivated: desktop.showWindow("settings") }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Escape"; onActivated: window.hide() }
    header: ToolBar {
        RowLayout {
            anchors.fill: parent; anchors.margins: 10
            Label { text: "CodexBar"; font.pixelSize: 22; font.bold: true; Layout.fillWidth: true }
            ToolButton {
                text: qsTr("Menu")
                onClicked: appMenu.open()
                Menu {
                    id: appMenu
                    MenuItem { text: qsTr("Copy summary"); enabled: desktop.entries.length > 0; onTriggered: desktop.copySummary() }
                    MenuSeparator {}
                    MenuItem { text: qsTr("Quit CodexBar"); onTriggered: Qt.quit() }
                }
            }
            ToolButton { text: qsTr("Settings…"); onClicked: desktop.showWindow("settings") }
        }
        implicitHeight: 64
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: width < 500 ? 12 : 20
        spacing: 12
        TabBar {
            Layout.fillWidth: true
            currentIndex: window.selectedTab
            TabButton { text: qsTr("Usage"); onClicked: { window.selectedTab = 0; desktop.showWindow("usage"); } }
            TabButton { text: qsTr("Spending"); onClicked: { window.selectedTab = 1; desktop.showWindow("spending"); } }
        }
        Label {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            visible: window.selectedTab === 0
            text: desktop.error || (desktop.busy ? qsTr("Refreshing usage…") :
                desktop.stale ? qsTr("Usage is out of date") :
                desktop.updated ? qsTr("Updated %1").arg(desktop.updated) : qsTr("Waiting for usage…"))
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scroll.availableWidth
                spacing: 16
                Repeater {
                    model: window.selectedTab === 0 ? desktop.entries : []
                    UsageCard { required property var modelData; entry: modelData }
                }
                Label {
                    visible: window.selectedTab === 1
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: qsTr("Estimated cost of local Codex and Claude sessions, across accounts.")
                    opacity: 0.7
                }
                Label {
                    visible: window.selectedTab === 1
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: !desktop.settings.showCosts ? qsTr("Enable local spending in Settings.")
                        : desktop.costBusy ? qsTr("Reading local history…") : desktop.costError
                }
                Repeater {
                    model: window.selectedTab === 1 && desktop.settings.showCosts ? desktop.spending : []
                    Frame {
                        required property var modelData
                        Layout.fillWidth: true; padding: 14
                        ColumnLayout {
                            width: parent.width; spacing: 12
                            Label { text: Usage.providerName(modelData.provider); font.pixelSize: 18; font.bold: true }
                            Label { text: Usage.provenance(modelData.provenance); opacity: 0.65; Layout.fillWidth: true; wrapMode: Text.Wrap }
                            Label { text: modelData.error; visible: text !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap }
                            Label { text: qsTr("Today  %1     30 days  %2").arg(Usage.money(modelData.today)).arg(Usage.money(modelData.month)); font.pixelSize: 18; Layout.fillWidth: true; wrapMode: Text.Wrap }
                            Label { text: qsTr("%1 tokens").arg(Usage.count(modelData.tokens)) }
                            Label {
                                Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.7
                                text: qsTr("Input %1 · output %2 · cached %3").arg(Usage.count(modelData.input))
                                    .arg(Usage.count(modelData.output)).arg(Usage.count(modelData.cached))
                            }
                            Label { text: modelData.coverage; opacity: 0.7; Layout.fillWidth: true; wrapMode: Text.Wrap }
                            UsageChart { Layout.fillWidth: true; chart: modelData.chart }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Button { text: window.refreshing ? qsTr("Refreshing…") : qsTr("Refresh"); enabled: !window.refreshing && (window.selectedTab === 0 || desktop.settings.showCosts); onClicked: window.refreshCurrent() }
            Item { Layout.fillWidth: true }
            Button { text: qsTr("Close"); onClicked: window.hide() }
        }
    }
}
