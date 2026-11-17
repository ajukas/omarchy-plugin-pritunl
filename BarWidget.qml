import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar icon for the Pritunl VPN. It lights up while connected; clicking opens a
// card with the profile status, a PIN field and a connect/disconnect button.
// All work goes through the pritunl-client CLI, polled with `list -j`.
Panel {
  id: root
  moduleName: "ajukas.pritunl"
  ipcTarget: "ajukas.pritunl"

  readonly property string configuredId: String(setting("profileId", "") || "")
  readonly property color fg: Color.popups.text
  readonly property color dim: Qt.darker(fg, 1.6)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var profile: null
  property bool busy: false
  property bool connecting: false
  property string status: ""
  property bool statusError: false

  readonly property bool connected: profile !== null && profile.connected === true
  readonly property bool active: profile !== null && profile.run_state === "Active"
  readonly property string profileName: profile ? profile.name : "Pritunl"

  function open() {
    refresh()
    root.controller.show()
  }

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function showStatus(message, isError) {
    root.status = message
    root.statusError = isError
    statusTimer.restart()
  }

  function connect() {
    if (!root.profile || root.busy) return
    var pin = pinInput.text
    if (pin === "") {
      root.showStatus("Digite o PIN", true)
      return
    }
    root.busy = true
    root.connecting = true
    root.status = "Conectando…"
    root.statusError = false
    actionProc.command = ["pritunl-client", "start", root.profile.id, "--password", pin]
    actionProc.running = true
    pinInput.text = ""
    connectTimeout.restart()
  }

  function disconnect() {
    if (!root.profile || root.busy) return
    root.busy = true
    root.connecting = false
    root.status = "Desconectando…"
    root.statusError = false
    actionProc.command = ["pritunl-client", "stop", root.profile.id]
    actionProc.running = true
  }

  function applyList(list) {
    var found = null
    for (var i = 0; i < list.length; i++) {
      if (root.configuredId === "" || list[i].id === root.configuredId) { found = list[i]; break }
    }
    root.profile = found
    if (!root.connecting || !found) return
    if (found.connected) {
      root.connecting = false
      connectTimeout.stop()
      root.showStatus("Conectado", false)
    } else if (found.run_state !== "Active") {
      // The service drops the profile back to inactive when auth fails.
      root.connecting = false
      connectTimeout.stop()
      root.showStatus("Falha ao conectar. PIN incorreto?", true)
    }
  }

  Process {
    id: listProc
    command: ["pritunl-client", "list", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.applyList(JSON.parse(text) || []) } catch (e) {}
      }
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      id: actionErr
      waitForEnd: true
    }
    onExited: function(code) {
      root.busy = false
      if (code !== 0) {
        root.connecting = false
        connectTimeout.stop()
        var msg = String(actionErr.text || "").trim().split("\n").pop()
        root.showStatus(msg !== "" ? msg : "pritunl-client saiu com erro " + code, true)
      } else if (!root.connecting) {
        root.status = ""
      }
      root.refresh()
    }
  }

  // Poll faster while a connection is being set up.
  Timer {
    interval: root.connecting || root.busy ? 1000 : 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: connectTimeout
    interval: 45000
    onTriggered: {
      if (!root.connecting) return
      root.connecting = false
      root.showStatus("Tempo esgotado ao conectar", true)
    }
  }

  Timer {
    id: statusTimer
    interval: 6000
    onTriggered: root.status = ""
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.connected ? "󰦝" : "󰖂"
    active: root.connected || root.opened
    dimmed: !root.connected && !root.connecting
    tooltipText: {
      if (!root.profile) return "Pritunl · nenhum perfil importado"
      if (root.connected) return root.profileName + "\nConectado · " + (root.profile.client_address || "")
      if (root.connecting) return root.profileName + "\nConectando…"
      return root.profileName + "\nDesconectado"
    }
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
      else if (b === Qt.RightButton && root.active) root.disconnect()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: pinInput.visible ? pinInput : null
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      width: parent.width
      spacing: Style.space(12)

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          text: button.text
          color: root.connected ? Color.accent : root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          width: parent.width - x
          textFormat: Text.PlainText
          elide: Text.ElideRight
          text: root.profileName
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: {
          if (!root.profile) return "Nenhum perfil encontrado. Importe com: pritunl-client add <arquivo.tar>"
          if (root.connected) {
            var t = "Conectado"
            if (root.profile.client_address) t += " · IP " + root.profile.client_address
            if (root.profile.server_address) t += "\nServidor " + root.profile.server_address
            return t
          }
          if (root.connecting || root.active) return "Conectando…"
          return "Desconectado"
        }
        color: root.connected ? Color.accent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      TextField {
        id: pinInput
        visible: root.profile !== null && !root.active && !root.connecting
        width: parent.width
        password: true
        enabled: !root.busy
        placeholderText: "PIN"
        onAccepted: root.connect()
        Keys.onEscapePressed: root.close()
      }

      Button {
        visible: root.profile !== null
        width: parent.width
        bordered: true
        text: root.active || root.connecting ? "Desconectar" : "Conectar"
        onClicked: (root.active || root.connecting) ? root.disconnect() : root.connect()
      }

      Text {
        visible: root.status !== ""
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: root.status
        color: root.statusError ? Color.urgent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }
}
