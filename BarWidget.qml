import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "local.haste2-rgb"

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  // Cor atual (lida do arquivo de estado do haste2-rgb) e se o daemon está ativo.
  property string currentColorHex: "#a0a0a0"
  property bool daemonActive: false
  property string currentDpi: "—"

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }
  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }
  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  function refreshState() {
    statusProc.running = false
    statusProc.running = true
  }

  implicitWidth: 28
  implicitHeight: 28

  onBarChanged: injectPanel()

  Component.onCompleted: refreshState()

  // Faz polling leve do estado (serviço ativo? qual cor?) pra tingir o ícone.
  Timer {
    interval: 4000
    running: true
    repeat: true
    onTriggered: root.refreshState()
  }

  Process {
    id: statusProc
    command: ["bash", "-lc",
      "systemctl --user is-active haste2-rgb.service 2>/dev/null; " +
      "echo \"color:$(cat \"$HOME/.config/haste2-rgb/color\" 2>/dev/null)\"; " +
      "echo \"dpi:$(cat \"$HOME/.config/haste2-rgb/dpi\" 2>/dev/null)\""]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        var t = line.trim()
        if (t === "active" || t === "inactive" || t === "failed") {
          root.daemonActive = (t === "active")
        } else if (t.indexOf("color:") === 0) {
          var c = t.substring(6)
          if (c.length > 0) root.currentColorHex = colorHelper.colorNameToHex(c)
        } else if (t.indexOf("dpi:") === 0) {
          var d = t.substring(4)
          if (d.length > 0) root.currentDpi = d
        }
      }
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: root.daemonActive ? "Haste 2 RGB — ligado" : "Haste 2 RGB — desligado"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) {
        root.toggle()
      } else if (buttonCode === Qt.RightButton) {
        root.refreshState()
      }
    }
  }

  // Ícone de mouse desenhado com formas QML (sem depender de nenhuma
  // fonte Nerd Font — os codepoints do Material Design Icons mudam entre
  // versões da fonte, então um glifo fixo podia virar um quadrado vazio
  // dependendo do sistema).
  Item {
    anchors.centerIn: button
    width: 13
    height: 17
    z: 1

    Rectangle {
      id: mouseBody
      anchors.fill: parent
      radius: width / 2
      color: "transparent"
      border.width: 1.4
      border.color: root.bar ? root.bar.foreground : "#ffffff"
    }

    Rectangle {
      // rodinha
      width: 2
      height: 4
      radius: 1
      color: root.bar ? root.bar.foreground : "#ffffff"
      anchors.horizontalCenter: mouseBody.horizontalCenter
      anchors.top: mouseBody.top
      anchors.topMargin: 3
    }
  }

  // Pontinho indicando a cor atual, sem depender de propriedades internas do WidgetButton.
  Rectangle {
    width: 6
    height: 6
    radius: 3
    color: root.daemonActive ? root.currentColorHex : "#606060"
    anchors.right: button.right
    anchors.bottom: button.bottom
    anchors.rightMargin: 2
    anchors.bottomMargin: 2
    border.color: root.bar ? root.bar.background : "#000000"
    border.width: 1
  }

  QtObject {
    id: colorHelper
    function colorNameToHex(name) {
      switch (name) {
        case "red": return "#ff0000"
        case "green": return "#00ff00"
        case "blue": return "#0000ff"
        case "white": return "#ffffff"
        case "yellow": return "#ffff00"
        case "cyan": return "#00ffff"
        case "magenta": return "#ff00ff"
        case "purple": return "#8000ff"
        case "orange": return "#ff6000"
        case "pink": return "#ff1493"
        case "off": return "#606060"
        default:
          return name.charAt(0) === "#" ? name : "#a0a0a0"
      }
    }
  }
}
