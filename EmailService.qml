import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import "vendor/omamail/ui" as Omamail
import "vendor/omamail/ui/calendar" as CalendarNative
import "vendor/omamail/ui/bar/Preview.js" as Preview

Item {
  id: root
  readonly property alias service: mail
  readonly property string home: Quickshell.env("HOME")
  property bool windowOpen: false
  property bool calendarEnabled: true
  property bool emailEnabled: true
  readonly property alias calendarEvents: upcoming.events
  function refreshUpcoming() {
    upcoming.sourceList=mail.calendarController.sourceList
    upcoming.sourcesLoaded=mail.calendarController.sourcesLoaded
    if(!calendarEnabled || !mail.backend.ready || !upcoming.sourcesLoaded)return
    var range=Preview.previewRange(Date.now());upcoming.refresh(range[0],range[1])
  }
  CalendarNative.CalendarController {
    id:upcoming
    service:mail;pluginDir:mail.pluginDir;cacheName:"dashboard-calendar-summary"
    accountId:""
    sourceList:mail.calendarController.sourceList
    sourcesLoaded:mail.calendarController.sourcesLoaded
    onSourcesLoadedChanged:Qt.callLater(root.refreshUpcoming)
    onEnabledSourceKeyChanged:Qt.callLater(root.refreshUpcoming)
  }
  Connections {target:mail.calendarController;function onEventCreated(ok,error){if(ok)Qt.callLater(root.refreshUpcoming)} function onEventWritingChanged(){if(!mail.calendarController.eventWriting)Qt.callLater(root.refreshUpcoming)} function onSourceListChanged(){Qt.callLater(root.refreshUpcoming)} function onSourcesLoadedChanged(){Qt.callLater(root.refreshUpcoming)}}
  Connections {target:mail.backend;function onReadyChanged(){Qt.callLater(root.refreshUpcoming)}}
  Timer {interval:300000;running:root.calendarEnabled;repeat:true;triggeredOnStart:true;onTriggered:root.refreshUpcoming()}
  onCalendarEnabledChanged:if(calendarEnabled)Qt.callLater(refreshUpcoming)
  property var dialogWindow: null
  property var fileCallback: null
  signal openRequested(string accountId, string messageId)
  signal calendarOpenRequested(string eventId,double eventStart)
  property int configWritesInFlight:0
  property bool preferencesLoaded:false
  property var pendingPreferences:null
  property bool preferenceWriteRunning:false
  property string preferencesError:""
  function savePreferences(value) {
    preferencesLoaded=true
    pendingPreferences=JSON.stringify(value,null,2)
    writePreferences()
  }
  function writePreferences() {
    if(preferenceWriteRunning || pendingPreferences===null)return
    var payload=pendingPreferences;pendingPreferences=null;preferenceWriteRunning=true
    host.writeConfig("dashboard.json",payload,function(ok,error){
      root.preferenceWriteRunning=false;root.preferencesError=ok?"":error
      if(root.pendingPreferences!==null)root.writePreferences()
    })
  }
  property var preferenceFlushCallback:null
  property int preferenceFlushTicks:0
  function flushPreferences(done) {
    if(!preferenceWriteRunning && pendingPreferences===null && configWritesInFlight===0){done(!preferencesError);return}
    preferenceFlushCallback=done;preferenceFlushTicks=0;preferenceFlushTimer.start()
  }
  Timer {
    id:preferenceFlushTimer
    interval:100;repeat:true
    onTriggered:{
      root.preferenceFlushTicks++
      if((!root.preferenceWriteRunning && root.pendingPreferences===null && root.configWritesInFlight===0) || root.preferenceFlushTicks>=50){
        stop();var done=root.preferenceFlushCallback;root.preferenceFlushCallback=null
        if(done)done(!root.preferenceWriteRunning && root.pendingPreferences===null && root.configWritesInFlight===0 && !root.preferencesError)
      }
    }
  }
  FileView {
    path:root.home+"/.config/starlink-dashboard/mail/omamail/dashboard.json"
    printErrors:false
    onLoaded:{if(root.preferencesLoaded)return;try {var saved=JSON.parse(text());mail.applySettings(Object.assign({},mail.settings,saved))}catch(error){root.preferencesError="Could not read account preferences"}root.preferencesLoaded=true}
    onLoadFailed:root.preferencesLoaded=true
  }
  Omamail.Service {
    id: mail
    // Use the displayed message owner, including unified mailbox selections.
    function showMessageImages(){if(mail.reading)mail.reading.showRemoteImages()}
    // The v0.11.1 UI release deliberately pins backend 0.11.0, API 7.
    manifest: ({id:"starlink-dashboard-mail",name:"StarMail",version:"0.11.0"})
    notificationHandler:function(accountId,messageId,title,body){if(root.emailEnabled)mailNotifications.notify(accountId,messageId,title,body)}
    platform: host
    shell: host
    windowOpen: root.windowOpen
    initialSettings: ({unifiedCalendarView:true,notifyNewMail:"Off",calendarRemindersEnabled:false,suggestEvents:false,showBarIcon:false,oauthPort:9482})
    Component.onCompleted: {
      // Preserve the upstream release's explicit guard for unreleased M365 API 8.
      backendRuntime.latestApiVersion=8
      backendRuntime.unreleasedMethods=["m365.signInBegin","m365.signInPoll","m365.signOut","m365.verify","m365.list","m365.messages","m365.read","m365.attachment","m365.modify","m365.trash","m365.untrash","m365.send","m365.saveDraft","m365.deleteDraft","m365.sendAs","m365.invalidate","m365.cancel"]
    }
  }
  MailNotifications {
    id:mailNotifications
    onActivated:function(accountId,messageId){if(mail.findAccount(accountId))mail.openNotification(accountId,messageId)}
  }
  QtObject {
    id: host
    readonly property bool standalone: true
    readonly property string backendPath: String(Qt.resolvedUrl("scripts/mail-backend")).replace(/^file:\/\//,"")
    readonly property var capabilities: ({agent:false,tray:false,mailto:false,notifications:true,appearance:false})
    readonly property bool hasNotifications: true
    readonly property string notificationError:mailNotifications.error
    readonly property string calendarPalettePath:root.home+"/.local/state/omarchy/current/theme/colors.toml"
    function configPath(name) { return root.home+"/.config/starlink-dashboard/mail/omamail/"+name }
    function cachePath(name) { return root.home+"/.cache/starlink-dashboard/mail/omamail/"+name }
    function openExternal(url) { Quickshell.execDetached(["xdg-open",String(url)]);return true }
    function setClipboard(text) { clipboard.text=text; clipboard.selectAll(); clipboard.copy(); return true }
    function chooseFiles(callback) {
      if(root.fileCallback) {callback({ok:false,error:"A file picker is already open"});return false}
      root.fileCallback=callback;attachmentPicker.open();return true
    }
    function writeConfig(name,text,callback) {
      if(["credentials.json","window.json","calendars.json","dashboard.json"].indexOf(name)<0) { if(callback)callback(false,"Invalid preference file");return false }
      root.configWritesInFlight++
      var writer=writerComponent.createObject(root,{payload:JSON.stringify({name:name,text:text}),done:callback})
      writer.running=true
      return true
    }
    function updateEntryInline(pluginId,entry) {root.savePreferences(entry);return true}
    function summon(pluginId,payload) {
      try { var value=JSON.parse(payload); if(value.view==="calendar"){root.calendarOpenRequested(String(value.eventId || ""),Number(value.eventStart)||0);return true} root.openRequested(value.accountId || "",value.messageId || "");return true } catch(error) {return false}
    }
  }
  FileDialog {
    id:attachmentPicker
    title:"Choose attachments"
    parentWindow:root.dialogWindow
    fileMode:FileDialog.OpenFiles
    onAccepted: {
      var paths=[]
      for(var i=0;i<selectedFiles.length;i++) {
        var uri=String(selectedFiles[i])
        if(uri.indexOf("file:///")===0)paths.push(decodeURIComponent(uri.slice(7)))
      }
      var callback=root.fileCallback;root.fileCallback=null
      if(callback)callback({ok:true,paths:paths})
    }
    onRejected:{var callback=root.fileCallback;root.fileCallback=null;if(callback)callback({ok:false,error:"cancelled"})}
  }
  TextEdit { id: clipboard; visible: false }
  Component {
    id: writerComponent
    Process {
      id: writer
      property string payload
      property var done
      property bool completed: false
      function finish(ok,error) {
        if(completed)return
        completed=true;root.configWritesInFlight--
        if(done)done(ok,error)
      }
      command: ["/usr/bin/python3",String(Qt.resolvedUrl("scripts/mail_store.py")).replace(/^file:\/\//,"")]
      stdinEnabled: true
      onStarted: { write(payload); stdinEnabled=false }
      stdout: StdioCollector {
        onStreamFinished: {
          var result=({ok:false,error:"Could not save mail preferences"})
          try {result=JSON.parse(text)} catch(error) {}
          writer.finish(result.ok,result.error || "")
        }
      }
      onExited: { if(!completed)finish(false,"Could not save mail preferences"); destroy() }
    }
  }
}
