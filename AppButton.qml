import QtQuick
import QtQuick.Controls.Basic

Button {
  id: control
  hoverEnabled: true
  contentItem: Label {
    text: control.text
    font: control.font
    color: control.palette.buttonText
    opacity: control.enabled ? 1 : .45
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }
}
