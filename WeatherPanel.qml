import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Weather.js" as Weather

GridLayout {
  id: root
  property var weather: ({})
  property Component heading
  property string status: "Loading weather…"
  property color bg
  property color fg
  property color accent
  property color muted
  property color edge
  property string fontFamily
  property real textScale: 1
  property bool fullscreenMode: false
  readonly property var current: weather.current || {}
  readonly property var units: weather.units || {temperature:"",wind:"",precipitation:""}
  readonly property var mapData: weather.map || {tiles:[],width:768,height:512}
  readonly property var frames: mapData.frames || []
  property int frameIndex: 0
  property bool playing: true
  property int frameInterval: 700
  readonly property var activeFrame: frames.length ? frames[Math.min(frameIndex,frames.length-1)] : ({})
  onMapDataChanged: frameIndex=0
  Timer {
    objectName: "radarPlaybackTimer"
    interval: root.frameInterval
    repeat: true
    running: root.visible && root.playing && root.frames.length>1
    onTriggered: root.frameIndex=(root.frameIndex+1)%root.frames.length
  }
  readonly property bool stacked: width<520
  columns: stacked?1:2
  columnSpacing: 16; rowSpacing: 16
  signal refreshRequested(int zoom)
  ColumnLayout {
    id: conditions
    objectName: "weatherConditions"
    Layout.fillWidth: true
    Layout.preferredWidth: root.stacked ? 1 : (root.width-root.columnSpacing)*.25
    Layout.minimumWidth: 0
    Layout.alignment: Qt.AlignTop
    Layout.fillHeight: false
    spacing: 10
    Loader { sourceComponent: root.heading; Layout.fillWidth: true; Layout.minimumWidth: 0 }
    Label { text: root.weather.location || "Weather"; textFormat: Text.PlainText; color: root.fg; font.pixelSize: 12*root.textScale; font.bold: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Label { text: Weather.number(root.current.temperature)+root.units.temperature; color: root.fg; font.pixelSize: 32*root.textScale; Layout.fillWidth: true; elide: Text.ElideRight }
    Label { text: root.weather.current?Weather.condition(root.current.code):root.status; color: root.accent; font.pixelSize: 12*root.textScale; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Label { text: "Feels like "+Weather.number(root.current.feelsLike)+root.units.temperature+"\nRain chance "+Weather.number(root.current.probability)+"%\nWind "+Weather.number(root.current.wind)+" "+root.units.wind+"\nHumidity "+Weather.number(root.current.humidity)+"%\nPrecip. "+Weather.number(root.current.precipitation,2)+" "+root.units.precipitation; color: root.muted; font.pixelSize: 11*root.textScale; lineHeight: 1.4; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Rectangle { Layout.fillWidth: true; height: 1; color: root.edge }
    Label { text: "7-DAY FORECAST"; color: root.fg; font.pixelSize: 10*root.textScale; font.bold: true; Layout.fillWidth: true; wrapMode: Text.Wrap }
    Repeater {
      objectName: "weatherForecast"
      model: root.weather.daily || []
      delegate: ColumnLayout {
        required property var modelData
        Layout.fillWidth: true; spacing: 3
        RowLayout {
          Layout.fillWidth: true
          Label { text: Qt.formatDate(new Date(modelData.date+"T12:00:00"),"ddd"); color: root.fg; font.pixelSize: 11*root.textScale }
          Label { text: Weather.icon(modelData.code); font.family: root.fontFamily; color: root.accent; font.pixelSize: 11 }
          Item { Layout.fillWidth: true }
          Label { text: Weather.number(modelData.high)+"° / "+Weather.number(modelData.low)+"°"; color: root.fg; font.pixelSize: 11*root.textScale }
        }
        Label { text: Weather.number(modelData.probability)+"% rain · "+Weather.number(modelData.precipitation,2)+" "+root.units.precipitation; color: root.muted; font.pixelSize: 9*root.textScale; Layout.fillWidth: true; elide: Text.ElideRight }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.edge; opacity: .5 }
      }
    }
    Label { text: root.weather.updated ? "Updated "+root.weather.updated.replace("T"," ")+"\n"+root.status : root.status; textFormat: Text.PlainText; color: root.muted; font.pixelSize: 9; wrapMode: Text.Wrap; Layout.fillWidth: true }
  }
  ColumnLayout {
    id: radarColumn
    objectName: "weatherRadar"
    Layout.fillWidth: true
    Layout.preferredWidth: root.stacked ? 1 : (root.width-root.columnSpacing)*.75
    Layout.minimumWidth: 0
    Layout.alignment: Qt.AlignTop
    Layout.fillHeight: false
    spacing: 10
    Rectangle {
      id: mapViewport
      objectName: "weatherMap"
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
      implicitHeight: (root.fullscreenMode?1.25:1)*1.25*Math.max(180,Math.min(260,width*.55))
      color: root.bg; radius: 10; border.color: root.edge; clip: true
      Item {
        id: mapCanvas
        width: root.mapData.width || 768; height: root.mapData.height || 512
        anchors.centerIn: parent
        scale: Math.max(mapViewport.width/width,mapViewport.height/height)
        Repeater {
          model: root.mapData.tiles || []
          delegate: Image {
            required property var modelData
            x: modelData.x; y: modelData.y; width: 256; height: 256
            source: modelData.url; asynchronous: true; cache: true
          }
        }
        Repeater {
          model: root.frames.length ? root.frames : [{url:root.mapData.overlay || ""}]
          delegate: Image {
            required property int index
            required property var modelData
            anchors.fill: parent
            source: modelData.url; asynchronous: true; cache: true
            opacity: root.frames.length && index!==root.frameIndex ? 0 : .7
          }
        }
        Rectangle {
          anchors.centerIn: parent; width: 12; height: 12; radius: 6; color: root.accent; border.color: root.bg; border.width: 2
        }
      }
      Label { anchors.centerIn: parent; width: parent.width-30; text: root.weather.map?"":"Loading map…"; visible: text.length>0; color: root.fg; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
      Rectangle {
        anchors.bottom: parent.bottom; width: parent.width; height: mapAttribution.implicitHeight+12; color: Qt.rgba(root.bg.r,root.bg.g,root.bg.b,.9)
        Label { id: mapAttribution; anchors.centerIn: parent; width: parent.width-16; text: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a> · <a href="https://radar.weather.gov">NOAA/NWS radar</a>'; textFormat: Text.StyledText; color: root.fg; linkColor: root.accent; font.pixelSize: 9; wrapMode: Text.Wrap; onLinkActivated: function(link) { Qt.openUrlExternally(link) } }
      }
    }
    RowLayout {
      objectName: "radarToolbar"
      Layout.fillWidth: true
      Label { text: "LOCAL RADAR"; color: root.accent; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
      AppButton { text: "−"; implicitWidth: 32; enabled: (root.mapData.zoom || 7)>3; onClicked: root.refreshRequested((root.mapData.zoom || 7)-1) }
      Label { text: "Zoom "+(root.mapData.zoom || 7); color: root.muted; font.pixelSize: 10 }
      AppButton { text: "+"; implicitWidth: 32; enabled: (root.mapData.zoom || 7)<10; onClicked: root.refreshRequested((root.mapData.zoom || 7)+1) }
      AppButton { text: "↻"; implicitWidth: 32; onClicked: root.refreshRequested(root.mapData.zoom || 7); ToolTip.visible: hovered; ToolTip.text: "Refresh weather and radar" }
    }
    RowLayout {
      Layout.fillWidth: true
      AppButton {
        objectName: "radarPlayPause"
        text: root.playing ? "Ⅱ Pause" : "▶ Play"
        enabled: root.frames.length>1
        onClicked: root.playing=!root.playing
      }
      ComboBox {
        objectName: "radarPlaybackSpeed"
        model: ["Slow", "Normal", "Fast"]
        currentIndex: 1
        onActivated: root.frameInterval=[1400,700,350][currentIndex]
        ToolTip.visible: hovered; ToolTip.text: "Radar playback speed"
      }
      Label {
        objectName: "radarFrameTime"
        text: root.activeFrame.time ? Qt.formatDateTime(new Date(root.activeFrame.time),"MMM d · h:mm AP")+" local · "+(root.frameIndex+1)+"/"+root.frames.length : "Latest radar"
        color: root.muted; font.pixelSize: 10; wrapMode: Text.Wrap; Layout.fillWidth: true
      }
    }
    Label { text: root.mapData.error || (root.mapData.overlay ? (root.frames.length>1 ? "NOAA radar loop · past hour" : "Latest available NOAA reflectivity")+" · transparent areas indicate no detected precipitation" : "Radar is loading…"); textFormat: Text.PlainText; color: root.muted; font.pixelSize: 10*root.textScale; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Label { text: root.mapData.updated ? "Radar fetched "+Qt.formatDateTime(new Date(root.mapData.updated),"MMM d · h:mm AP") : ""; color: root.muted; font.pixelSize: 9; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Rectangle { Layout.fillWidth: true; height: 1; color: root.edge }
    Label { text: "WEATHER ALERTS"; color: root.fg; font.pixelSize: 10*root.textScale; font.bold: true }
    Label { text: root.weather.alerts ? (root.weather.alerts.error || (root.weather.alerts.items.length?root.weather.alerts.items.length+" active alert(s)":"No active NWS alerts for this location")) : "Checking alerts…"; textFormat: Text.PlainText; color: root.muted; font.pixelSize: 11*root.textScale; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Repeater {
      model: root.weather.alerts ? root.weather.alerts.items : []
      delegate: Label {
        required property var modelData
        Layout.fillWidth: true
        text: "⚠ "+modelData.title+"\n"+modelData.headline
        textFormat: Text.PlainText; color: root.accent; font.pixelSize: 11*root.textScale; wrapMode: Text.Wrap
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (/^https:\/\//.test(parent.modelData.url)) Qt.openUrlExternally(parent.modelData.url) }
      }
    }
    Label { text: '<a href="https://open-meteo.com/">Forecasts by Open-Meteo</a> · Alerts by NOAA/NWS'; textFormat: Text.StyledText; linkColor: root.accent; color: root.muted; font.pixelSize: 10; wrapMode: Text.Wrap; Layout.fillWidth: true; onLinkActivated: function(link) { Qt.openUrlExternally(link) } }
  }
}
