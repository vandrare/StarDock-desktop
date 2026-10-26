import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "vendor/omamail/ui/components" as CalendarUi
import "vendor/omamail/ui/calendar/Calendar.js" as Calendar
import "vendor/omamail/ui/backend/Plain.js" as Plain
import "CalendarPreferences.js" as Preferences

Item {
  id: root
  objectName: "calendarPanel"
  signal accountsRequested()
  property var service: null
  readonly property var preferences:Preferences.normalize(service?service.settings:{})
  readonly property string defaultView:preferences.calendarDefaultView
  onDefaultViewChanged:calendarView.setView(defaultView)
  Component.onCompleted:calendarView.setView(defaultView)
  function openEventId(id,startMs){calendarView.showEvent(id,startMs)}
  readonly property var controller: service ? service.calendarController : null
  property Component heading
  property color bg
  property color fg
  property color accent
  property color muted
  property color edge
  property string fontFamily
  property real textScale: 1
  property bool choosingProvider: true
  readonly property bool connectionsOpen:connections.opened
  function closeConnections(){connections.close()}
  function openEvent(event) { calendarView.showEvent(Calendar.eventKey(event),Number(event.start.ms)) }
  function setup(index) {
    if(!service)return
    choosingProvider=index<0
    if(index>=0)service.activeIndex=index
    accountDialog.open()
  }
  component CalendarButton: AppButton {
    id: button
    palette.buttonText: checked ? root.accent : root.fg
    background: Rectangle { implicitWidth:100;implicitHeight:40;radius:6; color:button.checked || button.hovered ? Qt.rgba(root.accent.r,root.accent.g,root.accent.b,.15) : root.bg; border.color:button.activeFocus ? root.accent : "transparent" }
  }
  readonly property bool needsExitReview:eventComposer.opened && !eventComposer.pristine || !!controller && (controller.eventWriting || controller.creatingEvent)
  property var leaveCallback:null
  function requestLeave(done) {
    if(controller && (controller.eventWriting || controller.creatingEvent)) {
      controller.lastError="Wait for the calendar change to finish before closing or disabling Calendar."
      done(false);return
    }
    if(!eventComposer.opened || eventComposer.pristine){done(true);return}
    if(leaveCallback){done(false);return}
    leaveCallback=done;discardDialog.open()
  }
  function finishLeave(discard) {
    discardDialog.close()
    var done=leaveCallback;leaveCallback=null
    if(discard)eventComposer.close()
    if(done)done(discard)
  }
  function requestDelete(sourceId,event) {
    if(controller && !controller.eventWriting)deleteDialog.openFor(controller.deleteRequest(sourceId,Plain.plain(event)))
  }
  Shortcut {
    sequence:"Escape";enabled:root.visible && eventComposer.opened
    onActivated:root.requestLeave(function(ok){if(ok)eventComposer.close()})
  }
  CalendarUi.CalendarEventComposer {
    id:eventComposer
    objectName:"calendarEventComposer"
    anchors.fill:parent;z:30;visible:opened
    controller:root.controller
    defaultDurationMinutes:root.preferences.calendarDuration
    defaultTimeZone:root.preferences.calendarTimeZone
    textColor:root.fg;backgroundColor:root.bg;accentColor:root.accent;urgentColor:root.accent;dimColor:root.muted;panelFontFamily:root.fontFamily
  }
  CalendarUi.ConfirmDeleteDialog {
    id:deleteDialog
    objectName:"calendarDeleteConfirmation"
    textColor:root.fg;dimColor:root.muted;dangerColor:root.accent;popupBackgroundColor:root.bg;popupBorderColor:root.edge;panelFontFamily:root.fontFamily
    onConfirmed:function(request){if(root.controller.confirmDelete(Plain.plain(request)))calendarView.closeDetail()}
  }
  Dialog {
    id:discardDialog
    parent:Overlay.overlay;anchors.centerIn:parent;modal:true
    title:"Unsaved calendar event";width:Math.min(440,parent.width-32)
    closePolicy:Popup.NoAutoClose
    background:Rectangle {color:root.bg;border.color:root.edge;radius:12}
    contentItem:Label {text:"Discard this event's unsaved changes?";color:root.fg;wrapMode:Text.Wrap}
    footer:RowLayout {
      CalendarButton {text:"Keep editing";Layout.fillWidth:true;onClicked:{discardDialog.close();root.finishLeave(false)}}
      CalendarButton {text:"Discard";Layout.fillWidth:true;onClicked:{discardDialog.close();root.finishLeave(true)}}
    }
  }
  RowLayout {
    anchors.fill:parent; spacing:16
    ScrollView {
      Layout.preferredWidth:(root.width-16)*.25;Layout.fillHeight:true;Layout.minimumWidth:0
      contentWidth:availableWidth;rightPadding:24;clip:true
      ColumnLayout {
        width:parent.width;spacing:12
        Loader { sourceComponent:root.heading;Layout.fillWidth:true }
        CalendarButton { text:"Connections…";objectName:"calendarConnections";Layout.fillWidth:true;enabled:!!root.controller;onClicked:connections.open() }
        CalendarButton { text:"+ New event";objectName:"calendarNewEvent";Layout.fillWidth:true;enabled:!!root.controller && root.controller.writableSourceGroups.length>0 && !root.controller.eventWriting && !root.controller.creatingEvent;onClicked:eventComposer.begin() }
        CalendarButton { text:"Undo change";objectName:"calendarUndo";Layout.fillWidth:true;visible:!!root.controller && !!root.controller.undoChange;enabled:!!root.controller && !root.controller.eventWriting && !root.controller.creatingEvent;onClicked:root.controller.undoLastChange() }
        CalendarButton { text:"Settings…";Layout.fillWidth:true;onClicked:root.accountsRequested() }
        CalendarButton { text:"Refresh";Layout.fillWidth:true;enabled:!!root.controller && !root.controller.loading;onClicked:calendarView.refresh() }
        Label { text:"CALENDARS";color:root.muted;font.pixelSize:10*root.textScale }
        Repeater {
          model:root.controller ? root.controller.availableSources.sources : []
          delegate:CheckBox {
            id:sourceToggle
            required property var modelData
            Layout.fillWidth:true
            text:modelData.name || "Calendar";checked:modelData.enabled!==false
            palette.windowText:root.fg;palette.text:root.fg;palette.highlight:root.accent
            contentItem:Label { text:sourceToggle.text;textFormat:Text.PlainText;color:root.fg;leftPadding:sourceToggle.indicator.width+8;wrapMode:Text.Wrap;verticalAlignment:Text.AlignVCenter }
            onToggled:root.controller.setSourceEnabled(modelData.id,checked)
          }
        }
        Label { Layout.fillWidth:true;text:root.controller && root.controller.noCalendars ? "Open Connections to enable calendars from a compatible account or add a CalDAV source." : "Create events, open an event to edit or delete it, or drag it to reschedule. Availability depends on the calendar provider.";color:root.muted;font.pixelSize:11*root.textScale;wrapMode:Text.Wrap }
      }
    }
    CalendarUi.CalendarView {
      id:calendarView
      objectName:"nativeCalendarView"
      Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumWidth:0
      controller:root.controller
      weekStart:root.preferences.calendarWeekStart
      timeFormat:root.preferences.calendarTimeFormat==="24"?"HH:mm":"h:mm AP"
      dateFormat:root.preferences.calendarDateFormat
      textColor:root.fg;backgroundColor:root.bg;accentColor:root.accent;urgentColor:root.accent;dimColor:root.muted
      calendarBorderColor:root.edge;calendarTodayBackgroundColor:Qt.rgba(root.accent.r,root.accent.g,root.accent.b,.15)
      calendarBorderWidth:1;panelFontFamily:root.fontFamily
      onCopyRequested:function(text){root.controller.copyText(text)}
      onOpenRequested:function(url){root.controller.openExternal(url)}
      onCreateAt:function(startMs){eventComposer.beginAt(startMs)}
      onEditRequested:function(sourceId,event){eventComposer.beginEdit(sourceId,Plain.plain(event))}
      onDeleteRequested:function(sourceId,event){root.requestDelete(sourceId,event)}
    }
  }
  Dialog {
    id:connections
    objectName:"calendarConnectionsDialog"
    parent:Overlay.overlay;anchors.centerIn:parent;modal:true
    title:"Calendar connections";padding:24
    width:Math.min(parent.width-32,780);height:Math.min(parent.height-32,760)
    palette.windowText:root.fg;palette.text:root.fg;palette.buttonText:root.fg;palette.highlight:root.accent;palette.base:root.bg
    background:Rectangle {color:root.bg;border.color:root.edge;radius:12}
    contentItem:ScrollView {
      id:connectionScroll
      clip:true;rightPadding:24;contentWidth:availableWidth
      CalendarUi.CalendarSettings {
        width:connectionScroll.availableWidth
        service:root.service;controller:root.controller
        textColor:root.fg;dimColor:root.muted;accentColor:root.accent;urgentColor:root.accent;panelFontFamily:root.fontFamily
        onAccountSetupRequested:function(index){root.setup(index)}
        onAddAccountRequested:root.setup(-1)
        onClientSetupRequested:root.accountsRequested()
        onOpenCalendarRequested:connections.close()
      }
    }
    footer:CalendarButton {text:"Done";onClicked:connections.close()}
  }
  CalendarUi.SetupPages {
    id:setupPages
    service:root.service;textColor:root.fg;dimColor:root.muted;accentColor:root.accent;dangerColor:root.accent;panelFontFamily:root.fontFamily
    onChosen:function(providerId){
      if(providerId==="m365" && root.service.backend.apiVersion<8){setupNotice.open();return}
      root.service.addAccount(providerId);root.choosingProvider=false
    }
    onRemoveRequested:setupNotice.open()
  }
  Dialog {
    id:accountDialog
    parent:Overlay.overlay;anchors.centerIn:parent;modal:true
    title:"Calendar account";padding:24
    width:Math.min(parent.width-32,760);height:Math.min(parent.height-32,760)
    palette.windowText:root.fg;palette.text:root.fg;palette.buttonText:root.fg;palette.highlight:root.accent;palette.base:root.bg
    background:Rectangle {color:root.bg;border.color:root.edge;radius:12}
    contentItem:ScrollView {
      id:accountScroll
      clip:true;rightPadding:24;contentWidth:availableWidth
      Loader {width:accountScroll.availableWidth;sourceComponent:setupPages.pageFor(root.service ? root.service.providerId : "gmail",root.choosingProvider)}
    }
    footer:CalendarButton {text:"Done";onClicked:accountDialog.close()}
    onClosed:if(root.service)root.service.discardCurrentDraft()
  }
  Dialog {
    id:setupNotice
    parent:Overlay.overlay;anchors.centerIn:parent;modal:true
    title:"Account setup"
    width:Math.min(468,root.width-32)
    height:230
    background:Rectangle {color:root.bg;border.color:root.edge;radius:12}
    contentItem:Label {width:Math.min(420,root.width-32);text:"Use a supported Google, Outlook personal, iCloud or CalDAV connection. Microsoft 365 requires a newer backend. Mail account removal and OAuth client settings will be added with account settings.";wrapMode:Text.Wrap;color:root.fg}
    footer:CalendarButton {text:"Close";onClicked:setupNotice.close()}
  }
}
