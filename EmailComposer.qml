// Recovery/send lifecycle glue adapted from Omamail v0.11.1 App.qml (MIT).
// Copyright (c) 2026 Jason Lee. See vendor/omamail/LICENSE.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "vendor/omamail/ui/components" as MailUi
import "vendor/omamail/ui/compose" as Compose
import "vendor/omamail/ui/compose/Recovery.js" as Recovery
import "vendor/omamail/ui/message/Message.js" as Message
import "vendor/omamail/ui/message/Mailto.js" as Mailto
import "vendor/omamail/ui/backend/Plain.js" as Plain

Item {
  id: root
  property var service: null
  property color bg
  property color fg
  property color accent
  property color muted
  property color edge
  property string fontFamily
  property bool hostVisible: true
  readonly property bool opened: hostVisible
  readonly property bool composing: compose.opened
  readonly property alias editor: compose
  readonly property string notice: composeRecoveryNotice || draftSavedToast
  property string draftSavedToast: ""
  property string composeRecoveryNotice: ""
  property bool composeRecoveryUpdateNoticePending: false
  property int pendingComposeReturnTo: -1
  property var nav: []
  property bool draftSaveBusy: false
  property var flushCallback: null
  property int flushChecks: 0
  property var composeRecovery: Recovery.empty()
  property bool composeRecoveryLoaded: false
  property bool composeRecoveryRestoring: false
  property int composeRecoveryRevision: 0
  property bool composeDetachingForSave: false
  property string lastComposeRecoveryText: ""
  property string composeWritePayload: ""
  property bool composeWriteQueued: false
  property bool composeWriting: false
  property bool composeReading: false
  property bool composeRecoveryConflict: false
  property string composeStorageRevision: ""
  property bool composeReceiptChecking: false
  property int composeCommittedRevision: 0
  property var composeReceiptAcks: []
  property var composeReceiptAckBusy: ({})
  property var composeDeliveryStates: ({})

  // Only a native normalized record is restored; the editor owns its live fields.
  function loadComposeRecovery(record) {
    composeRecovery = record && typeof record === "object" ? record : Recovery.empty()
    lastComposeRecoveryText = composeRecovery.active === true ? JSON.stringify(composeRecovery) : ""
    composeRecoveryLoaded = true
    reconcileComposeReceipts()
  }

  Compose.RecoveryController {
    id: composeRecoveryController
    app: root
    composer: compose
    recoveryTimer: composeRecoveryTimer
  }
  function reconcileComposeReceipts() { composeRecoveryController.reconcileComposeReceipts() }
  function queueComposeReceiptAck(accountId, sendId, revision) {
    composeRecoveryController.queueComposeReceiptAck(accountId, sendId, revision)
  }
  function acknowledgeComposeReceipts() { composeRecoveryController.acknowledgeComposeReceipts() }

  function readComposeRecovery() { return composeRecoveryController.readComposeRecovery() }
  function restoreComposeRecovery() { return composeRecoveryController.restoreComposeRecovery() }
  function parkedBesides(draft) {
    var parked=composeRecoveryController.parkedBesides(draft)
    if(compose.interruptedDraft && compose.interruptedDraft!==draft)parked.push(compose.interruptedDraft)
    return parked
  }
  function saveComposeRecovery(saved) { return composeRecoveryController.saveComposeRecovery(saved) }
  function scheduleComposeRecovery() { return composeRecoveryController.scheduleComposeRecovery() }
  function clearComposeRecovery(expectedRevision) { return composeRecoveryController.clearComposeRecovery(expectedRevision) }
  function writeComposeRecovery(raw) { return composeRecoveryController.writeComposeRecovery(raw) }
  function drainComposeRecovery() { return composeRecoveryController.drainComposeRecovery() }

  function composeReturnView() { return service && service.selectedId ? "reader" : "list" }
  function startMailto(url) {
    var fields=Mailto.parse(String(url))
    if(!fields || !service || !service.ready || !service.canSend)return false
    if(compose.opened){compose.takeFocus();return false}
    compose.beginDraft(fields)
    Qt.callLater(compose.takeFocus)
    return true
  }
  function start(mode) {
    if(compose.opened) { compose.takeFocus();return }
    if(!service || !service.ready || !service.canSend)return
    if(mode!=="new" && (!service.selectedMessage || service.detailLoading || !service.detailPainted))return
    if(mode==="draft") {
      compose.beginDraft(Message.draftFields(Plain.plain(service.selectedMessage),service.selectedBody.text),service.selectedId,Plain.plain(service.selectedAttachments))
    } else compose.begin(mode,Plain.plain(service.selectedMessage),service.selectedBody.text,Plain.plain(service.selectedAttachments))
    Qt.callLater(compose.takeFocus)
  }
  function requestLeaveCompose() {
    if(!compose.opened)return
    if(!compose.hasUserChanges())compose.finish()
    else exitDialog.open()
  }
  function saveAndLeaveCompose(force) {
    if(!compose.opened || !service || draftSaveBusy)return
    if(force!==true && !compose.hasMeaningfulDraft()) {compose.finish();return}
    var saved=compose.snapshotDraft()
    var revision=saveComposeRecovery(saved)
    composeDetachingForSave=true
    compose.detachForSave()
    composeDetachingForSave=false
    draftSaveBusy=true
    service.saveDraft(compose.fieldsForDraft(saved),function(result,error) {
      root.draftSaveBusy=false
      if(error) {
        compose.recoverDetachedSave(saved)
        if(root.composeRecoveryRevision===revision)root.saveComposeRecovery(saved)
        else root.scheduleComposeRecovery()
        root.service.fail("Could not save draft: "+String(error))
        return
      }
      compose.completeDetachedSave(saved)
      if(compose.opened || compose.parkedForSend)root.scheduleComposeRecovery()
      else root.clearComposeRecovery(revision)
      root.draftSavedToast=String(result && result.warning || "Draft saved")
      noticeTimer.restart()
    })
  }
  function restoreParkedDraft(sendId,oldest) {
    var named=(compose.parkedDrafts || []).filter(function(entry){return entry.sendId===String(sendId || "")})
    var account=named.length && named[0].draft ? String(named[0].draft.accountId || "") : ""
    if(!compose.resumePendingSend(sendId,oldest))return false
    var revision=saveComposeRecovery()
    if(account!=="")queueComposeReceiptAck(account,String(sendId),revision)
    // ComposeView retains the interrupted newer draft; closing the restored
    // message brings it back instead of silently discarding it.
    if(root.hostVisible)Qt.callLater(compose.takeFocus)
    return true
  }
  function undoPendingSend() {
    if(!service)return false
    return service.undoSend(function(id){if(id)root.restoreParkedDraft(id===true?"":String(id),false)})
  }
  function flush(done) {
    if(flushCallback) { if(done)done(false);return }
    composeRecoveryTimer.stop()
    if(compose.opened || compose.parkedForSend)saveComposeRecovery()
    flushCallback=done
    flushChecks=0
    flushTimer.start()
  }
  Timer {
    id:flushTimer
    interval:50;repeat:true
    onTriggered: {
      root.flushChecks++
      if(!root.composeWriting && !root.composeWriteQueued && !root.draftSaveBusy && !compose.attaching) {
        stop();var done=root.flushCallback;root.flushCallback=null;if(done)done(true)
      } else if(root.flushChecks>=100 || root.composeRecoveryConflict) {
        stop();root.composeRecoveryNotice="Draft changes could not be saved. Keep Email open and try again."
        var done=root.flushCallback;root.flushCallback=null;if(done)done(false)
      }
    }
  }
  Timer {id:composeRecoveryTimer;interval:300;onTriggered:root.saveComposeRecovery()}
  Timer {id:noticeTimer;interval:5000;onTriggered:root.draftSavedToast=""}
  onServiceChanged:Qt.callLater(readComposeRecovery)
  onHostVisibleChanged:if(hostVisible)Qt.callLater(restoreComposeRecovery)
  Connections {
    target:root.service ? root.service.backend : null
    ignoreUnknownSignals:true
    function onReadyChanged() {if(root.service.backend.ready){root.readComposeRecovery();root.acknowledgeComposeReceipts()}}
  }
  Connections {
    target:root.service
    ignoreUnknownSignals:true
    function onReplySent(sendId) {
      if(!compose.completePendingSend(sendId))return
      if(compose.opened || compose.parkedForSend)root.scheduleComposeRecovery()
      else root.clearComposeRecovery()
      root.draftSavedToast="Message sent";noticeTimer.restart()
    }
    function onReplyFailed(sendId) {if(root.restoreParkedDraft(sendId,true))root.scheduleComposeRecovery()}
  }
  MailUi.ComposeView {
    id:compose
    objectName:"mailComposer"
    anchors.fill:parent
    anchors.topMargin:composeStatus.visible ? composeStatus.implicitHeight+8 : 0
    anchors.bottomMargin:pendingBar.visible ? pendingBar.height+8 : 0
    visible:opened
    service:root.service
    textColor:root.fg;backgroundColor:root.bg;accentColor:root.accent;dimColor:root.muted;dimmerColor:root.muted
    popupBackgroundColor:root.bg;popupBorderColor:root.edge;panelFontFamily:root.fontFamily
    contentDirection:root.service ? root.service.contentDirection : "Auto"
    onOpenedChanged:if(opened && root.hostVisible)Qt.callLater(takeFocus)
    onClosed: {
      if(!root.composeDetachingForSave) {
        if(parkedForSend)root.scheduleComposeRecovery()
        else root.clearComposeRecovery()
      }
    }
    onCloseRequested:root.requestLeaveCompose()
    onSendQueued:root.saveComposeRecovery(pendingDraft)
    onDraftChanged:root.scheduleComposeRecovery()
  }
  MailUi.ComposeExitDialog {
    id:exitDialog
    textColor:root.fg;dimColor:root.muted;dangerColor:root.accent
    popupBackgroundColor:root.bg;popupBorderColor:root.edge;panelFontFamily:root.fontFamily
    currentDraftKey:compose.opened ? compose.draftKey : ""
    onSaveRequested:function(key){if(key===compose.draftKey)root.saveAndLeaveCompose(true)}
    onDiscardRequested:function(key){if(key===compose.draftKey)compose.finish()}
  }
  Label {
    id:composeStatus
    objectName:"mailComposeStatus"
    anchors.top:parent.top;anchors.left:parent.left;anchors.right:parent.right
    text:root.notice || (root.service ? root.service.lastError : "")
    textFormat:Text.PlainText
    visible:compose.opened && text.length>0
    color:root.accent;wrapMode:Text.Wrap;font.pixelSize:11
  }
  RowLayout {
    id:pendingBar
    anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom
    visible:!!root.service && root.service.sendPending && compose.opened
    Label {text:root.service ? "Sending in "+root.service.sendSecondsRemaining+"s" : "";color:root.muted;Layout.fillWidth:true}
    AppButton {text:"Undo send";onClicked:root.undoPendingSend()}
  }
}
