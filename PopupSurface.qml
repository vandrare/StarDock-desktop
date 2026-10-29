import QtQuick
import QtQuick.Effects
import "Config.js" as Config

Rectangle {
  id:root
  property var appearance:({})
  readonly property var settings:Config.popupAppearance(appearance)
  radius:16
  border.width:1
  layer.enabled:settings.shadowSize>0
  layer.effect:MultiEffect {
    shadowEnabled:true
    shadowColor:root.settings.shadowColor
    shadowOpacity:.35
    blurMax:Math.max(1,root.settings.shadowSize)
    shadowBlur:1
    shadowVerticalOffset:Math.round(root.settings.shadowSize/4)
    autoPaddingEnabled:true
  }
}
