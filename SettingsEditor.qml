import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Config.js" as Config

ColumnLayout {
  id: root
  property string accountError:""
  property Component backupSettingsComponent
  property Component emailSettingsComponent
  property Component calendarSettingsComponent
  signal accountsRequested()
  property var configuration: ({})
  property color bg
  property color fg
  property color accent
  property color muted
  property color edge
  property color systemBg
  property color systemFg
  property var locationResults: []
  property string locationStatus: ""
  signal locationSearchRequested(string query)
  property color systemAccent
  signal applyRequested(var colors, real textScale, var rss, real popupWidthPercent, var weather, var clock, real fullscreenTitleSize, var enabledModules, var overview, real sidebarWidthPercent, var fontSizes, var popupAppearance)
  function popupDraft(){return Config.popupAppearance({shadowSize:shadowSize.value,shadowColor:shadowColor.text,overlayOpacity:overlayOpacity.value})}
  property var fontDraft:({})
  function updateFont(key,value){var next=Object.assign({},fontDraft);if(value===null)delete next[key];else next[key]=value;fontDraft=next}
  property bool rssEnabledDraft:true
  property var moduleDraft: Config.modules(undefined)
  signal canceled()
  spacing: 16
  function load() {
    backupSection.expanded=false
    if(backupOptions.item)backupOptions.item.load()
    overviewSection.expanded=false
    overviewDraft.clear()
    var overview=Config.overview(configuration.overview)
    overview.order.forEach(function(key){overviewDraft.append({moduleKey:key,shown:overview.hidden.indexOf(key)<0})})
    var popup=Config.popupAppearance(configuration.popupAppearance)
    shadowSize.value=popup.shadowSize;shadowColor.text=popup.shadowColor;overlayOpacity.value=popup.overlayOpacity
    fontDraft=Config.fontOverrides(configuration.fontSizes)
    rssEnabledDraft=Config.rss(configuration.rss).enabled
    sidebarWidth.value=Config.sidebarWidth(configuration.sidebarWidthPercent)
    moduleDraft=Config.modules(configuration.enabledModules)
    modulesSection.expanded=false
    emailSection.expanded=false
    if(emailOptions.item)emailOptions.item.load()
    calendarSection.expanded=false
    if(calendarOptions.item)calendarOptions.item.load()
    var colors = configuration.colors || {}
    bgField.text = colors.background || ""
    fgField.text = colors.foreground || ""
    accentField.text = colors.accent || ""
    scaleSlider.value = configuration.textScale || 1
    popupWidthSlider.value = Config.popupWidth(configuration.popupWidthPercent)
    fullscreenTitleSize.value=Config.sectionTitleSize(configuration.fullscreenTitleSize)
    titleBarFontSize.value=Config.clock(configuration.clock).fontSize
    clockHours.currentIndex=Config.clock(configuration.clock).hourFormat==="24"?1:0
    clockDate.currentIndex=Config.dateFormats.indexOf(Config.clock(configuration.clock).dateFormat)
    var rss = Config.rss(configuration.rss)
    feedDraft.clear()
    rss.feeds.forEach(function(feed) { feedDraft.append(feed) })
    speedSlider.value = rss.scrollSpeed
    maxWordsSpin.value = rss.maxWords
    appearance.expanded = false
    rssSection.expanded = false
    weatherSection.expanded = false
    weatherOptions.load()
  }
  ListModel {id:overviewDraft;objectName:"overviewDraft"}
  function overviewOptions() {
    var order=[],hidden=[]
    for(var i=0;i<overviewDraft.count;i++){var row=overviewDraft.get(i);order.push(row.moduleKey);if(!row.shown)hidden.push(row.moduleKey)}
    return {order:order,hidden:hidden}
  }
  function rssDraft() {
    var feeds=[]
    for(var i=0;i<feedDraft.count;i++) feeds.push({url:feedDraft.get(i).url.trim(),count:feedDraft.get(i).count})
    return {enabled:rssEnabledDraft,feeds:feeds,scrollSpeed:speedSlider.value,maxWords:maxWordsSpin.value}
  }
  function validFeeds() {
    for(var i=0;i<feedDraft.count;i++) if (!/^https?:\/\/[^\s/]+(?:\/[^\s]*)?$/.test(feedDraft.get(i).url.trim())) return false
    return true
  }
  Label {visible:!!root.accountError;text:root.accountError;color:root.accent;wrapMode:Text.Wrap;Layout.fillWidth:true}
  ListModel { id: feedDraft; objectName: "feedDraft" }
  component FontSizeOption:ColumnLayout {
    id:option
    required property var modelData
    Layout.fillWidth:true;spacing:6
    Label {text:option.modelData.label;color:root.fg;Layout.fillWidth:true;wrapMode:Text.Wrap}
    RowLayout {
      Layout.fillWidth:true
      SpinBox {
        id:size
        objectName:"fontSize_"+option.modelData.key
        from:option.modelData.min;to:option.modelData.max;editable:true
        value:root.fontDraft[option.modelData.key]===undefined?option.modelData.defaultSize:root.fontDraft[option.modelData.key]
        enabled:root.fontDraft[option.modelData.key]!==undefined
        onValueModified:root.updateFont(option.modelData.key,value)
      }
      CheckBox {
        objectName:"fontDefault_"+option.modelData.key
        text:"Use default ("+option.modelData.defaultSize+" px)"
        checked:root.fontDraft[option.modelData.key]===undefined
        palette.windowText:root.fg;palette.highlight:root.accent
        onToggled:root.updateFont(option.modelData.key,checked?null:option.modelData.defaultSize)
      }
    }
    Label {
      objectName:"fontPreview_"+option.modelData.key
      text:"Preview: The quick brown fox jumps over the lazy dog."
      color:root.muted;font.pixelSize:size.value*scaleSlider.value
      Layout.fillWidth:true;wrapMode:Text.Wrap
    }
  }
  component Section: ColumnLayout {
    id: section
    property string title
    property string subtitle
    property bool expanded: false
    default property alias contents: sectionBody.data
    Layout.fillWidth: true
    spacing: 12
    AbstractButton {
      objectName: section.objectName + "Header"
      Layout.fillWidth: true
      implicitHeight: 56
      onClicked: section.expanded = !section.expanded
      Accessible.name: section.title
      contentItem: RowLayout {
        ColumnLayout {
          Layout.fillWidth: true; spacing: 4
          Label { text: section.title; color: root.fg; font.pixelSize: 17; font.bold: true }
          Label { text: section.subtitle; color: root.muted; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
        }
        Label { objectName: section.objectName+"Arrow"; text: section.expanded ? "⌃" : "⌄"; color: root.accent; font.pixelSize: 20 }
      }
    }
    ColumnLayout { id: sectionBody; visible: section.expanded; Layout.fillWidth: true; spacing: 10 }
    Rectangle { Layout.fillWidth: true; height: 1; color: root.edge }
  }
  component Field: TextField {
    Layout.fillWidth: true; color: root.fg; placeholderTextColor: root.muted
    selectByMouse: true
    background: Rectangle { color: root.bg; radius: 6; border.color: root.edge }
  }
  ScrollView {
    id: scroll
    objectName: "settingsScroll"
    rightPadding: 24
    Layout.fillWidth: true; Layout.fillHeight: true
    contentWidth: availableWidth
    clip: true
    ColumnLayout {
      width: scroll.availableWidth; spacing: 10
      Section {
        id: modulesSection
        objectName: "modulesAccordion"
        title: "Modules"
        subtitle: "Choose 3–4 modules · "+root.moduleDraft.length+" selected"
        Repeater {
          objectName: "moduleRepeater"
          model: Config.moduleOptions
          delegate: Switch {
            required property var modelData
            objectName: "moduleSwitch_"+modelData.key
            text: modelData.title
            Layout.fillWidth: true
            checked: root.moduleDraft.indexOf(modelData.key)>=0
            enabled: checked ? root.moduleDraft.length>3 : root.moduleDraft.length<4
            palette.windowText: root.fg; palette.highlight: root.accent
            onToggled: {
              var next=root.moduleDraft.filter(function(key){return key!==modelData.key})
              if(checked)next.push(modelData.key)
              if(next.length>=3 && next.length<=4)root.moduleDraft=next
            }
          }
        }
        Label { text: "Keep at least three and at most four modules enabled. Email starts disabled."; color: root.muted; wrapMode: Text.Wrap; Layout.fillWidth: true }
        Switch {objectName:"moduleSwitch_rss";text:"RSS News Feeds";checked:root.rssEnabledDraft;palette.windowText:root.fg;palette.highlight:root.accent;onToggled:root.rssEnabledDraft=checked}
        Label {text:"RSS is independent of the 3–4 panel modules. Turning it off gives its space to the panels.";color:root.muted;wrapMode:Text.Wrap;Layout.fillWidth:true;font.pixelSize:11}
      }
      Section {
        id: appearance
        objectName: "appearanceAccordion"
        title: "Appearance"
        subtitle: "System theme, color overrides and text size"
        Label { text: "Leave a color empty to follow Omarchy."; color: root.muted; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }
        Label { text: "Background"; color: root.fg }
        Field { id: bgField; objectName: "backgroundOverride"; placeholderText: String(root.systemBg); validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}|/ } }
        Label { text: "Text"; color: root.fg }
        Field { id: fgField; placeholderText: String(root.systemFg); validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}|/ } }
        Label { text: "Accent"; color: root.fg }
        Field { id: accentField; objectName: "accentOverride"; placeholderText: String(root.systemAccent); validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}|/ } }
        Label { text: "Text size · " + Math.round(scaleSlider.value*100) + "%"; color: root.fg }
        Slider { id: scaleSlider; Layout.fillWidth: true; from: .85; to: 1.5; stepSize: .05; palette.highlight: root.accent }
        Label {text:"Content font sizes";color:root.fg;font.bold:true}
        Repeater {objectName:"fontSizeRepeater";model:Config.fontOptions;delegate:FontSizeOption {}}
        Label {text:"Popup appearance";color:root.fg;font.bold:true}
        Label {text:"Shadow size · "+shadowSize.value+" px (0 disables shadows)";color:root.fg}
        SpinBox {id:shadowSize;objectName:"popupShadowSize";from:0;to:64;editable:true}
        Label {text:"Shadow color (#RRGGBB or #AARRGGBB)";color:root.fg}
        Field {id:shadowColor;objectName:"popupShadowColor";placeholderText:"#000000";validator:RegularExpressionValidator {regularExpression:/#[0-9a-fA-F]{6}|#[0-9a-fA-F]{8}|/}}
        Label {text:"Background dimming · "+Math.round(overlayOpacity.value)+"% opacity";color:root.fg}
        Slider {id:overlayOpacity;objectName:"popupOverlayOpacity";Layout.fillWidth:true;from:0;to:100;stepSize:1;palette.highlight:root.accent}
        Label {text:"0% leaves the app undimmed; 100% makes the backdrop black. These settings apply to app dialogs and confirmations.";color:root.muted;Layout.fillWidth:true;wrapMode:Text.Wrap;font.pixelSize:11}
        Rectangle {
          objectName:"popupStylePreview"
          Layout.fillWidth:true;Layout.preferredHeight:100+shadowSize.value*2
          color:root.bg;radius:8
          Rectangle {anchors.fill:parent;radius:8;color:Qt.rgba(0,0,0,overlayOpacity.value/100)}
          PopupSurface {objectName:"popupShadowPreview";anchors.centerIn:parent;width:180;height:64;appearance:root.popupDraft();color:root.bg;border.color:root.edge;Label {anchors.centerIn:parent;text:"Popup preview";color:root.fg}}
        }
        Label { text: "Article popup width · " + Math.round(popupWidthSlider.value) + "% of screen"; color: root.fg }
        Slider { id: popupWidthSlider; objectName: "popupWidthPercent"; Layout.fillWidth: true; from: 20; to: 100; stepSize: 1; palette.highlight: root.accent }
        Label {text:"Fullscreen summary column width · "+Math.round(sidebarWidth.value)+"%";color:root.fg}
        Slider {id:sidebarWidth;objectName:"sidebarWidthPercent";Layout.fillWidth:true;from:20;to:35;stepSize:1;palette.highlight:root.accent}
        Label { text: "Fullscreen section title size (px)"; color: root.fg }
        SpinBox { id: fullscreenTitleSize; objectName: "fullscreenTitleSize"; from: 12; to: 72; editable: true; palette.text: root.fg; palette.base: root.bg; palette.button: root.bg; palette.buttonText: root.fg }
        Label { text: "Title bar font size (px)"; color: root.fg }
        SpinBox { id: titleBarFontSize; objectName: "titleBarFontSize"; from: 12; to: 64; editable: true; palette.text: root.fg; palette.base: root.bg; palette.button: root.bg; palette.buttonText: root.fg }
        Label { text: "Clock format"; color: root.fg }
        ComboBox { id: clockHours; objectName: "clockHourFormat"; Layout.fillWidth: true; model: ["12-hour (1:30 PM)", "24-hour (13:30)"] }
        Label { text: "Date format"; color: root.fg }
        ComboBox {
          id: clockDate
          objectName: "clockDateFormat"
          Layout.fillWidth: true
          model: Config.dateFormats.map(function(format) { return Qt.formatDate(new Date(2026,9,25),format)+" · "+format })
        }
        AppButton { text: "Reset appearance to theme"; onClicked: { bgField.text=""; fgField.text=""; accentField.text=""; scaleSlider.value=1; popupWidthSlider.value=33;sidebarWidth.value=33;fontDraft=({});shadowSize.value=20;shadowColor.text="#000000";overlayOpacity.value=35 } }
      }
      Section {
        id: weatherSection
        objectName: "weatherAccordion"
        title: "Weather"
        subtitle: "Location, temperature, units, refresh interval and map zoom"
        WeatherSettings {
          id: weatherOptions
          objectName: "weatherSettings"
          configuration: root.configuration.weather || {}
          results: root.locationResults
          searchStatus: root.locationStatus
          bg: root.bg; fg: root.fg; accent: root.accent; muted: root.muted; edge: root.edge
          onSearchRequested: function(query) { root.locationSearchRequested(query) }
        }
      }
      Section {
        id: rssSection
        objectName: "rssAccordion"
        title: "RSS news feeds"
        subtitle: "Feed URLs, article counts and automatic scrolling"
        Label { text: "Articles per feed: 1–50. Refreshes every 10 minutes. Hover over the feed or open an article to pause scrolling."; color: root.muted; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }
        Repeater {
          objectName: "feedRepeater"
          model: feedDraft
          delegate: Rectangle {
            id: entry
            objectName: "feedEntry"+index
            required property int index
            required property string url
            required property int count
            Layout.fillWidth: true; implicitHeight: feedFields.implicitHeight+24
            color: "transparent"; border.color: root.edge; radius: 8
            ColumnLayout {
              id: feedFields
              anchors.fill: parent; anchors.margins: 12; spacing: 10
              RowLayout {
                Layout.fillWidth: true
                Label { text: "Feed " + (entry.index+1); color: root.accent; font.bold: true }
                Item { Layout.fillWidth: true }
                AppButton { text: "Remove"; onClicked: feedDraft.remove(entry.index) }
              }
              Field { objectName: "feedUrl"+entry.index; text: entry.url; placeholderText: "https://example.com/rss"; onTextEdited: feedDraft.setProperty(entry.index,"url",text) }
              RowLayout {
                Label { text: "Articles to fetch"; color: root.fg }
                Item { Layout.fillWidth: true }
                SpinBox { objectName: "feedCount"+entry.index; from: 1; to: 50; value: entry.count; editable: true; onValueModified: feedDraft.setProperty(entry.index,"count",value); palette.text: root.fg; palette.base: root.bg; palette.button: root.bg; palette.buttonText: root.fg }
              }
            }
          }
        }
        AppButton { objectName: "addFeedButton"; text: "+ Add feed"; enabled: feedDraft.count < 10; onClicked: feedDraft.append({url:"",count:10}) }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Maximum words per article"; color: root.fg; Layout.fillWidth: true; wrapMode: Text.Wrap }
          SpinBox { id: maxWordsSpin; objectName: "rssMaxWords"; from: 0; to: 10000; stepSize: 50; editable: true; palette.text: root.fg; palette.base: root.bg; palette.button: root.bg; palette.buttonText: root.fg }
        }
        Label { text: "0 means no word limit. Longer excerpts end with a link to the original article."; color: root.muted; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
        Label { text: "Scrolling speed · " + Math.round(speedSlider.value) + " px/s" + (speedSlider.value === 0 ? " (paused)" : ""); color: root.fg }
        Slider { id: speedSlider; objectName: "rssSpeed"; Layout.fillWidth: true; from: 0; to: 150; stepSize: 1; palette.highlight: root.accent }
        Label { text: root.validFeeds() ? "" : "Enter a valid http:// or https:// URL for every feed."; visible: text.length>0; color: root.accent; wrapMode: Text.Wrap; Layout.fillWidth: true }
      }
      Section {
        id:emailSection
        objectName:"emailAccordion"
        title:"Email"
        subtitle:"Mail checks, notifications, remote images and signatures"
        Loader {id:emailOptions;Layout.fillWidth:true;sourceComponent:root.emailSettingsComponent}
        Label {visible:!root.emailSettingsComponent;text:"Enable Email or Calendar to manage mail preferences.";color:root.muted;wrapMode:Text.Wrap;Layout.fillWidth:true}
      }
      Section {
        id:calendarSection
        objectName:"calendarAccordion"
        title:"Calendar"
        subtitle:"Calendar preferences, sources and reminders"
        Loader {id:calendarOptions;Layout.fillWidth:true;sourceComponent:root.calendarSettingsComponent}
        Label {visible:!root.calendarSettingsComponent;text:"Enable Calendar or Email to manage account preferences.";color:root.muted;wrapMode:Text.Wrap;Layout.fillWidth:true}
      }
      Section {
        id:overviewSection
        objectName:"overviewAccordion"
        title:"Overview"
        subtitle:"Choose and arrange your daily summaries"
        Label {text:"Only enabled modules appear in Overview. Changes save with Apply.";color:root.muted;wrapMode:Text.Wrap;Layout.fillWidth:true}
        Repeater {
          model:overviewDraft
          delegate:RowLayout {
            id:overviewRow
            required property string moduleKey
            required property bool shown
            required property int index
            Layout.fillWidth:true
            Switch {text:overviewRow.moduleKey.charAt(0).toUpperCase()+overviewRow.moduleKey.slice(1);checked:overviewRow.shown;Layout.fillWidth:true;palette.windowText:root.fg;onToggled:overviewDraft.setProperty(overviewRow.index,"shown",checked)}
            AppButton {text:"↑";Accessible.name:"Move "+overviewRow.moduleKey+" up";enabled:overviewRow.index>0;onClicked:overviewDraft.move(overviewRow.index,overviewRow.index-1,1)}
            AppButton {text:"↓";Accessible.name:"Move "+overviewRow.moduleKey+" down";enabled:overviewRow.index<overviewDraft.count-1;onClicked:overviewDraft.move(overviewRow.index,overviewRow.index+1,1)}
          }
        }
      }
      Section {
        id:backupSection
        objectName:"backupAccordion"
        title:"Backup & restore"
        subtitle:"Private snapshots, schedules and restore previews"
        Loader {id:backupOptions;Layout.fillWidth:true;sourceComponent:root.backupSettingsComponent}
      }
    }
  }
  RowLayout {
    Layout.fillWidth: true
    Label { text: "Changes are saved with Apply."; color: root.muted; font.pixelSize: 10; Layout.fillWidth: true; wrapMode: Text.Wrap }
    AppButton { text: "Cancel"; onClicked: root.canceled() }
    AppButton {
      objectName: "applySettings"
      text: "Apply"
      enabled: bgField.acceptableInput && fgField.acceptableInput && accentField.acceptableInput && shadowColor.acceptableInput && root.validFeeds() && weatherOptions.valid && root.moduleDraft.length>=3 && root.moduleDraft.length<=4
      onClicked: {
        var colors={}
        if(bgField.text) colors.background=bgField.text
        if(fgField.text) colors.foreground=fgField.text
        if(accentField.text) colors.accent=accentField.text
        if(emailOptions.item)emailOptions.item.save()
        if(calendarOptions.item)calendarOptions.item.save()
        root.applyRequested(colors,scaleSlider.value,root.rssDraft(),popupWidthSlider.value,weatherOptions.draft(),{fontSize:titleBarFontSize.value,hourFormat:clockHours.currentIndex===1?"24":"12",dateFormat:Config.dateFormats[clockDate.currentIndex]},fullscreenTitleSize.value,root.moduleDraft,root.overviewOptions(),sidebarWidth.value,Config.fontOverrides(root.fontDraft),root.popupDraft())
      }
    }
  }
}
