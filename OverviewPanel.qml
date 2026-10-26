import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Config.js" as Config
import "Weather.js" as Weather
import "Overview.js" as Overview

GridLayout {
  id:root
  objectName:"liveOverview"
  property var options:Config.overview({})
  property var enabledModules:[]
  property var weather:({})
  property string weatherStatus:"Loading weather…"
  property string calendarStatus:""
  property var events:[]
  property var notes:[]
  property var messages:[]
  property int unreadCount:0
  property bool mailConnected:false
  property double now:Date.now()
  property string dateFormat:"MMM d, yyyy"
  property string timeFormat:"h:mm AP"
  property color fg
  property color bg
  property color accent
  property color muted
  property color edge
  property real textScale:1
  readonly property var sections:options.order.filter(function(key){return options.hidden.indexOf(key)<0 && enabledModules.indexOf(key)>=0})
  readonly property var today:Overview.eventsToday(events,now)
  readonly property var next:Overview.nextEvent(events,now)
  signal moduleRequested(string key)
  signal eventRequested(var event)
  signal noteRequested(int index)
  signal mailRequested(string accountId,string messageId)
  columns:width>=520*textScale?2:1
  columnSpacing:12;rowSpacing:12
  function eventTime(event) {return Qt.formatDateTime(new Date(Number(event.start.ms)),event.start.allDay ? root.dateFormat+" · 'All day'" : root.dateFormat+" · "+root.timeFormat)}
  function rows(key) {
    if(key==="calendar")return today.filter(function(event){return Number(event.end?event.end.ms:event.start.ms)>root.now}).slice(0,4).map(function(event){return {title:event.summary || "Untitled event",detail:root.eventTime(event),event:event}})
    if(key==="notes")return notes.map(function(note){return {title:note.title,detail:note.firstLine || "Empty note",index:note.noteIndex}})
    if(key==="email")return messages.map(function(message){return {title:message.subject || "(No subject)",detail:message.from?message.from.display:"",accountId:message.accountId,messageId:message.id}})
    return (weather.alerts && weather.alerts.items || []).slice(0,3).map(function(alert){return {title:"⚠ "+alert.title,detail:alert.headline || "Open Weather for details"}})
  }
  Repeater {
    model:root.sections
    delegate:Rectangle {
      id:card
      required property string modelData
      objectName:"overviewCard_"+modelData
      Layout.fillWidth:true;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop
      implicitHeight:content.implicitHeight+28
      radius:10;color:"transparent";border.color:root.edge
      ColumnLayout {
        id:content
        anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:14;spacing:8
        AbstractButton {
          id:header
          objectName:"overviewOpen_"+card.modelData
          Layout.fillWidth:true;implicitHeight:30;hoverEnabled:true
          Accessible.name:"Open "+card.modelData
          onClicked:root.moduleRequested(card.modelData)
          contentItem:Label {text:card.modelData.charAt(0).toUpperCase()+card.modelData.slice(1)+"  ↗";color:root.accent;font.pixelSize:14*root.textScale;font.bold:true;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter}
          background:Rectangle {radius:6;color:header.hovered?Qt.rgba(root.accent.r,root.accent.g,root.accent.b,.15):"transparent"}
        }
        Label {
          Layout.fillWidth:true;wrapMode:Text.Wrap;color:root.fg;font.pixelSize:12*root.textScale;textFormat:Text.PlainText
          text:card.modelData==="weather" ? (root.weather.current ? Weather.number(root.weather.current.temperature)+((root.weather.units || {}).temperature || "°")+" · "+Weather.condition(root.weather.current.code)+"\n"+(root.weather.location || "")+"\nRain chance "+Weather.number(root.weather.current.probability)+"%" : root.weatherStatus) : card.modelData==="calendar" ? (root.calendarStatus || root.today.length+" event(s) today") : card.modelData==="email" ? (root.mailConnected?root.unreadCount+" unread messages":"Open Email to connect an account") : root.notes.length+" recent notes"
        }
        AbstractButton {
          id:nextEventButton
          visible:card.modelData==="calendar" && !!root.next
          objectName:card.modelData==="calendar"?"overviewNextEvent":""
          Layout.fillWidth:true;implicitHeight:nextText.implicitHeight+8
          onClicked:root.eventRequested(root.next)
          contentItem:Label {id:nextText;text:root.next?"Next: "+(root.next.summary || "Untitled event")+"\n"+root.eventTime(root.next):"";textFormat:Text.PlainText;color:root.accent;font.pixelSize:12*root.textScale;wrapMode:Text.Wrap}
        }
        Repeater {
          model:root.rows(card.modelData)
          delegate:AbstractButton {
            id:row
            required property var modelData
            required property int index
            objectName:"overviewRow_"+card.modelData+"_"+index
            Layout.fillWidth:true;implicitHeight:rowContent.implicitHeight+10;hoverEnabled:true
            onClicked:{if(card.modelData==="calendar")root.eventRequested(modelData.event);else if(card.modelData==="notes")root.noteRequested(modelData.index);else if(card.modelData==="email")root.mailRequested(modelData.accountId || "",modelData.messageId);else root.moduleRequested("weather")}
            background:Rectangle {radius:6;color:row.hovered?Qt.rgba(root.accent.r,root.accent.g,root.accent.b,.15):"transparent"}
            contentItem:ColumnLayout {
              id:rowContent;spacing:3
              Label {text:row.modelData.title;textFormat:Text.PlainText;color:root.accent;font.pixelSize:12*root.textScale;wrapMode:Text.Wrap;Layout.fillWidth:true;maximumLineCount:2;elide:Text.ElideRight}
              Label {text:row.modelData.detail;textFormat:Text.PlainText;color:root.muted;font.pixelSize:11*root.textScale;wrapMode:Text.Wrap;Layout.fillWidth:true;maximumLineCount:2;elide:Text.ElideRight}
            }
          }
        }
        Label {
          Layout.fillWidth:true;wrapMode:Text.Wrap;color:root.muted;font.pixelSize:11*root.textScale
          visible:!root.rows(card.modelData).length
          text:card.modelData==="calendar"?"No more events today." : card.modelData==="notes"?"Create your first note in Notes." : card.modelData==="email"?"No recent unread messages." : root.weather.alerts?(root.weather.alerts.error || "No active weather alerts."):"Checking alerts…"
        }
      }
    }
  }
  Label {visible:!root.sections.length;Layout.fillWidth:true;text:"Choose summaries in Settings → Overview. Only enabled modules appear here.";color:root.muted;wrapMode:Text.Wrap}
}
