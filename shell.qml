import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "Config.js" as Config

ShellRoot {
  id: root
  readonly property string home: Quickshell.env("HOME")
  property color backgroundColor: "#071426"
  property color foregroundColor: "#c8d9e9"
  property color accentColor: "#6cb6ff"
  property string fontFamily: "JetBrainsMono Nerd Font"
  property string themeName: "Omarchy"
  property var config: ({enabledModules:Config.modules(undefined), fullscreenTitleSize:36, clock: Config.clock({}), colors: {}, textScale: 1, mainPanel: "overview", popupWidthPercent: 33, rss: Config.rss({}), weather: Config.weather({})})
  property bool configLoaded: false
  property var rssCache: ({})
  property var news: []
  property string newsStatus: "Loading news…"
  property bool refreshPending: false
  onConfigLoadedChanged: if (configLoaded) { activeMapZoom=Config.weather(config.weather).mapZoom; refreshRss(); refreshWeather() }
  onConfigChanged: if (configLoaded) { activeMapZoom=Config.weather(config.weather).mapZoom; refreshRss(); refreshWeather() }

  function refreshRss() {
    if (rssProcess.running) { refreshPending = true; return }
    var feeds = Config.rss(config.rss).feeds
    if (!feeds.length) { news = []; newsStatus = "Add an RSS feed in Settings"; return }
    newsStatus = "Refreshing feeds…"
    rssProcess.requestedFeeds = feeds
    rssProcess.output = ""
    rssProcess.running = true
  }
  function applyFeedResult(raw) {
    var results = JSON.parse(raw).feeds
    var cache = Object.assign({}, rssCache)
    var failures = 0
    results.forEach(function(result) {
      if (result.error) failures++
      else cache[result.url] = result.articles
    })
    rssCache = cache
    var articles = []
    Config.rss(config.rss).feeds.forEach(function(feed) {
      articles = articles.concat((cache[feed.url] || []).slice(0,feed.count))
    })
    news = articles
    newsStatus = failures ? (articles.length ? "Some feeds unavailable · showing available stories" : "Could not load feeds · check URLs or connection") : (articles.length ? articles.length + " articles · auto-scroll" : "No articles available")
  }
  Process {
    id: rssProcess
    property var requestedFeeds: []
    property string output: ""
    command: ["/usr/bin/python3", String(Qt.resolvedUrl("scripts/fetch_rss.py")).replace(/^file:\/\//,"")]
    stdinEnabled: true
    onStarted: { write(JSON.stringify({feeds: requestedFeeds}) + "\n"); rssDeadline.restart() }
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: rssProcess.output = String(text || "") }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      rssDeadline.stop()
      try {
        if (code !== 0) throw new Error("fetch failed")
        root.applyFeedResult(output)
      } catch (_error) { root.newsStatus = "Could not load feeds · try Refresh" }
      if (root.refreshPending) { root.refreshPending = false; Qt.callLater(root.refreshRss) }
    }
  }
  Timer { id: rssDeadline; interval: 45000; onTriggered: { rssProcess.running = false; root.newsStatus = "Feed request timed out · try Refresh" } }
  Timer { interval: 600000; running: root.configLoaded; repeat: true; onTriggered: root.refreshRss() }


  property var weatherData: ({})
  property string weatherStatus: "Loading weather…"
  property int activeMapZoom: 7
  property bool weatherPending: false
  property var locations: []
  property string locationStatus: ""
  function refreshWeather() {
    if (weatherProcess.running) { weatherPending=true; return }
    weatherStatus="Refreshing weather…"
    var value=Config.weather(config.weather)
    value.mapZoom=activeMapZoom
    weatherProcess.payload=value
    weatherProcess.output=""
    weatherProcess.running=true
  }
  function searchLocation(query) {
    if (locationProcess.running) return
    locations=[]
    locationStatus="Searching locations…"
    locationProcess.query=query
    locationProcess.output=""
    locationProcess.running=true
  }
  Process {
    id: weatherProcess
    property var payload: ({})
    property string output: ""
    command: ["/usr/bin/python3",String(Qt.resolvedUrl("scripts/fetch_weather.py")).replace(/^file:\/\//,"")]
    stdinEnabled: true
    onStarted: { write(JSON.stringify({op:"weather",config:payload})+"\n"); weatherDeadline.restart() }
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: weatherProcess.output=String(text || "") }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      weatherDeadline.stop()
      try {
        var result=JSON.parse(output)
        if (code!==0 || result.error || !result.weather) throw new Error("Unavailable")
        root.weatherData=result.weather
        root.weatherStatus="Forecast updated"
      } catch (_error) { root.weatherStatus=root.weatherData.current?"Refresh failed · showing previous weather":"Weather unavailable · try Refresh" }
      if (root.weatherPending) { root.weatherPending=false; Qt.callLater(root.refreshWeather) }
    }
  }
  Timer { id: weatherDeadline; interval: 75000; onTriggered: { weatherProcess.running=false; root.weatherStatus="Weather request timed out" } }
  Timer { interval: Config.weather(root.config.weather).refreshMinutes*60000; running: root.configLoaded; repeat: true; onTriggered: root.refreshWeather() }
  Process {
    id: locationProcess
    property string query: ""
    property string output: ""
    command: ["/usr/bin/python3",String(Qt.resolvedUrl("scripts/fetch_weather.py")).replace(/^file:\/\//,"")]
    stdinEnabled: true
    onStarted: { write(JSON.stringify({op:"search",query:query})+"\n"); locationDeadline.restart() }
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: locationProcess.output=String(text || "") }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      locationDeadline.stop()
      try {
        var result=JSON.parse(output)
        if(code!==0) throw new Error("Unavailable")
        root.locations=result.locations || []
        root.locationStatus=result.error || "Choose a matching location from the list."
      } catch (_error) { root.locationStatus="Location search unavailable. Try again." }
    }
  }
  Timer { id: locationDeadline; interval: 20000; onTriggered: { locationProcess.running=false; root.locationStatus="Location search timed out" } }

  function loadPalette(raw) {
    var keys = { background: "backgroundColor", foreground: "foregroundColor", accent: "accentColor" }
    String(raw).split("\n").forEach(function(line) {
      var match = /^\s*(background|foreground|accent)\s*=\s*["'](#[0-9a-fA-F]{6})/.exec(line)
      if (match) root[keys[match[1]]] = match[2]
    })
  }
  FileView {
    id: paletteFile
    path: root.home + "/.local/state/omarchy/current/theme/colors.toml"
    printErrors: false
    onLoaded: root.loadPalette(text())
  }
  FileView {
    id: themeNameFile
    path: root.home + "/.local/state/omarchy/current/theme.name"
    printErrors: false
    onLoaded: root.themeName = text().trim().replace(/-/g, " ")
  }
  FileView {
    id: typographyFile
    path: root.home + "/.config/omarchy/shell.toml"
    printErrors: false
    onLoaded: {
      var section = ""
      String(text()).split("\n").forEach(function(line) {
        var heading = /^\s*\[([^\]]+)\]/.exec(line)
        if (heading) section = heading[1]
        var font = /^\s*family\s*=\s*"([^"]+)"/.exec(line)
        if (section === "font" && font) root.fontFamily = font[1]
      })
    }
  }
  property bool notesLoaded:false
  property bool notesWriting:false
  property bool configWriting:false
  property string fileSaveError:""
  property var savedNotes: [{title:"First note",body:""}]
  FileView {
    id: notesFile
    path: root.home+"/.config/starlink-dashboard-notes.json"
    printErrors: false; atomicWrites: true
    onSaved:root.notesWriting=false
    onSaveFailed:{root.notesWriting=false;root.fileSaveError="Notes could not be saved"}
    onLoadFailed:root.notesLoaded=true
    onLoaded: {
      root.notesLoaded=true
      try {
        var entries=JSON.parse(text())
        if(Array.isArray(entries)) root.savedNotes=entries.map(function(note) { return {title:String(note.title || ""),body:String(note.body || ""),updated:Number(note.updated)||0} })
      } catch (_error) {}
    }
  }
  FileView {
    id: configFile
    path: root.home + "/.config/starlink-dashboard-demo.json"
    printErrors: false
    atomicWrites: true
    onSaved:root.configWriting=false
    onSaveFailed:{root.configWriting=false;root.fileSaveError="Dashboard preferences could not be saved"}
    onLoaded: {
      if (root.configLoaded) return
      try {
        var value = JSON.parse(text())
        if (value && typeof value === "object" && !Array.isArray(value)) {
          var allowed = Config.modules(value.enabledModules)
          root.config = { overview:Config.overview(value.overview), enabledModules:allowed, fullscreenTitleSize:Config.sectionTitleSize(value.fullscreenTitleSize), clock: Config.clock(value.clock), colors: value.colors || {}, textScale: Math.max(.85, Math.min(1.5, Number(value.textScale) || 1)), mainPanel: allowed.indexOf(value.mainPanel) >= 0 ? value.mainPanel : allowed[0], rss: Config.rss(value.rss), popupWidthPercent: Config.popupWidth(value.popupWidthPercent), weather: Config.weather(value.weather) }
        }
      } catch (_error) {}
      root.configLoaded = true
    }
    onLoadFailed: root.configLoaded = true
  }
  Timer {
    interval: 2000; running: true; repeat: true
    onTriggered: { paletteFile.reload(); themeNameFile.reload(); typographyFile.reload() }
  }
  IpcHandler {
    target: "dashboard"
    function show(): void { window.visible = true }
    function quit(): void { root.requestClose() }
    function settings(): void { window.visible = true; dashboard.openSettings() }
    function backupStatus(): string {return JSON.stringify({ready:backupService.ready,busy:backupService.busy,error:backupService.error,schedule:backupService.state.settings.schedule,backups:backupService.state.backups.length})}
    function accounts(): void {window.visible=true;sharedAccounts.open()}
    function refresh(): void { root.refreshRss() }
    function article(index: int): void { dashboard.openArticle(index) }
    function overview(): void {if(dashboard.focusedPanel!=="overview")dashboard.promote(dashboard.slots.indexOf("overview"))}
    function resetMailZoom(): void {if(dashboard.mailService)dashboard.mailService.setBodyZoom(1)}
    function email(): void { if (dashboard.focusedPanel!=="email") dashboard.promote(dashboard.slots.indexOf("email")) }
    function calendar(): void { if(dashboard.focusedPanel!=="calendar") dashboard.promote(dashboard.slots.indexOf("calendar")) }
    function weather(): void { if (dashboard.focusedPanel!=="weather") dashboard.promote(dashboard.slots.indexOf("weather")) }
    function status(): string { return JSON.stringify({calendarSources:dashboard.mailService ? dashboard.mailService.calendarController.availableSources.sources.length : 0,calendarEvents:dashboard.calendarEvents.length,visible:window.visible,articles:root.news.length,images:root.news.filter(function(item) { return !!item.image }).length,status:root.newsStatus,feeds:Config.rss(root.config.rss).feeds.length,weatherLocation:root.weatherData.location || "",forecastDays:(root.weatherData.daily || []).length,radar:!!(root.weatherData.map || {}).overlay,radarFrames:((root.weatherData.map || {}).frames || []).length,weatherStatus:root.weatherStatus,mailReady:!!dashboard.mailService && dashboard.mailService.backend.ready,mailVersion:dashboard.mailService && dashboard.mailService.backend.protocolInfo ? dashboard.mailService.backend.protocolInfo.version : "",mailAccounts:dashboard.mailService ? dashboard.mailService.accountSummaries.filter(function(account){return !!account.id}).length : 0}) }
  }
  Loader {
    id: mailHostLoader
    active: Config.modules(root.config.enabledModules).some(function(key){return key==="email" || key==="calendar"})
    sourceComponent: Component {
      EmailService {
        calendarEnabled:dashboard.enabledModules.indexOf("calendar")>=0
        dialogWindow:dashboard.Window.window
        windowOpen: window.visible && dashboard.focusedPanel==="email"
        onCalendarOpenRequested:function(eventId,eventStart){window.visible=true;dashboard.openCalendarId(eventId,eventStart)}
        onOpenRequested: function(accountId,messageId){ window.visible=true;dashboard.openMail(accountId,messageId) }
      }
    }
  }
  Component {
    id:calendarPreferencesComponent
    CalendarPreferences {saveError:mailHostLoader.item?mailHostLoader.item.preferencesError:"";service:dashboard.mailService;fg:dashboard.fg;muted:dashboard.muted;onAccountsRequested:sharedAccounts.open()}
  }
  SharedAccounts {
    id:sharedAccounts
    parent:dashboard.Overlay.overlay
    service:dashboard.mailService
    beforeRemove:function(done){dashboard.prepareCalendarExit(function(ok){if(ok)dashboard.flushMailDrafts(done);else done(false)})}
    bg:dashboard.bg;fg:dashboard.fg;muted:dashboard.muted;accent:dashboard.accent;edge:dashboard.edge;fontFamily:root.fontFamily
    onCalendarRequested:dashboard.openCalendarId("",0)
  }
  property bool restoreBusy:false
  property var fileFlushCallback:null
  property int fileFlushTicks:0
  function flushDashboardFiles(done){
    if(!notesWriting && !configWriting){done(!fileSaveError);return}
    fileFlushCallback=done;fileFlushTicks=0;fileFlush.start()
  }
  Timer {
    id:fileFlush
    interval:100;repeat:true
    onTriggered:{
      root.fileFlushTicks++
      if((!root.notesWriting && !root.configWriting) || root.fileFlushTicks>=50){stop();var done=root.fileFlushCallback;root.fileFlushCallback=null;if(done)done(!root.notesWriting && !root.configWriting && !root.fileSaveError)}
    }
  }
  BackupService {
    id:backupService
    automaticReady:root.configLoaded && root.notesLoaded
    liveSnapshot:({dashboard:root.config,notes:root.savedNotes})
    prepareBackup:function(done){if(mailHostLoader.item)mailHostLoader.item.flushPreferences(done);else done(true)}
    prepareRestore:function(done){
      dashboard.prepareCalendarExit(function(calendarOk){
        if(!calendarOk){done(false);return}
        dashboard.flushMailDrafts(function(mailOk){
          if(!mailOk){done(false);return}
          function finish(ok){if(!ok){done(false);return}root.flushDashboardFiles(function(saved){root.restoreBusy=saved;done(saved)})}
          if(mailHostLoader.item)mailHostLoader.item.flushPreferences(finish);else finish(true)
        })
      })
    }
    onRestoreFailed:root.restoreBusy=false
    onRestoreReady:function(ticket){
      function finish(error){
        if(error){root.restoreBusy=false;backupService.error="Could not close the account service for restore. No files were restored.";return}
        root.closingDashboard=true
        Quickshell.execDetached(["/usr/bin/python3",String(Qt.resolvedUrl("scripts/dashboard_backup.py")).replace(/^file:\/\//,""),"--finish-restore",ticket,String(Quickshell.processId)])
        Qt.quit()
      }
      if(dashboard.mailService && dashboard.mailService.backend.ready)dashboard.mailService.backend.shutdown(finish)
      else finish(null)
    }
  }
  Component {
    id:backupOptionsComponent
    BackupSettings {
      service:backupService;dialogWindow:dashboard.Window.window
      fg:dashboard.fg;bg:dashboard.bg;accent:dashboard.accent;muted:dashboard.muted;edge:dashboard.edge
    }
  }
  property bool closingDashboard:false
  function requestClose() {
    if(closingDashboard)return
    closingDashboard=true
    dashboard.prepareCalendarExit(function(calendarOk) {
      if(!calendarOk){root.closingDashboard=false;window.visible=true;return}
      dashboard.flushMailDrafts(function(ok) {
        if(!ok) { root.closingDashboard=false;window.visible=true;dashboard.openMail("","");return }
        function finish(preferencesOk){
          if(!preferencesOk){root.closingDashboard=false;window.visible=true;dashboard.openSettings();return}
          if(dashboard.mailService && dashboard.mailService.backend.ready)dashboard.mailService.backend.shutdown(function(error){Qt.quit()})
          else Qt.quit()
        }
        if(mailHostLoader.item)mailHostLoader.item.flushPreferences(finish);else finish(true)
      })
    })
  }
  FloatingWindow {
    id: window
    onClosed: root.requestClose()
    title: "StarDock"
    implicitWidth: 1320
    implicitHeight: 940
    minimumSize: Qt.size(620, 600)
    color: root.backgroundColor
    Dashboard {
      id: dashboard
      anchors.fill: parent
      themeBackground: root.backgroundColor
      themeForeground: root.foregroundColor
      themeAccent: root.accentColor
      themeFont: root.fontFamily
      themeName: root.themeName
      enabled:!root.restoreBusy
      backupSettingsComponent:backupOptionsComponent
      mailService: mailHostLoader.item ? mailHostLoader.item.service : null
      accountSettingsError:mailHostLoader.item?mailHostLoader.item.preferencesError:""
      accountPreferencesFlush:function(done){if(mailHostLoader.item)mailHostLoader.item.flushPreferences(done);else done(true)}
      calendarEvents:mailHostLoader.item ? mailHostLoader.item.calendarEvents : []
      calendarSettingsComponent:mailHostLoader.item ? calendarPreferencesComponent : null
      calendarPanelComponent: Component {
        CalendarPanel {
          service:dashboard.mailService;heading:dashboard.calendarHeading
          onAccountsRequested:sharedAccounts.open()
          bg:dashboard.bg;fg:dashboard.fg;accent:dashboard.accent;muted:dashboard.muted;edge:dashboard.edge
          fontFamily:root.fontFamily;textScale:dashboard.textScale
        }
      }
      emailPanelComponent: Component {
        EmailPanel {
          service: dashboard.mailService
          onAccountsRequested:sharedAccounts.open()
          dateFormat:dashboard.clockSettings.dateFormat
          timeFormat:dashboard.clockSettings.hourFormat==="24"?"HH:mm":"h:mm AP"
          heading: dashboard.emailHeading
          bg:dashboard.bg;fg:dashboard.fg;accent:dashboard.accent;muted:dashboard.muted;edge:dashboard.edge
          fontFamily:root.fontFamily; textScale:dashboard.textScale
        }
      }
      notesData: root.savedNotes
      onNotesEdited: function(entries) { root.notesWriting=true;root.fileSaveError="";root.savedNotes=entries; notesFile.setText(JSON.stringify(entries,null,2)+"\n") }
      configuration: root.config
      headlines: root.news
      feedStatus: root.newsStatus
      weatherData: root.weatherData
      weatherStatus: root.weatherStatus
      locationResults: root.locations
      locationStatus: root.locationStatus
      onLocationSearchRequested: function(query) { root.searchLocation(query) }
      onWeatherRefreshRequested: function(zoom) { root.activeMapZoom=zoom; root.refreshWeather() }
      onCloseRequested: root.requestClose()
      onRefreshNewsRequested: root.refreshRss()
      onConfigurationEdited: function(value) {
        root.config = value
        root.configWriting=true;root.fileSaveError=""
        configFile.setText(JSON.stringify(value, null, 2) + "\n")
      }
    }
  }
}
