import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Config.js" as Config

ColumnLayout {
  id: root
  property var configuration: ({})
  property var results: []
  property string searchStatus: ""
  property color bg
  property color fg
  property color accent
  property color muted
  property color edge
  property var selectedLocation: Config.weather({})
  property bool locationDirty: false
  readonly property bool valid: !locationDirty && isFinite(selectedLocation.latitude) && isFinite(selectedLocation.longitude)
  signal searchRequested(string query)
  Layout.fillWidth: true
  spacing: 10
  function load() {
    selectedLocation=Config.weather(configuration)
    locationField.text=selectedLocation.location
    locationDirty=false
    temperature.currentIndex=selectedLocation.temperatureUnit === "celsius" ? 1:0
    units.currentIndex=selectedLocation.units === "metric" ? 1:0
    refresh.value=selectedLocation.refreshMinutes
    zoom.value=selectedLocation.mapZoom
  }
  function draft() {
    return {location:selectedLocation.location,latitude:selectedLocation.latitude,longitude:selectedLocation.longitude,countryCode:selectedLocation.countryCode,temperatureUnit:temperature.currentIndex===1?"celsius":"fahrenheit",units:units.currentIndex===1?"metric":"imperial",refreshMinutes:refresh.value,mapZoom:zoom.value}
  }
  Label { text: "Location"; color: root.fg }
  RowLayout {
    Layout.fillWidth: true
    TextField {
      id: locationField
      objectName: "weatherLocation"
      Layout.fillWidth: true
      placeholderText: "City or postal code"
      color: root.fg; placeholderTextColor: root.muted
      selectByMouse: true
      background: Rectangle { color: root.bg; border.color: root.edge; radius: 6 }
      onTextEdited: root.locationDirty=true
      onAccepted: root.searchRequested(text)
    }
    AppButton { objectName: "weatherSearch"; text: "Search"; enabled: locationField.text.trim().length>=2; onClicked: root.searchRequested(locationField.text) }
  }
  ComboBox {
    id: locations
    objectName: "weatherLocationResults"
    visible: root.results.length>0
    Layout.fillWidth: true
    model: root.results
    textRole: "location"
    displayText: "Select a matching location…"
    onActivated: function(index) {
      root.selectedLocation=root.results[index]
      locationField.text=root.selectedLocation.location
      root.locationDirty=false
      displayText=root.selectedLocation.location
    }
  }
  Label { text: root.locationDirty ? "Search and select a matching location before applying." : root.selectedLocation.latitude.toFixed(4)+", "+root.selectedLocation.longitude.toFixed(4); color: root.muted; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
  Label { text: root.searchStatus; visible: text.length>0; textFormat: Text.PlainText; color: root.accent; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
  Label { text: "Temperature"; color: root.fg }
  ComboBox { id: temperature; objectName: "weatherTemperatureUnit"; Layout.fillWidth: true; model: ["Fahrenheit (°F)","Celsius (°C)"] }
  Label { text: "Wind and precipitation units"; color: root.fg }
  ComboBox { id: units; objectName: "weatherMeasurementUnits"; Layout.fillWidth: true; model: ["Imperial · mph, inches","Metric · km/h, millimetres"] }
  RowLayout {
    Layout.fillWidth: true
    Label { text: "Refresh interval (minutes)"; color: root.fg; Layout.fillWidth: true; wrapMode: Text.Wrap }
    SpinBox { id: refresh; objectName: "weatherRefreshMinutes"; from: 5; to: 120; editable: true }
  }
  RowLayout {
    Layout.fillWidth: true
    Label { text: "Map zoom"; color: root.fg; Layout.fillWidth: true }
    SpinBox { id: zoom; objectName: "weatherMapZoom"; from: 3; to: 10; editable: true }
  }
  Label { text: "Open-Meteo forecasts work worldwide. NOAA radar and weather alerts cover U.S. locations. Map data: © OpenStreetMap contributors."; color: root.muted; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
}
