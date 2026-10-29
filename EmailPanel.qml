import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.Commons
import "vendor/omamail/ui/components" as MailUi
import "vendor/omamail/ui/account/Model.js" as MailModel
import "vendor/omamail/ui/backend/Plain.js" as Plain

Item {
  id: root
  objectName: "emailPanel"
  signal accountsRequested()
  property var service: null
  property Component heading
  property color bg
  property color fg
  property color accent
  property color muted
  property color edge
  property string fontFamily
  property real bodyFontSize:14
  property real messageListFontSize:12
  readonly property real messageListScale:textScale*messageListFontSize/12
  property real textScale: 1
  property string dateFormat:"MMM d, yyyy"
  property string timeFormat:"h:mm AP"
  property bool choosingProvider: true
  property bool addingAccount: false
  readonly property bool connected: !!service && service.ready
  readonly property bool backendReady: !!service && service.backend.ready
  readonly property bool splitReader: width>=1000
  readonly property var messages: service ? service.messages : []
  readonly property var selected: service ? service.selectedMessage : null
  readonly property bool mailListLoading: !!service && !!service.listLoading
  function loadFirstMessage() {
    if(!visible || !connected || mailListLoading || composeShell.composing || !messages.length || service.selectedId || selected)return
    service.select(messages[0].id)
  }
  onMessagesChanged:Qt.callLater(loadFirstMessage)
  onConnectedChanged:Qt.callLater(loadFirstMessage)
  onMailListLoadingChanged:Qt.callLater(loadFirstMessage)
  onVisibleChanged:if(visible)Qt.callLater(loadFirstMessage)
  Component.onCompleted:Qt.callLater(loadFirstMessage)
  function receivedDate(message) {
    var date=new Date(message.dateMs || message.date || 0)
    return isNaN(date.getTime()) || date.getTime()<=0 ? "—" : Qt.formatDate(date,root.dateFormat)
  }
  function receivedDetails(message) {
    var date=new Date(message.dateMs || message.date || 0)
    return isNaN(date.getTime()) || date.getTime()<=0 ? "Received date unavailable" : Qt.formatDateTime(date,root.dateFormat+" · "+root.timeFormat)
  }
  component MailButton: AppButton {
    id:button
    palette.buttonText:checked ? root.accent : root.fg
    background:Rectangle {
      implicitWidth:100;implicitHeight:40;radius:6
      color:button.checked || button.hovered ? Qt.rgba(root.accent.r,root.accent.g,root.accent.b,.15) : root.bg
      border.color:button.activeFocus ? root.accent : "transparent"
    }
  }
  component MailAction: MailButton {
    id:action
    property string iconName
    property string hint
    text:""
    implicitWidth:36;implicitHeight:36
    Accessible.name:hint
    ToolTip.visible:hovered
    ToolTip.text:hint
    contentItem:MailUi.ActionIcon {name:action.iconName;filled:action.checked;iconSize:17;color:action.checked ? root.accent : root.fg;opacity:action.enabled?1:.45}
  }
  function setup(add) {
    if(!service)return
    addingAccount=add
    choosingProvider=add || !service.hasSavedAccounts
    accountSetup.open()
  }
  function chooseProvider(providerId) {
    if(providerId==="m365" && service.backend.apiVersion<8) { compatibilityNotice.open();return }
    if(!service.current || service.accountCount===0 || (service.hasSavedAccounts && addingAccount))service.addAccount(providerId)
    else service.configureCurrentAccount({provider:providerId})
    choosingProvider=false
  }
  function openMessage(id) { if(service)service.select(id) }
  function flushDrafts(done) { composeShell.flush(done) }
  function startCompose(mode) { composeShell.start(mode) }
  function messageAction(verb) {
    if(!service || !selected || !service.ready)return false
    if(verb==="star") {service.toggleStar(service.selectedId);return true}
    return service.act(service.selectedId,verb)
  }
  readonly property bool detailReady: connected && !!selected && !service.detailLoading && service.detailPainted
  readonly property string archiveAction: MailModel.keyActionFor("archive",selected ? [Plain.plain(selected)] : [],service)
  readonly property string trashAction: MailModel.keyActionFor("trash",selected ? [Plain.plain(selected)] : [],service)
  RowLayout {
    id:browsing
    anchors.fill:parent
    spacing:16
    visible:!composeShell.composing

  ColumnLayout {
    Layout.fillWidth: true; Layout.fillHeight: true
    Layout.preferredWidth: (root.width-browsing.spacing)*.25
    Layout.minimumWidth: 0
    spacing: 12
    Loader { sourceComponent: root.heading; Layout.fillWidth: true }
    ScrollView {
      id: accountsScroll
      Layout.fillWidth:true; Layout.fillHeight:true; clip:true; rightPadding:24; contentWidth:availableWidth
      ColumnLayout {
        width:accountsScroll.availableWidth
        spacing:8
        Repeater {
          model: root.service ? root.service.accountSummaries : []
          delegate: MailButton {
            required property var modelData
            required property int index
            Layout.fillWidth:true; Layout.minimumWidth:0
            text: modelData.label || modelData.email || "New account"
            checked:modelData.active
            onClicked: { root.service.switchToIndex(index); root.service.clearSelection() }
            ToolTip.visible:hovered; ToolTip.text:modelData.email || "Account setup"
          }
        }
        Rectangle { Layout.fillWidth:true; height:1; color:root.edge }
        Repeater {
          model: root.service && root.service.current ? root.service.current.mailboxes : []
          delegate: MailButton {
            required property var modelData
            Layout.fillWidth:true; Layout.minimumWidth:0
            text:modelData.label
            enabled:root.connected
            checked:root.service && root.service.current && root.service.current.mailboxKey===modelData.key
            onClicked:root.service.selectMailbox(modelData.key)
          }
        }
      }
    }
  }
  ColumnLayout {
    Layout.fillWidth:true; Layout.fillHeight:true
    Layout.preferredWidth:(root.width-browsing.spacing)*.75
    Layout.minimumWidth:0
    spacing:12
    RowLayout {
      Layout.fillWidth:true
      MailButton { text:"Back"; visible:!root.splitReader && !!root.selected; onClicked:root.service.clearSelection() }
      Label { text:root.service ? (root.service.accountEmail || "Email") : "Email"; color:root.fg; font.bold:true; font.pixelSize:14*root.textScale; Layout.fillWidth:true; elide:Text.ElideRight }
      MailAction {objectName:"mailComposeCompact";iconName:"compose";hint:"Compose…";visible:!root.splitReader && !root.selected && root.connected;enabled:root.connected && root.service.canSend;onClicked:root.startCompose("new")}
      MailAction { objectName:"mailRefresh"; iconName:"refresh";hint:"Refresh"; enabled:root.connected; onClicked:root.service.refresh() }
    }
    Label {
      visible:!root.connected
      text:!root.backendReady ? "Starting the mail backend…" : "Connect a mailbox to read your email."
      color:root.muted; wrapMode:Text.Wrap; Layout.fillWidth:true
    }
    MailButton { text:"Connect a mailbox…"; visible:!root.connected; enabled:root.backendReady; onClicked:root.setup(!root.service.hasSavedAccounts) }
    RowLayout {
      Layout.fillWidth:true; Layout.fillHeight:true; spacing:12
      ColumnLayout {
        visible:root.splitReader || !root.selected
        Layout.fillWidth:true; Layout.fillHeight:true
        Layout.preferredWidth:root.splitReader ? 35 : 1
        Layout.minimumWidth:0
        TextField {
          objectName:"mailSearch"
          Layout.fillWidth:true; enabled:root.connected
          placeholderText:"Search mail and press Enter"
          color:root.fg; selectByMouse:true
          background:Rectangle {color:root.bg; border.color:root.edge; radius:6}
          onAccepted:root.service.search(text)
        }
        ScrollView {
          id: messageScroll
          objectName:"mailMessageScroll"
          Layout.fillWidth:true; Layout.fillHeight:true; clip:true; rightPadding:24; contentWidth:availableWidth
          ListView {
            id: messageList
            objectName:"mailMessageList"
            model:root.messages
            spacing:0
            delegate: AbstractButton {
              id: messageRow
              required property var modelData
              required property int index
              objectName:"mailMessage"+index
              width:messageList.width; implicitHeight:messageText.implicitHeight+20
              hoverEnabled:true
              onClicked:root.openMessage(modelData.id)
              background:Rectangle {
                color:messageRow.hovered || (root.service && root.service.selectedId===messageRow.modelData.id) ? Qt.rgba(root.accent.r,root.accent.g,root.accent.b,.15) : "transparent"
                border.width:0
                Rectangle { objectName:"mailMessageSeparator"+messageRow.index;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:1;color:root.edge }
              }
              contentItem:ColumnLayout {
                id:messageText
                spacing:4
                RowLayout {
                  Layout.fillWidth:true
                  spacing:8
                  Label { objectName:"mailSender"+messageRow.index; text:(messageRow.modelData.unread ? "● " : "")+(messageRow.modelData.from ? messageRow.modelData.from.display : ""); textFormat:Text.PlainText; color:root.accent; font.bold:messageRow.modelData.unread; font.pixelSize:11*root.messageListScale; Layout.fillWidth:true; Layout.minimumWidth:0; elide:Text.ElideRight }
                  Label {
                    objectName:"mailReceivedDate"+messageRow.index
                    text:root.receivedDate(messageRow.modelData)
                    color:root.muted;font.pixelSize:10*root.messageListScale
                    Layout.maximumWidth:parent.width*.5
                    horizontalAlignment:Text.AlignRight;elide:Text.ElideRight
                    ToolTip.visible:dateHover.hovered
                    ToolTip.text:root.receivedDetails(messageRow.modelData)
                    HoverHandler {id:dateHover}
                  }
                }
                Label { objectName:"mailMessageTitle"+messageRow.index; text:messageRow.modelData.subject || "(No subject)"; textFormat:Text.PlainText; color:root.fg; font.bold:messageRow.modelData.unread; font.pixelSize:12*root.messageListScale; Layout.fillWidth:true; wrapMode:Text.Wrap; maximumLineCount:2; elide:Text.ElideRight }
                Label { text:messageRow.modelData.snippet || ""; textFormat:Text.PlainText; color:root.muted; font.pixelSize:10*root.messageListScale; Layout.fillWidth:true; elide:Text.ElideRight }
              }
            }
          }
        }
        Label { visible:root.connected && !root.messages.length; text:root.service && root.service.listLoading ? "Loading messages…" : "No messages in this view"; color:root.muted; Layout.fillWidth:true; wrapMode:Text.Wrap }
        MailButton { text:"Load more"; visible:!!root.service && root.service.hasMore; enabled:root.connected; onClicked:root.service.loadMore() }
      }
      ColumnLayout {
        visible:root.splitReader || !!root.selected
        Layout.fillWidth:true; Layout.fillHeight:true
        Layout.preferredWidth:root.splitReader ? 65 : 1
        Layout.minimumWidth:0
        spacing:10
        Label { text:root.selected ? root.selected.subject || "(No subject)" : "Select a message to read"; textFormat:Text.PlainText; color:root.fg; font.pixelSize:18*root.textScale; font.bold:true; Layout.fillWidth:true; wrapMode:Text.Wrap }
        RowLayout {
          Layout.fillWidth:true;spacing:8
          Label { text:root.selected && root.selected.from ? root.selected.from.display : ""; textFormat:Text.PlainText; color:root.accent; Layout.fillWidth:true; Layout.minimumWidth:0; elide:Text.ElideRight }
          Label { text:root.selected ? root.receivedDate(root.selected) : "";color:root.muted;font.pixelSize:10*root.textScale;horizontalAlignment:Text.AlignRight }
        }
        Flow {
          objectName:"mailMessageToolbar"
          Layout.fillWidth:true
          Layout.preferredHeight:childrenRect.height
          spacing:6
          visible:root.connected
          MailAction {objectName:"mailCompose";iconName:"compose";hint:"Compose…";enabled:root.connected && root.service.canSend;onClicked:root.startCompose("new")}
          MailAction {objectName:"mailTrash";iconName:root.trashAction==="untrash"?"undo":"trash";hint:root.trashAction==="untrash"?"Restore":"Delete (move to trash)";enabled:root.detailReady;onClicked:root.messageAction(root.trashAction)}
          MailAction {objectName:"mailEditDraft";iconName:"compose";hint:"Edit draft…";visible:!!root.selected && root.selected.isDraft===true;enabled:root.detailReady && root.service.canSend;onClicked:root.startCompose("draft")}
          MailAction {objectName:"mailReply";iconName:"reply";hint:"Reply…";visible:!root.selected || root.selected.isDraft!==true;enabled:root.detailReady && root.service.canSend;onClicked:root.startCompose("reply")}
          MailAction {objectName:"mailReplyAll";iconName:"replyAll";hint:"Reply all…";visible:!root.selected || root.selected.isDraft!==true;enabled:root.detailReady && root.service.canSend;onClicked:root.startCompose("replyAll")}
          MailAction {objectName:"mailForward";iconName:"forward";hint:"Forward…";enabled:root.detailReady && root.service.canSend;onClicked:root.startCompose("forward")}
          MailAction {objectName:"mailArchive";iconName:root.archiveAction==="unarchive"?"inbox":"archive";hint:MailModel.actionName(root.archiveAction);visible:!!root.service && root.service.canArchive;enabled:root.detailReady;onClicked:root.messageAction(root.archiveAction)}
          MailAction {objectName:"mailMarkRead";iconName:root.selected && root.selected.unread?"check":"unread";hint:root.selected && root.selected.unread ? "Mark read" : "Mark unread";enabled:root.detailReady;onClicked:root.messageAction(root.selected.unread?"markRead":"markUnread")}
          MailAction {objectName:"mailStar";iconName:"star";checked:!!root.selected && root.selected.starred;hint:root.selected && root.selected.starred ? "Unstar" : "Star";visible:!!root.service && root.service.canStar;enabled:root.detailReady;onClicked:root.messageAction("star")}
        }
        Label { visible:!!root.service && root.service.detailLoading; text:"Loading message…"; color:root.muted }
        MailUi.MessageReader {
          id:richReader
          objectName:"mailReader"
          visible:!!root.selected || (!!root.service && root.service.detailLoading)
          Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumWidth:0
          service:root.service
          embeddedBody:true;oneMessageImageApproval:true
          textColor:root.fg;backgroundColor:root.bg;accentColor:root.accent;linkColor:root.accent
          dimColor:root.muted;dimmerColor:root.muted;popupBackgroundColor:root.bg;popupBorderColor:root.edge
          leadingBoundaryOverlap:0;panelFontFamily:root.fontFamily
          bodyMode:root.service ? root.service.bodyMode : "reader"
          zoom:(root.service ? root.service.bodyZoom : 1)*root.textScale*root.bodyFontSize/Style.font.body
          alwaysRenderHeavyMessages:!!root.service && root.service.alwaysRenderHeavyMessages
          contentDirection:root.service ? root.service.contentDirection : "Auto"
          onBodyModeRequested:function(mode){if(root.service)root.service.setBodyMode(mode)}
          onZoomRequested:function(step){if(root.service)root.service.setBodyZoom(root.service.bodyZoom+step)}
          onZoomResetRequested:if(root.service)root.service.setBodyZoom(1)
          onMemberRequested:function(id){if(root.service)root.service.select(id)}
          onActionRequested:function(action){root.messageAction(action)}
          onComposeRequested:function(mode){root.startCompose(mode)}
          onMailtoRequested:function(url){composeShell.startMailto(url)}
        }
      }
    }
    Label {
      objectName:"mailStatusNotice"
      visible:text.length>0
      text:root.service ? (composeShell.notice || root.service.lastError || root.service.backend.failure || "") : ""
      color:root.muted; textFormat:Text.PlainText; font.pixelSize:10*root.textScale; Layout.fillWidth:true; wrapMode:Text.Wrap
    }
  }
  RowLayout {
    Layout.fillWidth:true
    visible:!!root.service && root.service.sendPending
    Label {text:root.service ? "Sending in "+root.service.sendSecondsRemaining+"s" : "";color:root.accent;Layout.fillWidth:true}
    MailButton {objectName:"mailUndoSend";text:"Undo send";onClicked:composeShell.undoPendingSend()}
  }
  }
  EmailComposer {
    id:composeShell
    objectName:"mailComposeShell"
    anchors.fill:parent
    visible:composing
    hostVisible:root.visible
    service:root.service
    bg:root.bg;fg:root.fg;accent:root.accent;muted:root.muted;edge:root.edge;fontFamily:root.fontFamily

  }
  MailUi.SetupPages {
    id: setupPages
    service:root.service
    textColor:root.fg; dimColor:root.muted; dangerColor:root.accent; accentColor:root.accent; panelFontFamily:root.fontFamily
    onChosen: function(providerId) { root.chooseProvider(providerId) }
    onRemoveRequested:removeAccount.open()
  }
  Dialog {
    id: accountSetup
    objectName:"mailAccountSetup"
    title:root.choosingProvider ? "Add a mailbox" : "Account settings"
    parent:Overlay.overlay
    anchors.centerIn:parent
    width:Math.min(parent.width-32,760); height:Math.min(parent.height-32,760)
    modal:true; padding:24
    palette.window:root.bg; palette.windowText:root.fg; palette.text:root.fg; palette.button:root.bg; palette.buttonText:root.fg; palette.highlight:root.accent
    background:Rectangle { color:root.bg; border.color:root.edge; radius:12 }
    contentItem:ScrollView {
      id: setupScroll
      clip:true; rightPadding:24; contentWidth:availableWidth
      Loader {
        objectName:"mailProviderSetup"
        width:setupScroll.availableWidth
        sourceComponent:setupPages.pageFor(root.service ? root.service.providerId : "gmail",root.choosingProvider)
      }
    }
    footer:MailButton { text:"Done"; onClicked:accountSetup.close() }
    onClosed: { if(root.service)root.service.discardCurrentDraft() }
  }
  Dialog {
    id: compatibilityNotice
    parent:Overlay.overlay; anchors.centerIn:parent; modal:true
    title:"Microsoft 365"
    Label { text:"The backend pinned by StarMail does not yet support Microsoft 365 API 8. Outlook personal accounts use the separate Outlook option."; color:root.fg; width:Math.min(400,root.width-32); wrapMode:Text.Wrap }
    standardButtons:Dialog.Ok
  }
  Dialog {
    id:removeAccount
    parent:Overlay.overlay; anchors.centerIn:parent; modal:true
    title:"Remove this mailbox?"
    Label { text:"Remove this mailbox from the dashboard? Messages on the server are kept."; color:root.fg; width:Math.min(400,root.width-32); wrapMode:Text.Wrap }
    standardButtons:Dialog.Cancel | Dialog.Ok
    onAccepted:{ root.service.removeAccountAt(root.service.editingIndex()); accountSetup.close() }
  }
}
