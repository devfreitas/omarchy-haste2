import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "local.haste2-rgb"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  function open() {
    root.controller.show()
    if (root.hostWidget) root.hostWidget.refreshState()
  }
  function close() {
    root.controller.hide()
  }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function runCmd(cmd) {
    if (root.bar) root.bar.run(cmd)
    refreshTimer.restart()
  }

  function setColor(value) {
    runCmd("$HOME/.local/bin/haste2-rgb set " + value)
  }

  // Pequeno atraso pra deixar o daemon reiniciar antes de reconsultar o estado.
  Timer {
    id: refreshTimer
    interval: 400
    onTriggered: if (root.hostWidget) root.hostWidget.refreshState()
  }

  ListModel {
    id: dpiStages
    ListElement { label: "400" }
    ListElement { label: "800" }
    ListElement { label: "1600" }
    ListElement { label: "3200" }
  }

  ListModel {
    id: colors
    ListElement { label: "Vermelho"; value: "red";     hex: "#ff0000" }
    ListElement { label: "Verde";     value: "green";   hex: "#00ff00" }
    ListElement { label: "Azul";      value: "blue";    hex: "#0000ff" }
    ListElement { label: "Branco";    value: "white";   hex: "#ffffff" }
    ListElement { label: "Amarelo";   value: "yellow";  hex: "#ffff00" }
    ListElement { label: "Ciano";     value: "cyan";    hex: "#00ffff" }
    ListElement { label: "Magenta";   value: "magenta"; hex: "#ff00ff" }
    ListElement { label: "Roxo";      value: "purple";  hex: "#8000ff" }
    ListElement { label: "Laranja";   value: "orange";  hex: "#ff6000" }
    ListElement { label: "Rosa";      value: "pink";    hex: "#ff1493" }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(260))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        // Cabeçalho: título + status
        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: "Haste 2 RGB"
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Item { width: 1; height: 1 }

          Rectangle {
            width: 8
            height: 8
            radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: root.hostWidget && root.hostWidget.daemonActive
              ? root.hostWidget.currentColorHex
              : "#606060"
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hostWidget && root.hostWidget.daemonActive ? "Ligado" : "Desligado"
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            opacity: 0.75
          }
        }

        // Grade de cores predefinidas
        Grid {
          id: swatchGrid
          width: parent.width
          columns: 5
          spacing: Style.space(8)

          Repeater {
            model: colors
            delegate: Rectangle {
              width: (swatchGrid.width - Style.space(8) * 4) / 5
              height: width
              radius: Style.cornerRadius
              color: hex
              border.width: 1
              border.color: root.barForeground
              opacity: swatchArea.containsMouse ? 1.0 : 0.85

              MouseArea {
                id: swatchArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setColor(value)
              }
            }
          }
        }

        // Cor customizada em HEX — removida a pedido (só cores predefinidas)

        // DPI atual — somente leitura (o mouse só aceita troca pelo botão físico;
        // confirmado por teste real, escrever no device não tem efeito).
        Column {
          width: parent.width
          spacing: Style.space(6)

          Text {
            text: "DPI atual"
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            opacity: 0.75
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Repeater {
              model: dpiStages
              delegate: Rectangle {
                readonly property bool active: root.hostWidget
                  && root.hostWidget.currentDpi === label
                width: (parent.width - Style.space(8) * 3) / 4
                height: Style.spacing.controlHeight
                radius: Style.cornerRadius
                color: active ? Color.accent : "transparent"
                border.width: 1
                border.color: active ? Color.accent : root.barForeground

                Text {
                  anchors.centerIn: parent
                  text: label
                  color: active
                    ? (root.bar ? root.bar.background : "#000000")
                    : root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: active
                  opacity: active ? 1.0 : 0.7
                }
              }
            }
          }

          Text {
            text: "Troque pelo botão físico do mouse"
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            opacity: 0.5
          }
        }

        // Ações: desligar LED / parar o serviço
        Row {
          width: parent.width
          spacing: Style.space(8)

          Rectangle {
            width: (parent.width - Style.space(8)) / 2
            height: Style.spacing.controlHeight
            radius: Style.cornerRadius
            color: "transparent"
            border.width: 1
            border.color: root.barForeground
            Text {
              anchors.centerIn: parent
              text: "Desligar LED"
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setColor("off")
            }
          }

          Rectangle {
            width: (parent.width - Style.space(8)) / 2
            height: Style.spacing.controlHeight
            radius: Style.cornerRadius
            color: "transparent"
            border.width: 1
            border.color: Color.urgent
            Text {
              anchors.centerIn: parent
              text: "Parar serviço"
              color: Color.urgent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.runCmd("$HOME/.local/bin/haste2-rgb stop")
            }
          }
        }
      }
    }
  }
}
