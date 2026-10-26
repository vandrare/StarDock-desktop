import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell.Io
import "CalendarPreferences.js" as Preferences

ColumnLayout {
  id:root
  property var service:null
  property color fg
  property string saveError:""
  property color muted
  property var zones:[""]
  signal accountsRequested()
  function load() {
    var p=Preferences.normalize(service ? service.settings : {})
    view.currentIndex=Preferences.views.indexOf(p.calendarDefaultView)
    week.currentIndex=p.calendarWeekStart===0?1:0
    duration.value=p.calendarDuration
    zone.currentIndex=Math.max(0,zones.indexOf(p.calendarTimeZone))
    hours.currentIndex=p.calendarTimeFormat==="24"?1:0
    date.currentIndex=Preferences.dates.indexOf(p.calendarDateFormat)
    reminders.checked=p.calendarRemindersEnabled;snooze.value=p.calendarSnoozeMinutes
  }
  function save() {
    if(!service)return
    var values=Object.assign({},service.settings,{calendarDefaultView:Preferences.views[view.currentIndex],calendarWeekStart:week.currentIndex===1?0:1,calendarDuration:duration.value,calendarTimeZone:zones[zone.currentIndex] || "",calendarTimeFormat:hours.currentIndex===1?"24":"12",calendarDisplayTimePattern:hours.currentIndex===1?"HH:mm":"h:mm AP",calendarDateFormat:Preferences.dates[date.currentIndex],calendarRemindersEnabled:reminders.checked,calendarSnoozeMinutes:snooze.value})
    service.applySettings(values)
    service.shell.updateEntryInline(service.pluginId,values)
  }
  Component.onCompleted:load()
  Label {visible:!!root.saveError;text:root.saveError;color:root.fg;wrapMode:Text.Wrap;Layout.fillWidth:true}
  Label {text:"Default view";color:root.fg}
  ComboBox {id:view;objectName:"calendarDefaultView";model:["Month","Week","Day","Agenda"];Layout.fillWidth:true}
  Label {text:"First day of the week";color:root.fg}
  ComboBox {id:week;objectName:"calendarWeekStart";model:["Monday","Sunday"];Layout.fillWidth:true}
  Label {text:"Default event duration (minutes)";color:root.fg}
  SpinBox {id:duration;objectName:"calendarDuration";from:5;to:1440;stepSize:5;editable:true}
  Label {text:"New Google event time zone";color:root.fg}
  ComboBox {id:zone;model:root.zones.map(function(value){return value || "Calendar default / system local"});Layout.fillWidth:true}
  Label {text:"The calendar grid and entered times use your desktop time zone. This default supplies the event's time-zone metadata, including Google recurrence rules.";color:root.muted;wrapMode:Text.Wrap;Layout.fillWidth:true;font.pixelSize:11}
  Label {text:"Calendar time format";color:root.fg}
  ComboBox {id:hours;model:["12 hour","24 hour"];Layout.fillWidth:true}
  Label {text:"Calendar date format";color:root.fg}
  ComboBox {id:date;model:Preferences.dates;Layout.fillWidth:true}
  Switch {id:reminders;objectName:"calendarRemindersEnabled";text:"Desktop reminders";palette.windowText:root.fg}
  Label {text:"Snooze length (minutes)";color:root.fg}
  SpinBox {id:snooze;from:1;to:1440;editable:true}
  Label {text:"Reminders run while the dashboard is open. Choose reminder timing, default calendars, colors and visibility under Accounts & calendars. Reminders require a Google Calendar source in this StarMail release.";color:root.muted;wrapMode:Text.Wrap;Layout.fillWidth:true;font.pixelSize:11}
  AppButton {text:"Accounts & calendars…";Layout.fillWidth:true;onClicked:root.accountsRequested()}
  Process {
    command:["/usr/bin/python3","-c","import json,zoneinfo; print(json.dumps(sorted(zoneinfo.available_timezones())))"]
    running:true
    stdout:StdioCollector {onStreamFinished:{try {root.zones=[""].concat(JSON.parse(text));root.load()}catch(error){}}}
  }
}
