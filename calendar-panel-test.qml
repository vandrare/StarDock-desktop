import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import "vendor/omamail/ui/calendar" as NativeCalendar
import "vendor/omamail/ui/calendar/Calendar.js" as Calendar
import "vendor/omamail/ui/calendar/Sources.js" as Sources
ShellRoot {
  id:root
  property int beforeDelete:0
  property string leaveResult:"pending"
  QtObject {
    id:fixtureService
    property var calendarController:controller
    property var accountSummaries:[]
    property bool backendCanDiscoverCalendars:true
    property bool backendCanGoogleCalendars:true
    property string calendarPalettePath:""
    property var calendarReminderInbox:reminderInbox
    property var settings:({})
    property string pluginId:"fixture"
    property var shell:({updateEntryInline:function(id,entry){fixtureService.savedSettings=entry},summon:function(id,payload){fixtureService.lastSummon=JSON.parse(payload)}})
    property var savedSettings:null
    property var lastSummon:null
    property var lastReminder:null
    property bool reminderFailure:false
    property var backend:({call:function(method,params,done){fixtureService.lastReminder=params;Qt.callLater(function(){done({},fixtureService.reminderFailure?"Synthetic failure":null)})}})
    function applySettings(value){settings=value}
    property int calendarSnoozeMinutes:10
    property bool calendarRemindersEnabled:false
    property string calendarReminderError:""
    property bool unifiedCalendarView:true
    property string providerId:"gmail"
    property int activeIndex:-1
    property var recipientContacts:[]
    function refreshRecipientContacts(){}
    function setUnifiedCalendarView(value){unifiedCalendarView=value}
    function persistSetting(key,value){}
    function discardCurrentDraft(){}
  }
  QtObject {
    id:controller
    property var service:fixtureService
    property bool sourcesLoaded:true
    property bool loading:false
    property string lastError:""
    property string lastErrorKind:""
    property bool clockRunning:false
    property double nowMs:Date.now()
    property var events:[{uid:"synthetic",sourceId:"fixture",summary:"Synthetic calendar event",description:"Fixture details only",start:{ms:Date.now()+3600000,allDay:false},end:{ms:Date.now()+7200000,allDay:false},href:"https://example.test/cal/event.ics"}]
    property var availableSources:({sources:[{id:"fixture",name:"Synthetic calendar",kind:"caldav",url:"https://example.test/cal/",readOnly:false,enabled:true,colorKey:"accent"}]})
    signal calendarSaved(bool ok,string error)
    signal discoveryFinished(bool ok,string error,int count)
    property bool noCalendars:false
    property string accountId:""
    property bool composerHeld:false
    property bool creatingEvent:false
    property bool eventWriting:false
    property var undoChange:null
    property var writableSourceGroups:Sources.writableGroups(Sources.groupByAccount(availableSources,[]))
    property var lastWrite:null
    property bool failWrites:false
    signal composeRequested(var prefill)
    signal composeEnded()
    signal eventCreated(bool ok,string error)
    signal eventUpdated(bool ok,string error)
    signal eventDeleted(bool ok,string error)
    function rescheduleRefusal(event){return Calendar.writeRefusal(findSource(event.sourceId),event,"reschedule")}
    function createEvent(id,fields){
      var built=Calendar.createEvent(fields,Date.now())
      var error=Calendar.writeRefusal(findSource(id),null) || (!built.ok ? built.error : "")
      if(error){eventCreated(false,error);return false}
      lastWrite={operation:"create",sourceId:id,fields:fields};writeCount++
      Qt.callLater(function(){eventCreated(!failWrites,failWrites?"Synthetic write failure":"")});return true
    }
    function updateEvent(id,event,fields){
      lastWrite={operation:"update",sourceId:id,event:event,fields:fields};writeCount++
      Qt.callLater(function(){eventUpdated(!failWrites,failWrites?"Synthetic write failure":"")});return true
    }
    function deleteRequest(id,event){return Object.assign(Calendar.deleteRequest(event,findSource(id),true),{sourceId:id,event:event})}
    function confirmDelete(request){lastWrite={operation:"delete",request:request};writeCount++;Qt.callLater(function(){eventDeleted(true,"")});return true}
    function undoLastChange(){lastWrite={operation:"undo"};undoChange=null;return true}
    property int writeCount:0
    function nativeRequest(source,operation,fields,callback){writeCount++;callback({},null)}
    property int refreshCount:0
    function refresh(start,end){refreshCount++}
    function findSource(id){return availableSources.sources[0]}
    function colorKeyFor(id){return "accent"}
    function setSourceEnabled(id,value){}
    function copyText(text){return true}
    function openExternal(url){return true}
  }
  NativeCalendar.CalendarReminderInbox {id:reminderInbox;service:fixtureService}
  FloatingWindow {
    title:"Starlink Calendar Integration Test"
    implicitWidth:1320;implicitHeight:850;color:"#071426"
    CalendarPanel {id:panel;anchors.fill:parent;anchors.margins:24;service:fixtureService;bg:"#071426";fg:"#c8d9e9";accent:"#6cb6ff";muted:"#8099aa";edge:"#304050";fontFamily:"JetBrainsMono Nerd Font"}
    ScrollView {id:preferenceScroll;anchors.fill:parent;anchors.margins:24;visible:false;clip:true;rightPadding:24;contentWidth:availableWidth
      CalendarPreferences {id:preferenceOptions;width:preferenceScroll.availableWidth;service:fixtureService;fg:"#c8d9e9";muted:"#8099aa"}
    }
  }
  function find(item,name) {if(item.objectName===name)return item;var children=item.children || [];for(var i=0;i<children.length;i++){var found=find(children[i],name);if(found)return found}return null}
  IpcHandler {
    target:"calendartest"
    function view(mode:string):string {var view=find(panel,"nativeCalendarView");view.setView(mode);if(view.viewMode!==mode)return "FAIL: mode";return "PASS: "+mode}
    function details():string {panel.openEvent(controller.events[0]);return "PASS: requested details"}
    function verify():string {var view=find(panel,"nativeCalendarView");if(!view.detailOpen)return "FAIL: no details";return "PASS: event details"}
    function newEvent():string {find(panel,"calendarNewEvent").clicked();var editor=find(panel,"calendarEventComposer");if(!editor.opened || editor.selectedSourceId!=="fixture")return "FAIL: new event";return "PASS: new event"}
    function invalidDate():string {var editor=find(panel,"calendarEventComposer");var before=controller.writeCount;find(editor,"event-start-date-field").text="invalid";editor.submit("all");if(controller.writeCount!==before)return "FAIL: invalid dates written";editor.begin();return "PASS: invalid dates refused"}
    function recurrence():string {var editor=find(panel,"calendarEventComposer");editor.recurring=true;editor.recurrenceFrequency="WEEKLY";return "PASS: recurrence prepared"}
    function verifyAllDay():string {if(!controller.lastWrite.fields.allDay || !controller.lastWrite.fields.recurrence.enabled)return "FAIL: all-day recurrence lost";return "PASS: all-day recurrence preserved"}
    function prepare(allDay:bool):string {var editor=find(panel,"calendarEventComposer");find(editor,"event-title-field").text="Synthetic new event";find(editor,"event-location-field").text="Test room";find(editor,"event-description-field").text="First line\nSecond line";editor.allDay=allDay;return "PASS: prepared"}
    function save(fail:bool):string {controller.failWrites=fail;find(find(panel,"calendarEventComposer"),"event-save-button").clicked();return "PASS: save requested"}
    function verifySave(fail:bool):string {var editor=find(panel,"calendarEventComposer");if(editor.opened!==fail)return "FAIL: editor completion state";if(!controller.lastWrite || controller.lastWrite.fields.title!=="Synthetic new event" || controller.lastWrite.sourceId!=="fixture")return "FAIL: write routing";if(fail && find(editor,"event-save-error").text!=="Synthetic write failure")return "FAIL: error missing";return "PASS: write completion"}
    function edit():string {find(panel,"nativeCalendarView").editRequested("fixture",controller.events[0]);var editor=find(panel,"calendarEventComposer");if(!editor.editing || editor.titleText()!=="Synthetic calendar event")return "FAIL: edit";find(editor,"event-title-field").text="Synthetic new event";return "PASS: edit"}
    function verifyUpdate():string {if(controller.lastWrite.operation!=="update" || controller.lastWrite.event.uid!=="synthetic")return "FAIL: update identity";return "PASS: update"}
    function deleteEvent():string {root.beforeDelete=controller.writeCount;find(panel,"nativeCalendarView").deleteRequested("fixture",controller.events[0]);return "PASS: delete requested"}
    function verifyDeletePrompt():string {var dialog=find(panel,"calendarDeleteConfirmation");if(!dialog.opened || controller.writeCount!==root.beforeDelete)return "FAIL: deletion before confirmation";dialog.close();return "PASS: cancel did not write"}
    function confirmDelete():string {find(panel,"calendarDeleteConfirmation").confirm();if(controller.lastWrite.operation!=="delete")return "FAIL: delete not routed";return "PASS: confirmed delete"}
    function undo():string {controller.undoChange={};find(panel,"calendarUndo").clicked();return controller.lastWrite.operation==="undo"?"PASS: undo":"FAIL: undo"}
    function reschedule():string {
      var source=controller.availableSources.sources[0]
      controller.availableSources={sources:[Object.assign({},source,{kind:"google"})]}
      var event=Object.assign({},controller.events[0],{googleId:"synthetic-google"})
      var start=event.start.ms+86400000,end=event.end.ms+86400000
      find(panel,"nativeCalendarView").reschedule(event,start,end)
      if(controller.lastWrite.operation!=="update" || controller.lastWrite.fields.startMs!==start || controller.lastWrite.fields.endMs!==end)return "FAIL: reschedule times"
      controller.availableSources={sources:[source]}
      return "PASS: provider-supported rescheduling"
    }
    function leaveGuard():string {
      var editor=find(panel,"calendarEventComposer")
      editor.begin();find(editor,"event-title-field").text="Keep this draft"
      root.leaveResult="pending";panel.requestLeave(function(ok){root.leaveResult=String(ok)})
      if(root.leaveResult!=="pending")return "FAIL: unsaved event discarded without decision"
      panel.finishLeave(false)
      if(root.leaveResult!=="false" || !editor.opened || editor.titleText()!=="Keep this draft")return "FAIL: draft lost"
      panel.requestLeave(function(ok){root.leaveResult=String(ok)});panel.finishLeave(true)
      if(root.leaveResult!=="true" || editor.opened)return "FAIL: discard decision"
      controller.eventWriting=true;panel.requestLeave(function(ok){root.leaveResult=String(ok)});controller.eventWriting=false
      if(root.leaveResult!=="false")return "FAIL: allowed exit during write"
      return "PASS: unsaved and in-flight guards"
    }
    function showPreferences():string {panel.visible=false;preferenceScroll.visible=true;return "PASS: showing preferences"}
    function defaultCalendar():string {
      var original=controller.availableSources
      controller.availableSources={sources:[Object.assign({},original.sources[0],{readOnly:false}),{id:"preferred",name:"Preferred fixture",kind:"caldav",preferred:true,enabled:true}]}
      var editor=find(panel,"calendarEventComposer");editor.begin()
      if(editor.selectedSourceId!=="preferred")return "FAIL: preferred manual calendar ignored"
      editor.close();controller.availableSources=original
      return "PASS: preferred manual calendar"
    }
    function preferences():string {
      fixtureService.settings={calendarDefaultView:"week",calendarWeekStart:0,calendarTimeFormat:"24",calendarDateFormat:"yyyy-MM-dd",calendarDuration:30,calendarTimeZone:"America/Phoenix"}
      var view=find(panel,"nativeCalendarView")
      if(view.weekStart!==0 || view.timeFormat!=="HH:mm" || view.dateFormat!=="yyyy-MM-dd" || view.viewMode!=="week" || new Date(view.days[0].startMs).getDay()!==0)return "FAIL: calendar display preferences"
      var editor=find(panel,"calendarEventComposer");editor.begin()
      if(editor.dateRange.endMs-editor.dateRange.startMs!==1800000 || editor.defaultTimeZone!=="America/Phoenix")return "FAIL: event defaults"
      editor.close();preferenceOptions.load();preferenceOptions.save()
      if(!fixtureService.savedSettings || fixtureService.savedSettings.calendarDuration!==30)return "FAIL: preference save"
      return "PASS: calendar preferences"
    }
    function reminder(action:string,fail:bool):string {
      fixtureService.reminderFailure=fail
      var record=reminderInbox.receive({key:"synthetic-key",title:"Synthetic reminder",start:Date.now()+60000,end:Date.now()+3600000,accountId:"fixture",sourceId:"fixture",eventId:"synthetic"})
      if(action==="open"){reminderInbox.open(record);return fixtureService.lastSummon && fixtureService.lastSummon.view==="calendar"?"PASS: reminder open":"FAIL: reminder open"}
      reminderInbox.action(record.key,action,record.noticeId)
      return "PASS: reminder action requested"
    }
    function verifyReminder(fail:bool):string {
      if((reminderInbox.records.length>0)!==fail)return "FAIL: reminder action completion"
      if(fixtureService.lastReminder.minutes!==10)return "FAIL: snooze duration"
      if(fail && !reminderInbox.lastError)return "FAIL: reminder error missing"
      return "PASS: reminder completion"
    }
    function readOnly():string {controller.availableSources={sources:[Object.assign({},controller.availableSources.sources[0],{readOnly:true})]};if(find(panel,"calendarNewEvent").enabled || controller.rescheduleRefusal(controller.events[0])==="")return "FAIL: read-only controls";var before=controller.writeCount;controller.createEvent("fixture",{title:"Forbidden",startMs:Date.now()+3600000,endMs:Date.now()+7200000});if(controller.writeCount!==before)return "FAIL: read-only write forwarded";return "PASS: read-only controls"}
    function connections():string {find(panel,"calendarConnections").clicked();return panel.connectionsOpen ? "PASS: connections" : "FAIL: connections"}
    function closeConnections():string {panel.closeConnections();return "PASS"}
  }
}
