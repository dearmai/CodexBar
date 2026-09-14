import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Shared/Usage.js" as Usage

ApplicationWindow {
    id: window
    title: qsTr("Settings")
    width: 680; height: 720
    minimumWidth: 500; minimumHeight: 480
    property string feedback: ""
    property int section: 0
    property var providerOrder: []
    function moveProvider(index, offset) {
        var order = providerOrder.slice();
        var item = order.splice(index, 1)[0]; order.splice(index + offset, 0, item);
        providerOrder = order;
    }
    onClosing: function(event) { event.accepted = false; hide(); }
    onVisibleChanged: if (visible) load()
    function load() {
        var s = desktop.settings;
        provider.editText = s.provider; source.currentIndex = source.model.indexOf(s.source);
        account.value = s.accountIndex; allAccounts.checked = s.allAccounts;
        identity.checked = s.showIdentity; costs.checked = s.showCosts; status.checked = s.showStatus;
        notices.checked = s.notifications; threshold.value = s.notifyThreshold; interval.value = s.refreshSeconds;
        providerOrder = s.providerOrder.slice();
        quota.currentIndex = quota.model.indexOf(s.quotaDisplay);
        reset.currentIndex = reset.model.indexOf(s.resetDisplay);
        trayStyle.currentIndex = trayStyle.model.indexOf(s.trayStyle);
        theme.checked = s.followOmarchyTheme; pace.checked = s.showPace; warnings.checked = s.warningColors;
        refreshOnOpen.checked = s.refreshOnOpen;
        tray.checked = s.showTray; executable.text = s.executable; feedback = "";
    }
    Shortcut { sequence: "Escape"; onActivated: window.hide() }
    header: ToolBar {
        Label { anchors.left: parent.left; anchors.leftMargin: 24; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Settings"); font.pixelSize: 22; font.bold: true }
        implicitHeight: 64
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 16; spacing: 12
        TabBar {
            Layout.fillWidth: true
            currentIndex: window.section
            TabButton { text: qsTr("General"); onClicked: window.section = 0 }
            TabButton { text: qsTr("Providers"); onClicked: window.section = 1 }
            TabButton { text: qsTr("Advanced"); onClicked: window.section = 2 }
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: availableWidth; clip: true
            ColumnLayout {
                width: scroll.availableWidth; spacing: 20
                GroupBox {
                    title: qsTr("Provider"); Layout.fillWidth: true; visible: window.section === 1
                    ColumnLayout {
                        anchors.fill: parent; spacing: 10
                        Label { text: qsTr("Provider") }
                        ComboBox {
                            id: provider; Layout.fillWidth: true; editable: true
                            model: ["codex", "claude", "both", "enabled", "cursor", "gemini", "copilot", "antigravity", "custom", "all"]
                            validator: RegularExpressionValidator { regularExpression: /^[a-z0-9-]{1,80}$/ }
                        }
                        ColumnLayout {
                            visible: provider.editText === "custom"
                            Layout.fillWidth: true
                            RowLayout {
                                Layout.fillWidth: true
                                ComboBox { id: available; model: desktop.providers; textRole: "displayName"; Layout.fillWidth: true }
                                Button {
                                    text: qsTr("Add")
                                    enabled: available.currentIndex >= 0
                                    onClicked: {
                                        var id = desktop.providers[available.currentIndex].provider;
                                        if (window.providerOrder.indexOf(id) < 0) window.providerOrder = window.providerOrder.concat([id]);
                                    }
                                }
                            }
                            Repeater {
                                model: window.providerOrder
                                RowLayout {
                                    required property string modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Label { text: Usage.providerName(modelData); Layout.fillWidth: true; wrapMode: Text.Wrap }
                                    Button { text: "↑"; Accessible.name: qsTr("Move %1 up").arg(modelData); enabled: index > 0; onClicked: window.moveProvider(index, -1) }
                                    Button { text: "↓"; Accessible.name: qsTr("Move %1 down").arg(modelData); enabled: index < window.providerOrder.length - 1; onClicked: window.moveProvider(index, 1) }
                                    Button { text: qsTr("Remove"); onClicked: { var order = window.providerOrder.slice(); order.splice(index, 1); window.providerOrder = order; } }
                                }
                            }
                        }
                        Label { text: qsTr("Choose custom to select and order providers, or enabled to follow your CLI configuration."); Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.65 }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: qsTr("Source"); Layout.fillWidth: true }
                            ComboBox { id: source; model: ["auto", "oauth", "cli", "api", "web"] }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: qsTr("Account (0 = default)"); Layout.fillWidth: true; wrapMode: Text.Wrap }
                            SpinBox { enabled: !allAccounts.checked && ["custom", "both", "all", "enabled"].indexOf(provider.editText) < 0; id: account; from: 0; to: 999; editable: true }
                        }
                        Option { enabled: ["custom", "both", "all", "enabled"].indexOf(provider.editText) < 0; id: allAccounts; text: qsTr("All accounts") }
                        Option { id: identity; text: qsTr("Show account identity") }
                        RowLayout {
                            Layout.fillWidth: true
                            ComboBox { id: loginProvider; model: ["codex", "claude"]; Layout.fillWidth: true }
                            Button {
                                text: qsTr("Sign in…")
                                onClicked: {
                                    if (desktop.accountAction(loginProvider.currentText, "login"))
                                        window.feedback = qsTr("Finish signing in in the terminal, then refresh usage.");
                                }
                            }
                            Button { text: qsTr("Sign out…"); onClicked: signOut.open() }
                        }
                        Label { text: qsTr("Sign-in opens your provider CLI in a terminal. Account selection above only changes displayed usage."); Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.65 }
                    }
                }
                GroupBox {
                    title: qsTr("Updates"); Layout.fillWidth: true; visible: window.section === 0
                    ColumnLayout {
                        anchors.fill: parent; spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: qsTr("Refresh every (seconds)"); Layout.fillWidth: true; wrapMode: Text.Wrap }
                            SpinBox { id: interval; from: 60; to: 3600; stepSize: 60; editable: true }
                        }
                        Option { id: refreshOnOpen; text: qsTr("Refresh when opening usage") }
                        Option { id: notices; text: qsTr("Notify about low quota, resets, and outages") }
                        RowLayout {
                            Layout.fillWidth: true; enabled: notices.checked
                            Label { text: qsTr("Remaining quota threshold (%)"); Layout.fillWidth: true; wrapMode: Text.Wrap }
                            SpinBox { id: threshold; from: 1; to: 99; editable: true }
                        }
                        Option { id: status; text: qsTr("Service status") }
                    }
                }
                GroupBox {
                    title: qsTr("Desktop"); Layout.fillWidth: true; visible: window.section === 0
                    ColumnLayout {
                        anchors.fill: parent; spacing: 10
                        Button {
                            text: desktop.launchAtLogin ? qsTr("Disable start at login") : qsTr("Enable start at login")
                            onClicked: desktop.setLaunchAtLogin(!desktop.launchAtLogin)
                        }
                        Option { id: tray; text: qsTr("Tray icon") }
                        Label { text: qsTr("Optional with the Omarchy widget. CodexBar is also available in the application launcher."); Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.65 }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: qsTr("Tray style"); Layout.fillWidth: true }
                            ComboBox { id: trayStyle; model: ["meters", "icon"] }
                        }
                        Option { id: costs; text: qsTr("Local spending") }
                    }
                }
                GroupBox {
                    title: qsTr("Display"); Layout.fillWidth: true; visible: window.section === 0
                    ColumnLayout {
                        anchors.fill: parent; spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: qsTr("Quota"); Layout.fillWidth: true }
                            ComboBox { id: quota; model: ["remaining", "used"] }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: qsTr("Reset time"); Layout.fillWidth: true }
                            ComboBox { id: reset; model: ["countdown", "absolute", "both"] }
                        }
                        Option { id: theme; text: qsTr("Follow Omarchy theme colors") }
                        Option { id: pace; text: qsTr("Show pace") }
                        Option { id: warnings; text: qsTr("Highlight low quota") }
                    }
                }
                GroupBox {
                    title: qsTr("CLI"); Layout.fillWidth: true; visible: window.section === 2
                    ColumnLayout {
                        anchors.fill: parent; spacing: 10
                        Label { text: qsTr("Executable") }
                        TextField { id: executable; Layout.fillWidth: true; selectByMouse: true; placeholderText: "codexbar" }
                    }
                }
            }
        }
        Label { text: desktop.configError || window.feedback; visible: text !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap }
        RowLayout {
            Layout.fillWidth: true
            Label { text: qsTr("Closing windows keeps CodexBar running."); Layout.fillWidth: true; wrapMode: Text.Wrap; opacity: 0.65; font.pixelSize: 12 }
            Button { text: qsTr("Cancel"); onClicked: window.hide() }
            Button {
                text: qsTr("Save"); highlighted: true
                onClicked: {
                    if (desktop.saveSettings({provider: provider.editText.trim(), source: source.currentText,
                        accountIndex: account.value, allAccounts: allAccounts.checked, showIdentity: identity.checked,
                        showCosts: costs.checked, showStatus: status.checked, notifications: notices.checked,
                        notifyThreshold: threshold.value, refreshSeconds: interval.value,
                        providerOrder: window.providerOrder, quotaDisplay: quota.currentText, resetDisplay: reset.currentText,
                        followOmarchyTheme: theme.checked, showPace: pace.checked, warningColors: warnings.checked, trayStyle: trayStyle.currentText,
                        refreshOnOpen: refreshOnOpen.checked, showTray: tray.checked, executable: executable.text.trim()})) window.feedback = qsTr("Settings saved");
                }
            }
        }
    }
    Dialog {
        id: signOut
        title: qsTr("Sign out of %1?").arg(loginProvider.currentText)
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Ok
        Label { text: qsTr("This signs out the provider CLI on this machine."); wrapMode: Text.Wrap; width: Math.min(window.width - 80, 350) }
        onAccepted: desktop.accountAction(loginProvider.currentText, "logout")
    }
    component Option: CheckBox {
        Layout.fillWidth: true
        contentItem: Text {
            text: parent.text
            font: parent.font
            color: parent.palette.windowText
            leftPadding: parent.indicator.width + parent.spacing
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
        }
    }
}
