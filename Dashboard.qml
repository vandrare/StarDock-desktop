import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import "Config.js" as Config
import "ArticleText.js" as ArticleText
import "Weather.js" as Weather
import "Overview.js" as Overview
import "CalendarPreferences.js" as CalendarPreferences

Control {
  id: root
  font.family: themeFont
  palette.button: bg
  palette.buttonText: fg
  palette.text: fg
  palette.base: bg
  palette.highlight: accent
  readonly property real sectionTitleSize: fullscreenMode ? Config.sectionTitleSize(configuration.fullscreenTitleSize) : (narrow ? 27 : 36)*textScale
  property bool fullscreenMode: (Window.window && (Window.window.visibility===Window.FullScreen || Window.window.visibility===Window.Maximized)) || (width>=Screen.desktopAvailableWidth*.95 && height>=Screen.desktopAvailableHeight*.95)
  property color themeBackground: "#071426"
  property color themeForeground: "#c8d9e9"
  property color themeAccent: "#6cb6ff"
  property string themeFont: "JetBrainsMono Nerd Font"
  property string themeName: "Omarchy"
  readonly property string appVersion: "0.2"
  readonly property int popupWidthPercent: Config.popupWidth(configuration.popupWidthPercent)
  property date clockNow: new Date()
  readonly property var clockSettings: Config.clock(configuration.clock)
  Timer { interval: 1000; running: root.visible; repeat: true; onTriggered: root.clockNow=new Date() }
  property real availableScreenWidth: Screen.desktopAvailableWidth > 0 ? Screen.desktopAvailableWidth : width
  property var configuration: ({colors: {}, mainPanel: "overview"})
  property string focusedPanel: configuration.mainPanel || "overview"
  readonly property var enabledModules: Config.modules(configuration.enabledModules)
  property var slots: enabledModules.filter(function(key) { return key !== focusedPanel })
  onEnabledModulesChanged: syncModules()
  function syncModules() {
    if(enabledModules.indexOf(focusedPanel)<0)focusedPanel=enabledModules[0]
    var next=(slots || []).filter(function(key,index,list){return key!==focusedPanel && enabledModules.indexOf(key)>=0 && list.indexOf(key)===index})
    enabledModules.forEach(function(key){if(key!==focusedPanel && next.indexOf(key)<0)next.push(key)})
    slots=next
  }
  property int selectedNews: 0
  readonly property bool narrow: width < 900
  readonly property bool shortWindow: height < 700
  readonly property color bg: colorFor("background", themeBackground)
  readonly property color fg: colorFor("foreground", themeForeground)
  readonly property color accent: colorFor("accent", themeAccent)
  readonly property color surface: mix(bg, fg, 0.035)
  readonly property color edge: mix(bg, fg, 0.16)
  readonly property color muted: mix(bg, fg, 0.63)
  property var popupStyleExtras:[]
  readonly property var popupAppearance:Config.popupAppearance(configuration.popupAppearance)
  PopupAppearanceManager {target:root;extraTargets:root.popupStyleExtras;overlay:root.Overlay.overlay;appearance:root.popupAppearance;backgroundColor:root.surface;borderColor:root.edge}
  readonly property var fontSizes:Config.fontSizes(configuration.fontSizes)
  readonly property real summaryTextScale:textScale*fontSizes.summaries/12
  readonly property real textScale: Math.max(0.85, Math.min(1.5, Number(configuration.textScale || 1)))
  property string demoNote: ""
  property var notesData: [{title:"First note",body:demoNote}]
  property int notesSelection: 0
  signal notesEdited(var entries)
  property var modules: ({
    overview: {title: "Overview", subtitle: "A little space for everything.", icon: "\uf009", tag: "YOUR DAY, AT A GLANCE"},
    weather: {title: "Weather", subtitle: "A change of scenery.", icon: "\uf0c2", tag: "OUTSIDE / LIVE WEATHER"},
    calendar: {title: "Calendar", subtitle: "Make room for what matters.", icon: "\uf073", tag: "ON YOUR HORIZON"},
    email: {title:"Email",icon:"\uf0e0",tag:"YOUR INBOX"},
    notes: {title: "Notes", subtitle: "Keep a thought close.", icon: "\uf044", tag: "YOUR PERSONAL SCRATCHPAD"}
  })
  property var mailService: null
  readonly property var calendarPreferences:CalendarPreferences.normalize(mailService?mailService.settings:{})
  property string accountSettingsError:""
  property var accountPreferencesFlush:null
  property Component backupSettingsComponent
  property Component emailSettingsComponent
  property Component calendarSettingsComponent
  signal accountsRequested()
  property Component calendarPanelComponent
  property var calendarEvents: []
  readonly property Component calendarHeading: Component { ModuleHeading {} }
  readonly property var calendarPreviews: calendarEvents.filter(function(event){return event.start && Number(event.end ? event.end.ms : event.start.ms)>clockNow.getTime()}).sort(function(a,b){return Number(a.start.ms)-Number(b.start.ms)}).slice(0,3)
  function openCalendarId(eventId,startMs) {
    if(enabledModules.indexOf("calendar")<0){calendarUnavailable.open();return}
    if(focusedPanel!=="calendar")promote(slots.indexOf("calendar"))
    if(eventId)Qt.callLater(function(){var panel=calendarDetailLoader.item;if(panel && panel.item)panel.item.openEventId(eventId,startMs)})
  }
  function openCalendarEvent(event) {
    if(focusedPanel!=="calendar")promote(slots.indexOf("calendar"))
    Qt.callLater(function(){var panel=calendarDetailLoader.item; if(panel && panel.item)panel.item.openEvent(event)})
  }
  property Component emailPanelComponent
  readonly property Component emailHeading: Component { ModuleHeading {} }
  readonly property var mailPreviews: mailService ? (mailService.barMessages || []).slice(0,3) : []
  function openMail(accountId,messageId) {
    if(!mailService)return
    if(accountId && mailService.switchTo(accountId)===false)return
    if(focusedPanel!=="email")promote(slots.indexOf("email"))
    var ownerService=mailService,ownerAccount=mailService.activeAccountId
    if(messageId)Qt.callLater(function(){if(root.mailService===ownerService && ownerService.activeAccountId===ownerAccount)ownerService.select(messageId)})
  }
  readonly property string overviewSummary: {
    var parts=[]
    if(enabledModules.indexOf("weather")>=0 && weatherData.current)parts.push(Weather.number(weatherData.current.temperature)+(weatherData.units || {}).temperature+" · "+Weather.condition(weatherData.current.code))
    var next=Overview.nextEvent(calendarEvents,clockNow.getTime())
    if(enabledModules.indexOf("calendar")>=0 && next)parts.push("Next: "+(next.summary || "Untitled event"))
    if(enabledModules.indexOf("email")>=0 && mailService)parts.push(mailService.unreadTotal+" unread messages")
    if(enabledModules.indexOf("notes")>=0)parts.push(recentNotes.length+" recent notes")
    return parts.join(" · ") || "Open Overview for your daily summaries"
  }
  property var weatherData: ({})
  property string weatherStatus: "Loading weather…"
  property var locationResults: []
  property string locationStatus: ""
  signal locationSearchRequested(string query)
  signal weatherRefreshRequested(int zoom)
  property var headlines: []
  property string feedStatus: "Loading news…"
  property var selectedArticle: ({title:"",body:"",published:"",publisher:"",url:""})
  readonly property int sidebarWidthPercent:Config.sidebarWidth(configuration.sidebarWidthPercent)
  readonly property bool rssEnabled:rssConfiguration.enabled
  onRssEnabledChanged:if(!rssEnabled && article)article.close()
  readonly property var rssConfiguration: Config.rss(configuration.rss)
  readonly property real rssScrollSpeed: rssConfiguration.scrollSpeed
  property real previousScrollTime: 0
  signal configurationEdited(var value)
  signal closeRequested()
  signal refreshNewsRequested()

  readonly property var recentNotes: notesData.map(function(note,index) {
    return {noteIndex:index,title:note.title.trim() || "Untitled note",firstLine:note.body.split(/\r?\n/)[0],updated:Number(note.updated)||0}
  }).sort(function(a,b) { return b.updated-a.updated || b.noteIndex-a.noteIndex }).slice(0,3)
  function openNote(index) {
    if(index<0 || index>=notesData.length)return
    notesSelection=index
    if(focusedPanel!=="notes")promote(slots.indexOf("notes"))
  }
  function articleDate(value) {
    var date = new Date(value)
    return !value || isNaN(date.getTime()) ? "Date unavailable" : Qt.formatDateTime(date, "MMM d, yyyy")
  }
  function openSettings() { settings.open() }
  function openArticle(index) {
    if (!rssEnabled || !headlines.length) return
    selectedNews = index % headlines.length
    selectedArticle = headlines[selectedNews]
    article.open()
  }
  function advanceNews(seconds) {
    if(!rssEnabled)return
    var span = headlines.length * (feed.cardWidth + feed.spacing)
    if (span <= feed.width || rssScrollSpeed <= 0) return
    feed.contentX = (Math.max(0, feed.contentX) + rssScrollSpeed * seconds) % span
  }

  function mix(a, b, amount) { return Qt.rgba(a.r + (b.r-a.r)*amount, a.g + (b.g-a.g)*amount, a.b + (b.b-a.b)*amount, 1) }
  function colorFor(key, fallback) { var value = (configuration.colors || {})[key]; return /^#[0-9a-fA-F]{6}$/.test(value || "") ? value : fallback }
  function moduleInfo(key) { return modules[key] || modules.overview }
  function promote(index) {
    if (index < 0 || index >= slots.length) return
    var next = slots.slice(); var old = focusedPanel
    focusedPanel = next[index]; next[index] = old; slots = next
  }
  function prepareCalendarExit(done) {
    var loader=calendarDetailLoader.item
    var panel=loader ? loader.item : null
    if(panel && typeof panel.requestLeave==="function") {
      if(panel.needsExitReview){
        if(Window.window)Window.window.visible=true
        if(focusedPanel!=="calendar")promote(slots.indexOf("calendar"))
      }
      panel.requestLeave(done)
    } else done(true)
  }
  function flushMailDrafts(done) {
    var loader=emailDetailLoader.item
    var panel=loader ? loader.item : null
    if(panel && typeof panel.flushDrafts==="function")panel.flushDrafts(done)
    else if(done)done(true)
  }
  function updateConfiguration(colors, scale, rss, popupWidth, weather, clock, fullscreenTitleSize, enabledModules, overview, sidebarWidthPercent, fontSizes, popupAppearance) {
    var selected=Config.modules(enabledModules === undefined ? configuration.enabledModules : enabledModules)
    var nextFocused=selected.indexOf(focusedPanel)>=0?focusedPanel:selected[0]
    var value = { popupAppearance:Config.popupAppearance(popupAppearance===undefined?configuration.popupAppearance:popupAppearance), fontSizes:Config.fontOverrides(fontSizes===undefined?configuration.fontSizes:fontSizes), sidebarWidthPercent:Config.sidebarWidth(sidebarWidthPercent===undefined?configuration.sidebarWidthPercent:sidebarWidthPercent), overview:Config.overview(overview===undefined?configuration.overview:overview), enabledModules:selected, fullscreenTitleSize:Config.sectionTitleSize(fullscreenTitleSize === undefined ? configuration.fullscreenTitleSize : fullscreenTitleSize), clock: Config.clock(clock === undefined ? configuration.clock : clock), colors: colors, textScale: scale, mainPanel: nextFocused, rss: Config.rss(rss === undefined ? configuration.rss : rss), popupWidthPercent: Config.popupWidth(popupWidth === undefined ? configuration.popupWidthPercent : popupWidth), weather: Config.weather(weather === undefined ? configuration.weather : weather) }
    function commit(){
      if(root.accountPreferencesFlush)root.accountPreferencesFlush(function(ok){if(ok)writeCommit();else root.openSettings()})
      else writeCommit()
    }
    function writeCommit() {
      root.focusedPanel=nextFocused
      root.configuration=value
      root.syncModules()
      root.configurationEdited(value)
    }
    function afterCalendar() {
      if(root.enabledModules.indexOf("email")>=0 && selected.indexOf("email")<0)root.flushMailDrafts(function(ok){if(ok)commit();else if(root.focusedPanel!=="email")root.promote(root.slots.indexOf("email"))})
      else commit()
    }
    if(root.enabledModules.indexOf("calendar")>=0 && selected.indexOf("calendar")<0)prepareCalendarExit(function(ok){if(ok)afterCalendar()})
    else afterCalendar()
  }

  Rectangle { anchors.fill: parent; color: root.bg }
  ColumnLayout {
    objectName:"dashboardLayout"
    anchors.fill: parent
    anchors.bottomMargin:root.shortWindow ? 10 : 18
    anchors.margins: root.shortWindow ? 12 : (root.narrow ? 18 : 28)
    spacing: root.shortWindow ? 10 : 18
    Item {
      Layout.fillWidth: true
      implicitHeight: Math.max(toolbar.implicitHeight, titleClock.implicitHeight)
    RowLayout {
      id: toolbar
      anchors.fill: parent
      spacing: 12
      Rectangle {
        width: 36; height: 36; radius: 10; color: root.accent
        Text { anchors.centerIn: parent; text: "\uf009"; font.family: root.themeFont; font.pixelSize: 18; color: root.bg }
      }
      ColumnLayout {
        id: brand
        spacing: 3
        Label { text: "StarDock"; color: root.fg; font.family: root.themeFont; font.pixelSize: 16*root.textScale; font.letterSpacing: 3; font.bold: true }
      }
      Item { Layout.fillWidth: true }
      IconControl { objectName: "settingsButton"; glyph: "\uf013"; hint: "Settings"; onClicked: settings.open() }
      IconControl { objectName: "aboutButton"; glyph: "\uf05a"; hint: "About StarDock"; onClicked: about.open() }
      IconControl { id: closeControl; objectName: "closeButton"; glyph: "\uf00d"; hint: "Close dashboard"; onClicked: root.closeRequested() }
    }
      Label {
        id: titleClock
        objectName: "titleClock"
        anchors.centerIn: parent
        width: Math.max(0,parent.width-2*Math.max(48+brand.width,3*closeControl.width+24)-24)
        text: Qt.formatTime(root.clockNow,root.clockSettings.hourFormat==="24"?"HH:mm":"h:mm AP")+" · "+Qt.formatDate(root.clockNow,root.clockSettings.dateFormat)
        color: root.fg
        font.pixelSize: root.clockSettings.fontSize
        ToolTip.visible: clockHover.hovered
        ToolTip.text: text
        HoverHandler { id: clockHover }
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
      }
    }
    Rectangle { Layout.fillWidth: true; height: 1; color: root.edge }

    GridLayout {
      id: panelGrid
      Layout.fillWidth: true
      Layout.fillHeight: true
      columns: root.narrow ? 1 : 2
      columnSpacing: 16
      rowSpacing: 12
      Rectangle {
        id: mainPanel
        objectName: "mainPanel"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: root.narrow ? 1 : (root.fullscreenMode ? (panelGrid.width-panelGrid.columnSpacing)*(100-root.sidebarWidthPercent)/100 : 2)
        Layout.minimumWidth:0
        Layout.preferredHeight: root.narrow ? 3 : 1
        Layout.minimumHeight: root.shortWindow ? 120 : 200
        color: root.surface; border.color: root.edge; radius: 16; clip: true
        ColumnLayout {
          anchors.fill: parent; anchors.margins: root.narrow ? 18 : 26; spacing: 16
          ScrollView {
            id: detailScroll
            visible: root.focusedPanel!=="notes" && root.focusedPanel!=="email" && root.focusedPanel!=="calendar"
            objectName: "detailScroll"
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            rightPadding: 24
            contentWidth: availableWidth
            GridLayout {
              width: detailScroll.availableWidth
              columns: width<520 ? 1 : 2
              columnSpacing: 16; rowSpacing: 16
              ModuleHeading {
                visible: root.focusedPanel!=="weather"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: (detailScroll.availableWidth-16)*.25
                Layout.alignment: Qt.AlignTop
              }
              Loader {
                active: root.focusedPanel!=="notes" && root.focusedPanel!=="email" && root.focusedPanel!=="calendar"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: (detailScroll.availableWidth-16)*.75
                Layout.columnSpan: root.focusedPanel==="weather" ? parent.columns : 1
                Layout.alignment: Qt.AlignTop
                sourceComponent: root.focusedPanel === "weather" ? weatherDetail : root.focusedPanel === "calendar" ? calendarDetail : root.focusedPanel === "notes" ? notesDetail : root.focusedPanel === "email" ? emailDetail : overviewDetail
              }
            }
          }
          Loader {
            active:root.focusedPanel==="notes"
            visible:active
            Layout.fillWidth:true;Layout.fillHeight:true
            sourceComponent:notesDetail
          }
          Loader {
            id:calendarDetailLoader
            active:root.enabledModules.indexOf("calendar")>=0
            visible:root.focusedPanel==="calendar"
            Layout.fillWidth:true;Layout.fillHeight:true
            sourceComponent:calendarDetail
          }
          Loader {
            id:emailDetailLoader
            active:root.enabledModules.indexOf("email")>=0
            visible:root.focusedPanel==="email"
            Layout.fillWidth:true;Layout.fillHeight:true
            sourceComponent:emailDetail
          }
          RowLayout {
            visible: root.focusedPanel !== "email"
            Layout.fillWidth: true
            Rectangle { width: 5; height: 5; radius: 3; color: root.accent }
            Label { text: root.focusedPanel === "weather" ? "Open-Meteo · NOAA/NWS · OpenStreetMap" : root.focusedPanel === "notes" ? "Notes · saved automatically" : root.focusedPanel === "email" ? "Mail · StarMail" : root.focusedPanel === "calendar" ? "Calendar · StarMail" : "Live summaries · enabled modules"; color: root.muted; font.pixelSize: 10*root.textScale }
            Item { Layout.fillWidth: true }
          }
        }
      }
      GridLayout {
        id: summaries
        objectName:"summaryColumn"
        uniformCellHeights: true
        uniformCellWidths: true
        Layout.fillWidth: true; Layout.fillHeight: !root.narrow
        Layout.preferredWidth: !root.narrow && root.fullscreenMode ? (panelGrid.width-panelGrid.columnSpacing)*root.sidebarWidthPercent/100 : 1
        Layout.minimumWidth:0
        Layout.preferredHeight: root.narrow ? (root.shortWindow ? 76 : 110) : 1
        columns: root.narrow ? root.slots.length : 1
        rowSpacing: 12; columnSpacing: 10
        Repeater {
          model: root.slots.length
          delegate: AbstractButton {
            id: summary
            required property int index
            readonly property string panelKey: root.slots[index]
            objectName: "summary" + index
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.minimumHeight: root.shortWindow ? 68 : (root.narrow ? 95 : 100)
            Layout.preferredWidth: 1; Layout.preferredHeight: 1
            hoverEnabled: true
            Accessible.name: "Expand " + root.moduleInfo(panelKey).title
            onClicked: root.promote(index)
            background: Rectangle {
              color: summary.hovered ? root.mix(root.surface, root.accent, 0.07) : root.surface
              border.color: summary.hovered || summary.activeFocus ? root.accent : root.edge
              radius: 14
              Behavior on color { ColorAnimation { duration: 130 } }
              Behavior on border.color { ColorAnimation { duration: 130 } }
            }
            contentItem: ColumnLayout {
              anchors.fill: parent; anchors.margins: root.shortWindow ? 10 : (root.narrow ? 12 : 18); spacing: root.shortWindow ? 4 : 8
              RowLayout {
                Layout.fillWidth: true
                Label { text: root.moduleInfo(summary.panelKey).icon; font.family: root.themeFont; color: root.accent; font.pixelSize: 14 }
                Label { objectName:"summaryTitle"+summary.index; text: root.moduleInfo(summary.panelKey).title; color: root.fg; font.pixelSize: 12*root.summaryTextScale; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                Label { text: "↗"; color: summary.hovered ? root.accent : root.muted; font.pixelSize: 15 }
              }
              Label {
                visible: summary.panelKey!=="notes" && summary.panelKey!=="calendar" && (summary.panelKey!=="weather" || !root.shortWindow)
                text: summary.panelKey === "weather" ? (root.weatherData.current ? Weather.number(root.weatherData.current.temperature)+root.weatherData.units.temperature+" / "+Weather.number(root.weatherData.current.probability)+"% rain" : "Loading weather…") : summary.panelKey === "notes" ? "An unfinished thought" : summary.panelKey === "email" ? (root.mailService && root.mailService.hasSavedAccounts ? root.mailService.unreadTotal+" unread" : "Connect a mailbox") : "Your day, at a glance"
                color: root.fg; font.pixelSize: (root.narrow ? 11 : 17)*root.summaryTextScale; font.bold: !root.narrow; Layout.fillWidth: true; elide: Text.ElideRight
              }
              ScrollView {
                visible: summary.panelKey==="email"
                Layout.fillWidth:true; Layout.fillHeight:true; Layout.preferredHeight:100; Layout.minimumHeight:0
                rightPadding:24; clip:true; contentWidth:availableWidth
                ListView {
                  id:mailPreviewList
                  model:summary.panelKey==="email" ? root.mailPreviews : []
                  spacing:6
                  delegate:AbstractButton {
                    id:mailPreview
                    required property var modelData
                    required property int index
                    objectName:"mailPreview"+index
                    width:mailPreviewList.width; implicitHeight:mailPreviewText.implicitHeight+8
                    hoverEnabled:true
                    onClicked:root.openMail(modelData.accountId,modelData.id)
                    background:Rectangle { radius:5; color:mailPreview.hovered ? Qt.rgba(root.accent.r,root.accent.g,root.accent.b,.15) : "transparent" }
                    contentItem:ColumnLayout {
                      id:mailPreviewText
                      spacing:2
                      Label { text:(mailPreview.modelData.unread?"● ":"")+(mailPreview.modelData.subject || "(No subject)"); textFormat:Text.PlainText; color:root.accent; font.bold:mailPreview.modelData.unread; font.pixelSize:11*root.summaryTextScale; Layout.fillWidth:true; elide:Text.ElideRight }
                      Label { text:mailPreview.modelData.from ? mailPreview.modelData.from.display : ""; textFormat:Text.PlainText; color:root.muted; font.pixelSize:10*root.summaryTextScale; Layout.fillWidth:true; elide:Text.ElideRight }
                    }
                  }
                  Label { anchors.fill:parent; visible:!root.mailPreviews.length; text:root.mailService && root.mailService.hasSavedAccounts ? "No recent messages" : "Open Email to connect a mailbox"; color:root.muted; font.pixelSize:11*root.summaryTextScale; wrapMode:Text.Wrap }
                }
              }
              ScrollView {
                objectName:"calendarSummaryPreview"
                visible:summary.panelKey==="calendar"
                Layout.fillWidth:true;Layout.fillHeight:true;Layout.preferredHeight:114;Layout.minimumHeight:0
                clip:true;rightPadding:24;contentWidth:availableWidth
                ListView {
                  id:calendarPreviews
                  model:summary.panelKey==="calendar" ? root.calendarPreviews : []
                  spacing:6
                  delegate:AbstractButton {
                    id:eventPreview
                    required property var modelData
                    required property int index
                    objectName:"calendarPreview"+index
                    width:calendarPreviews.width;implicitHeight:eventText.implicitHeight+8
                    hoverEnabled:true
                    onClicked:root.openCalendarEvent(modelData)
                    background:Rectangle {radius:5;color:eventPreview.hovered ? Qt.rgba(root.accent.r,root.accent.g,root.accent.b,.15) : "transparent"}
                    contentItem:ColumnLayout {
                      id:eventText
                      spacing:2
                      Label {text:eventPreview.modelData.summary || "Untitled event";textFormat:Text.PlainText;color:root.accent;font.pixelSize:11*root.summaryTextScale;Layout.fillWidth:true;elide:Text.ElideRight}
                      Label {text:Qt.formatDateTime(new Date(Number(eventPreview.modelData.start.ms)),eventPreview.modelData.start.allDay ? root.calendarPreferences.calendarDateFormat+" · 'All day'" : root.calendarPreferences.calendarDateFormat+" · "+(root.calendarPreferences.calendarTimeFormat==="24"?"HH:mm":"h:mm AP"));color:root.muted;font.pixelSize:10*root.summaryTextScale;Layout.fillWidth:true;elide:Text.ElideRight}
                    }
                  }
                  Label {anchors.fill:parent;visible:!root.calendarPreviews.length;text:"No upcoming events in the next 31 days. Open Calendar to connect sources.";color:root.muted;font.pixelSize:11*root.summaryTextScale;wrapMode:Text.Wrap}
                }
              }
              ScrollView {
                objectName: "notesSummaryPreview"
                visible: summary.panelKey==="notes"
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredHeight: 114; Layout.minimumHeight: 0
                clip: true; rightPadding: 24; contentWidth: availableWidth
                ListView {
                  id: notePreviews
                  model: summary.panelKey==="notes" ? root.recentNotes : []
                  spacing: 6
                  delegate: AbstractButton {
                    id: preview
                    required property var modelData
                    required property int index
                    objectName: "notePreview"+index
                    width: notePreviews.width
                    implicitHeight: previewContent.implicitHeight+8
                    hoverEnabled: true
                    Accessible.name: "Open note "+modelData.title
                    onClicked: root.openNote(modelData.noteIndex)
                    background: Rectangle { radius: 5; color: preview.hovered ? Qt.rgba(root.accent.r,root.accent.g,root.accent.b,.15) : "transparent" }
                    contentItem: ColumnLayout {
                      id: previewContent
                      spacing: 2
                      Label { text: preview.modelData.title; textFormat: Text.PlainText; color: root.accent; font.pixelSize: 11*root.summaryTextScale; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                      Label { text: preview.modelData.firstLine || "Empty note"; textFormat: Text.PlainText; color: root.muted; font.pixelSize: 10*root.summaryTextScale; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                  }
                }
              }
              RowLayout {
                objectName: "weatherSummaryForecast"
                visible: summary.panelKey==="weather"
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                  model: summary.panelKey==="weather" ? (root.weatherData.daily || []).slice(1,6) : []
                  delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    spacing: 3
                    Label {
                      text: Qt.formatDate(new Date(modelData.date+"T12:00:00"),"ddd")+" "+Weather.icon(modelData.code)
                      color: root.accent; font.pixelSize: (root.shortWindow?9:11)*root.summaryTextScale
                      Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    }
                    Label {
                      text: Weather.number(modelData.high)+"° / "+Weather.number(modelData.low)+"°"
                      color: root.fg; font.pixelSize: (root.shortWindow?9:11)*root.summaryTextScale
                      Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    }
                    Label {
                      visible: !root.shortWindow && !root.narrow
                      text: Weather.number(modelData.probability)+"% rain"
                      color: root.muted; font.pixelSize: 10*root.summaryTextScale
                      Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    }
                  }
                }
              }
              Label {
                visible: summary.panelKey!=="notes" && summary.panelKey!=="email" && summary.panelKey!=="calendar" && !root.narrow && !root.shortWindow
                text: summary.panelKey === "weather" ? (root.weatherData.alerts ? (root.weatherData.alerts.error || (root.weatherData.alerts.items.length?"⚠ "+root.weatherData.alerts.items.length+" active alert(s)":"No active NWS alerts")) : root.weatherStatus) : summary.panelKey === "email" ? "Email module ready to configure. No account connected." : root.overviewSummary
                font.family: root.themeFont; color: root.muted; font.pixelSize: 11*root.summaryTextScale; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true
              }
              Item { visible: summary.panelKey!=="notes" && summary.panelKey!=="email" && summary.panelKey!=="calendar"; Layout.fillHeight: true }
              Label { visible: summary.panelKey!=="notes" && summary.panelKey!=="email" && summary.panelKey!=="calendar" && !root.narrow && !root.shortWindow; text: "CLICK TO EXPLORE"; color: root.accent; font.pixelSize: 9; font.letterSpacing: 1.2 }
            }
          }
        }
      }
    }

    Rectangle {
      id: newsPanel
      visible:root.rssEnabled
      objectName: "rssFeed"
      Layout.fillWidth: true
      Layout.preferredHeight: (root.shortWindow ? 125 : 210)+Math.max(0,root.fontSizes.rssHeadline*root.textScale-15)*(root.shortWindow?2:4)
      radius: 14; color: root.surface; border.color: root.edge
      ColumnLayout {
        anchors.fill: parent; anchors.margins: 16; spacing: 10
        RowLayout {
          Label { text: "\uf09e"; color: root.accent; font.family: root.themeFont; font.pixelSize: 13 }
          Label { text: "RSS News Feeds"; color: root.fg; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.4 }
          Item { Layout.fillWidth: true }
          Label { text: root.feedStatus; textFormat: Text.PlainText; color: root.muted; font.pixelSize: 10; Layout.maximumWidth: newsPanel.width * .45; elide: Text.ElideRight }
          IconControl { glyph: "\uf021"; hint: "Refresh feeds"; implicitWidth: 24; implicitHeight: 24; onClicked: root.refreshNewsRequested() }
        }
        ListView {
          id: feed
          Layout.fillWidth: true; Layout.fillHeight: true
          orientation: ListView.Horizontal; spacing: 12; clip: true
          objectName: "newsList"
          readonly property real cardWidth: Math.max(300, (width - 24)/3)
          model: root.headlines.length * (cardWidth + spacing) > width ? root.headlines.concat(root.headlines) : root.headlines
          onModelChanged: contentX = 0
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
          delegate: AbstractButton {
            required property var modelData
            required property int index
            width: feed.cardWidth; height: feed.height
            hoverEnabled: true
            Accessible.name: modelData.title
            onClicked: root.openArticle(index)
            background: Rectangle { color: parent.hovered ? root.mix(root.surface, root.accent, 0.07) : "transparent"; radius: 8; border.color: root.edge }
            contentItem: ColumnLayout {
              anchors.fill: parent; anchors.margins: 12; spacing: 7
              RowLayout {
                Layout.fillWidth: true; spacing: 12
                Label { objectName:"rssHeadline"+index; text: modelData.title; textFormat: Text.PlainText; color: root.accent; font.pixelSize: root.fontSizes.rssHeadline*root.textScale; font.bold: true; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true }
                Label { text: root.articleDate(modelData.published); color: root.muted; font.pixelSize: 12*root.textScale; Layout.alignment: Qt.AlignTop; ToolTip.visible: hovered; ToolTip.text: modelData.published || "Publication date unavailable"; property bool hovered: dateHover.hovered; HoverHandler { id: dateHover } }
              }
              Label { visible: !root.shortWindow; text: modelData.body || "Open this article for more information."; textFormat: Text.PlainText; color: root.fg; font.pixelSize: 12*root.textScale; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true }
              Label { visible: !root.shortWindow; text: modelData.publisher + "   ↗"; textFormat: Text.PlainText; color: root.muted; font.pixelSize: 10; Layout.fillHeight: true; Layout.fillWidth: true; elide: Text.ElideRight; verticalAlignment: Text.AlignBottom }
            }
          }
          HoverHandler { id: feedHover }
          Label { anchors.centerIn: parent; visible: !root.headlines.length; text: root.feedStatus; textFormat: Text.PlainText; color: root.muted; width: parent.width-24; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
        }
      }
    }
    RowLayout {
      objectName:"dashboardFooter"
      Layout.fillWidth: true
      Label { objectName:"appFooter"; text: "Scott Fors | Ver. "+root.appVersion; color: root.muted; font.pixelSize: 11*root.textScale }
      Item { Layout.fillWidth: true }
      Label { text: root.themeName + "  ·  " + (Object.keys(root.configuration.colors || {}).length ? "Custom colors" : "System palette"); color: root.muted; font.pixelSize: 9 }
    }
  }

  Timer {
    objectName: "newsScrollTimer"
    interval: 16; repeat: true
    running: root.visible && root.rssEnabled && root.headlines.length * (feed.cardWidth + feed.spacing) > feed.width && root.rssScrollSpeed > 0 && !feedHover.hovered && !feed.moving && !settings.visible && !about.visible && !article.visible
    onRunningChanged: root.previousScrollTime = Date.now()
    onTriggered: {
      var now = Date.now()
      root.advanceNews(Math.min(.1, (now-root.previousScrollTime)/1000))
      root.previousScrollTime = now
    }
  }

  component IconControl: AppButton {
    property string glyph
    property string hint
    implicitWidth: 36; implicitHeight: 36
    hoverEnabled: true
    Accessible.name: hint
    ToolTip.visible: hovered
    ToolTip.text: hint
    contentItem: Text { text: parent.glyph; color: root.fg; font.family: root.themeFont; font.pixelSize: 15; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
  }
  component Paragraph: Label {
    color: root.muted; font.pixelSize: 13*root.textScale
    wrapMode: Text.Wrap; Layout.fillWidth: true
    lineHeight: 1.45
  }
  component ModuleHeading: ColumnLayout {
    objectName: "moduleHeading"
    spacing: 16
    RowLayout {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      Label { text: root.moduleInfo(root.focusedPanel).icon; color: root.accent; font.family: root.themeFont; font.pixelSize: 17 }
      Label { text: root.moduleInfo(root.focusedPanel).tag; color: root.muted; font.pixelSize: 10*root.textScale; font.letterSpacing: 1; Layout.fillWidth: true; wrapMode: Text.Wrap }
    }
    Label { text: root.moduleInfo(root.focusedPanel).title; color: root.fg; font.pixelSize: root.sectionTitleSize; font.bold: true; Layout.fillWidth: true; wrapMode: Text.Wrap }
  }
  component SmallHeading: Label { color: root.fg; font.pixelSize: 11*root.textScale; font.bold: true; font.letterSpacing: 0.5 }
  component DemoDialog: Dialog {
    id:dialog
    readonly property bool dropShadow:root.popupAppearance.shadowSize>0
    modal: true; anchors.centerIn: parent; width: Math.min(root.width-32, 520)
    padding: 24; closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    palette.window: root.surface; palette.windowText: root.fg; palette.text: root.fg; palette.buttonText: root.fg; palette.button: root.bg; palette.base: root.bg; palette.highlight: root.accent
    background: PopupSurface {appearance:root.popupAppearance;color:root.surface;border.color:root.edge}
    header: Label { text: parent.title; color: root.fg; font.pixelSize: 22; font.bold: true; padding: 24; bottomPadding: 4 }
  }

  Component {
    id: overviewDetail
    OverviewPanel {
      options:Config.overview(root.configuration.overview)
      enabledModules:root.enabledModules
      weather:root.weatherData;weatherStatus:root.weatherStatus
      calendarStatus:root.mailService && root.mailService.calendarController ? (root.mailService.calendarController.noCalendars?"Connect a calendar to see your schedule.":root.mailService.calendarController.loading?"Refreshing schedule…":root.mailService.calendarController.lastError?"Refresh failed · showing available events":"") : "Calendar is starting…"
      events:root.calendarEvents;now:root.clockNow.getTime()
      notes:root.recentNotes;messages:root.mailPreviews
      unreadCount:root.mailService?root.mailService.unreadTotal:0
      mailConnected:!!root.mailService && root.mailService.hasSavedAccounts
      dateFormat:root.calendarPreferences.calendarDateFormat
      timeFormat:root.calendarPreferences.calendarTimeFormat==="24"?"HH:mm":"h:mm AP"
      fg:root.fg;bg:root.bg;accent:root.accent;muted:root.muted;edge:root.edge;textScale:root.textScale
      onModuleRequested:function(key){if(root.focusedPanel!==key)root.promote(root.slots.indexOf(key))}
      onEventRequested:function(event){root.openCalendarEvent(event)}
      onNoteRequested:function(index){root.openNote(index)}
      onMailRequested:function(accountId,messageId){root.openMail(accountId,messageId)}
    }
  }
  Component {
    id: weatherDetail
    WeatherPanel {
      fullscreenMode: root.fullscreenMode
      heading: Component { ModuleHeading {} }
      weather: root.weatherData
      status: root.weatherStatus
      bg: root.bg; fg: root.fg; accent: root.accent; muted: root.muted; edge: root.edge
      fontFamily: root.themeFont; textScale: root.textScale
      onRefreshRequested: function(zoom) { root.weatherRefreshRequested(zoom) }
    }
  }
  Component {
    id: emailDetail
    Loader { sourceComponent:root.emailPanelComponent }
  }
  Component {
    id: calendarDetail
    Loader { sourceComponent:root.calendarPanelComponent }
  }
  Component {
    id: notesDetail
    NotesPanel {
      heading: Component { ModuleHeading {} }
      notes: root.notesData
      selectedIndex: root.notesSelection
      onSelectedIndexChanged: root.notesSelection=selectedIndex
      bg: root.bg; fg: root.fg; accent: root.accent; edge: root.edge; muted: root.muted
      textScale: root.textScale
      bodyFontSize:root.fontSizes.notesBody
      listFontSize:root.fontSizes.summaries
      onEdited: function(entries) { root.notesData=entries; root.notesEdited(entries) }
    }
  }

  Dialog {
    id:calendarUnavailable
    parent:Overlay.overlay;anchors.centerIn:parent;modal:true
    title:"Calendar module is disabled";width:Math.min(root.width-32,440);height:220
    background:Rectangle {color:root.bg;border.color:root.edge;radius:12}
    contentItem:Label {text:"Enable Calendar under Settings → Modules to open this event. You can still snooze or dismiss its reminder.";color:root.fg;wrapMode:Text.Wrap}
    footer:AppButton {text:"Open settings";onClicked:{calendarUnavailable.close();root.openSettings()}}
  }
  DemoDialog {
    id: settings
    objectName: "settingsDialog"
    title: "Settings"
    width: Math.min(root.width-32, 660)
    height: Math.min(root.height-32, 700)
    onOpened: settingsEditor.load()
    contentItem: SettingsEditor {
      id: settingsEditor
      objectName: "settingsEditor"
      accountError:root.accountSettingsError
      backupSettingsComponent:root.backupSettingsComponent
      emailSettingsComponent:root.emailSettingsComponent
      calendarSettingsComponent:root.calendarSettingsComponent
      configuration: root.configuration
      locationResults: root.locationResults
      locationStatus: root.locationStatus
      onLocationSearchRequested: function(query) { root.locationSearchRequested(query) }
      bg: root.bg; fg: root.fg; accent: root.accent; muted: root.muted; edge: root.edge
      systemBg: root.themeBackground; systemFg: root.themeForeground; systemAccent: root.themeAccent
      onApplyRequested: function(colors,scale,rss,popupWidth,weather,clock,fullscreenTitleSize,enabledModules,overview,sidebarWidthPercent,fontSizes,popupAppearance) { root.updateConfiguration(colors,scale,rss,popupWidth,weather,clock,fullscreenTitleSize,enabledModules,overview,sidebarWidthPercent,fontSizes,popupAppearance); settings.close() }
      onCanceled: settings.close()
    }
  }
  DemoDialog {
    id: about
    objectName: "aboutDialog"
    title: "A space for your day."
    footer: AppButton { text: "Close"; onClicked: about.close() }
    contentItem: ColumnLayout {
      spacing: 16
      SmallHeading { text: "StarDock"; color: root.accent }
      Paragraph { text: "Four spaces. One focus. Click a summary card to swap it into the large panel. Resize the window to see the layout adapt." }
      Paragraph { text: "Built for Omarchy with Qt Quick and Quickshell. Colors follow your active theme unless you override them in Settings." }
      Paragraph { text: "Weather forecasts, radar, alerts and RSS stories are live. Overview summarizes your enabled modules. Email and calendars use your connected accounts. Notes save automatically on this computer." }
      Label { text: "VERSION "+root.appVersion+"  ·  LIVE RSS"; color: root.muted; font.pixelSize: 10 }
    }
  }
  DemoDialog {
    id: article
    objectName: "articleDialog"
    title: "RSS News Feeds"
    width: Math.min(root.width-32, root.availableScreenWidth * root.popupWidthPercent / 100)
    height: Math.min(root.height-32, implicitHeight)
    bottomPadding: 8
    footer: Control {
      leftPadding: 24; rightPadding: 24; topPadding: 0; bottomPadding: 16
      contentItem: RowLayout {
        objectName: "articleActions"
        spacing: 12
        AppButton {
          objectName: "openOriginalArticle"
          text: "Open original article ↗"
          Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.minimumWidth: 0
          enabled: /^https?:\/\//.test(root.selectedArticle.url || "")
          ToolTip.visible: hovered; ToolTip.text: text
          contentItem: Label { text: parent.text; color: root.fg; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
          onClicked: Qt.openUrlExternally(root.selectedArticle.url)
        }
        AppButton {
          objectName: "closeArticle"
          text: "Close"
          Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.minimumWidth: 0
          onClicked: article.close()
        }
      }
    }
    contentItem: ColumnLayout {
      spacing: 16
      Label { text: root.selectedArticle.title; textFormat: Text.PlainText; color: root.fg; font.pixelSize: article.width < 520 ? 18 : 22; wrapMode: Text.Wrap; Layout.minimumWidth: 0; Layout.fillWidth: true }
      Label { text: root.selectedArticle.publisher + " · " + root.articleDate(root.selectedArticle.published); textFormat: Text.PlainText; color: root.accent; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }
      ScrollView {
        id: articleScroll
        objectName: "articleText"
        Layout.fillWidth: true; Layout.fillHeight: true
        Layout.minimumWidth: 0; Layout.minimumHeight: 0
        Layout.preferredHeight: articleFlow.implicitHeight
        Layout.maximumHeight: articleFlow.implicitHeight
        implicitHeight: articleFlow.implicitHeight
        contentWidth: availableWidth
        clip: true
        Item {
          id: articleFlow
          objectName: "articleContent"
          width: articleScroll.availableWidth
          implicitHeight: Math.max(articlePicture.visible ? articlePicture.height : 0, articleBody.implicitHeight)
          height: implicitHeight
          Item {
            id: articlePicture
            objectName: "articlePicture"
            x: 0; y: 0
            width: Math.max(1,(articleFlow.width-16)/3)
            visible: /^https?:\/\//.test(root.selectedArticle.image || "") && articleImage.status !== Image.Error
            property real imageAspect: .65
            implicitHeight: Math.min(240,width*imageAspect)
            height: implicitHeight
            onWidthChanged: Qt.callLater(articleBody.forceLayout)
            onHeightChanged: Qt.callLater(articleBody.forceLayout)
            onVisibleChanged: Qt.callLater(articleBody.forceLayout)
            Image {
              id: articleImage
              objectName: "articleImage"
              anchors.fill: parent
              source: article.visible && /^https?:\/\//.test(root.selectedArticle.image || "") ? root.selectedArticle.image : ""
              asynchronous: true; cache: true; autoTransform: true
              fillMode: Image.PreserveAspectFit
              verticalAlignment: Image.AlignTop
              sourceSize: Qt.size(640,640)
              onSourceChanged: articlePicture.imageAspect = .65
              onStatusChanged: {
                if (status === Image.Ready && implicitWidth > 0 && implicitHeight > 0)
                  articlePicture.imageAspect = implicitHeight / implicitWidth
              }
              Accessible.name: "Article image"
            }
            BusyIndicator { anchors.centerIn: parent; running: articleImage.status === Image.Loading; visible: running; width: 32; height: 32; palette.dark: root.accent }
          }
          Text {
            id: articleBody
            objectName: "articleBody"
            width: articleFlow.width
            text: ArticleText.markup(root.selectedArticle.body || "This feed includes a headline only. Open the original article to read more.",root.rssConfiguration.maxWords,root.selectedArticle.url)
            textFormat: Text.StyledText
            color: root.fg; linkColor: root.accent
            font.family: root.themeFont; font.pixelSize: root.fontSizes.rssBody*root.textScale
            wrapMode: Text.Wrap; lineHeight: 1.45
            function lineInset(y) { return articlePicture.visible && y<articlePicture.height ? articlePicture.width+16 : 0 }
            onLineLaidOut: function(line) {
              line.x=lineInset(line.y)
              line.width=Math.max(1,width-line.x)
            }
            onLinkActivated: function(link) { if (/^https?:\/\//.test(link)) Qt.openUrlExternally(link) }
            HoverHandler { cursorShape: articleBody.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
          }
        }
      }
    }
  }
}
