import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import "tests" as Fixtures
ShellRoot {
  id:testRoot
  readonly property var panel:panelLoader.item
  property string flushResult:""
  property int htmlSerial:0
  Fixtures.MailFixture { id: fixture }
  PopupAppearanceManager {id:popupStyles;target:testRoot.panel;overlay:testRoot.panel?testRoot.panel.Overlay.overlay:null;appearance:({shadowSize:28,shadowColor:"#123456",overlayOpacity:55});backgroundColor:"#071426";borderColor:"#304050"}
  FloatingWindow {
    title:"Starlink Mail Integration Test"
    color:"#071426"
    implicitWidth:1200;implicitHeight:760
    Loader {
      id:panelLoader
      anchors.fill:parent;anchors.margins:24
      sourceComponent:Component {
        EmailPanel {
          service:fixture
          bg:"#071426";fg:"#c8d9e9";accent:"#6cb6ff";edge:"#304050";muted:"#8099aa";fontFamily:"JetBrainsMono Nerd Font"
        }
      }
    }
  }
  function find(item,name) {
    if(item.objectName===name)return item
    var children=item.children || []
    for(var i=0;i<children.length;i++){var found=find(children[i],name);if(found)return found}
    return null
  }
  IpcHandler {
    target:"mailtest"
    function compose(mode:string):string {
      fixture.current={mailboxes:[{key:"inbox",label:"Inbox"}],mailboxKey:"inbox"};fixture.hasSavedAccounts=true
      if(!fixture.selectedMessage)fixture.select("fixture-message")
      var shell=find(panel,"mailComposeShell")
      if(shell.editor.opened)shell.editor.finish()
      panel.startCompose(mode)
      return "opened="+shell.editor.opened
    }
    function inspectCompose():string {
      var shell=find(panel,"mailComposeShell")
      return JSON.stringify({opened:shell.composing,draft:shell.editor.snapshotDraft(),parked:shell.editor.parkedForSend,recovery:fixture.backend.record,send:fixture.lastSend,draftSaved:fixture.lastDraft,error:fixture.lastError})
    }
    function prepare():string {
      var shell=find(panel,"mailComposeShell")
      shell.editor.beginDraft({from:"fixture@example.test",to:"recipient@example.test",subject:"Synthetic message",body:"Hello\n\nSecond paragraph"})
      shell.editor.replaceBody("Hello\n\nSecond paragraph")
      shell.editor.chooseFiles()
      return "prepared"
    }
    function send():string {
      var shell=find(panel,"mailComposeShell")
      var before=fixture.sendCount
      shell.editor.submit()
      shell.editor.submit()
      if(fixture.sendCount!==before+1)return "FAIL: duplicate send"
      if(!fixture.lastSend || fixture.lastSend.accountId!=="fixture" || fixture.lastSend.attachments.length!==1 || fixture.lastSend.to!=="recipient@example.test")return "FAIL: send routing or attachments"
      if(!shell.editor.parkedForSend || shell.composing)return "FAIL: send not parked"
      return "PASS: synthetic send dispatched once and parked for undo"
    }
    function undo():string {find(panel,"mailComposeShell").undoPendingSend();return "undo requested"}
    function verifyUndo():string {
      var shell=find(panel,"mailComposeShell")
      if(!shell.composing || shell.editor.snapshotDraft().body!=="Hello\n\nSecond paragraph" || shell.editor.draftAttachments.length!==1)return "FAIL: undo did not restore draft and attachment"
      return "PASS: undo restored the original draft and attachment"
    }
    function saveDraft(fail:bool):string {fixture.draftShouldFail=fail;find(panel,"mailComposeShell").saveAndLeaveCompose(true);return "save requested"}
    function verifySave(fail:bool):string {
      var shell=find(panel,"mailComposeShell")
      if(!fixture.lastDraft || fixture.lastDraft.body!=="Hello\n\nSecond paragraph")return "FAIL: draft save fields"
      if(shell.composing!==fail)return "FAIL: draft save success/failure state"
      return "PASS: draft save "+(fail?"failure restored draft":"succeeded")
    }
    function actions():string {
      fixture.select("fixture-message")
      find(panel,"mailArchive").clicked();find(panel,"mailTrash").clicked();find(panel,"mailMarkRead").clicked();find(panel,"mailStar").clicked()
      var verbs=fixture.actions.map(function(entry){return entry.action}).join(",")
      if(verbs!=="archive,trash,markRead,star")return "FAIL: "+verbs
      fixture.current={mailboxes:[],mailboxKey:"trash"}
      fixture.selectedMessage={id:"fixture-message",labelIds:["TRASH"],subject:"In trash",unread:false}
      return "PASS: archive, trash, read and star routed to selected message"
    }
    function verifyRestore():string {
      var button=find(panel,"mailTrash")
      if(button.Accessible.name!=="Restore")return "FAIL: trash action should restore"
      button.clicked()
      return fixture.actions[fixture.actions.length-1].action==="untrash" ? "PASS: trash view restores messages" : "FAIL: restore route"
    }
    function flush():string {
      testRoot.flushResult="waiting"
      panel.flushDrafts(function(ok){testRoot.flushResult=ok?"PASS: local draft recovery flushed":"FAIL: flush"})
      return "flush requested"
    }
    function flushStatus():string {return testRoot.flushResult}
    function recreate():string {panelLoader.active=false;Qt.callLater(function(){panelLoader.active=true});return "recreating panel"}
    function forwardSend():string {
      var shell=find(panel,"mailComposeShell")
      if(shell.composing)shell.editor.finish()
      fixture.select("fixture-message")
      panel.startCompose("forward")
      return "forward opened"
    }
    function verifyForwardSend():string {
      var shell=find(panel,"mailComposeShell")
      find(panel,"compose-to-field").text="forward@example.test"
      shell.editor.submit()
      if(fixture.lastSend.threadId!=="" || fixture.lastSend.inReplyTo!=="" || fixture.lastSend.to!=="forward@example.test")return "FAIL: forward thread routing"
      fixture.sendPending=false;fixture.outboxState="sent";fixture.replySent("fixture-send-"+fixture.sendCount)
      return "PASS: forward starts a new thread; sent receipt handled"
    }
    function verifyRecovery():string {
      var shell=find(panel,"mailComposeShell")
      if(!shell.composing || shell.editor.snapshotDraft().body!=="Hello\n\nSecond paragraph" || shell.editor.draftAttachments.length!==1)return "FAIL: recovery did not restore body and attachment"
      return "PASS: recreated editor recovered local draft and attachment"
    }
    function newerDraft():string {
      var shell=find(panel,"mailComposeShell")
      shell.editor.beginDraft({from:"fixture@example.test",to:"newer@example.test",subject:"Newer draft",body:"Keep the newer draft"})
      shell.editor.replaceBody("Keep the newer draft")
      return "newer draft opened"
    }
    function verifyBothDrafts():string {
      var shell=find(panel,"mailComposeShell")
      var record=fixture.backend.record
      if(!record.active || record.draft.body!=="Hello\n\nSecond paragraph" || !record.parked.some(function(draft){return draft.body==="Keep the newer draft"}))return "FAIL: interrupted draft missing from recovery"
      return "PASS: both undone and interrupted drafts saved for recovery"
    }
    function finishRecoveredOriginal():string {
      var shell=find(panel,"mailComposeShell")
      shell.editor.finish()
      return shell.editor.snapshotDraft().body==="Keep the newer draft" ? "PASS: interrupted newer draft restored" : "FAIL: interrupted draft not restored"
    }
    function alreadySent():string {fixture.sendPending=false;fixture.outboxState="sent";return "delivery receipt seeded"}
    function verifyNoResend():string {
      var shell=find(panel,"mailComposeShell")
      return !shell.composing && !fixture.backend.record.active ? "PASS: sent receipt prevents draft reopening or resend" : "FAIL: sent draft reopened"
    }
    function seedUnsubscribe():string {
      fixture.htmlSource="<p>Synthetic newsletter</p>"
      fixture.unsubscribeLabel="Unsubscribe"
      fixture.unsubscribeDetail="Leave this synthetic mailing list"
      return "PASS"
    }
    function verifyUnsubscribeToolbar():string {
      var button=find(panel,"readerUnsubscribe")
      var modes=find(panel,"bodyModeTrack")
      if(!button || !button.visible || !modes || !modes.visible)return "FAIL: missing toolbar controls"
      if(Math.abs(button.mapToItem(panel,0,0).y-modes.mapToItem(panel,0,0).y)>1)return "FAIL: unsubscribe not on mode row"
      if(find(panel,"readerUnsubscribeNotice").visible)return "FAIL: redundant unsubscribe status strip"
      if(find(panel,"messageBodyScroller").y>1)return "FAIL: removed notice still reserves space"
      var before=fixture.unsubscribeCount
      button.clicked()
      if(fixture.unsubscribeCount!==before+1)return "FAIL: unsubscribe action not routed"
      fixture.unsubscribeLabel="";fixture.unsubscribeDetail="";fixture.htmlSource=""
      return "PASS: toolbar unsubscribe uses existing service action"
    }
    function verifyPopupAppearance():string {
      popupStyles.scan()
      var draftConfirmation=false
      for(var i=0;i<popupStyles.styled.length;i++){
        var popup=popupStyles.styled[i]
        if(popup.background.settings.shadowSize!==28 || popup.background.settings.shadowColor!=="#123456")return "FAIL: inconsistent popup appearance"
        if(popup.parent && popup.parent.currentDraftKey!==undefined)draftConfirmation=true
      }
      return draftConfirmation?"PASS: global appearance includes draft confirmations":"FAIL: draft popup not styled"
    }
    function verifyInitialMessage():string {
      return fixture.selectedId===fixture.messages[0].id && !!fixture.selectedMessage && find(panel,"mailReader").visible ? "PASS: first message loaded automatically" : "FAIL: first message not loaded"
    }
    function verifyStyle():string {
      fixture.select("fixture-message")
      var backdrop=find(panel,"readerFooterBackdrop")
      var body=find(panel,"messageBodyScroller")
      var notice=find(panel,"mailStatusNotice")
      if(!backdrop || backdrop.color.a!==0)return "FAIL: reader toolbar background"
      if(body.y+body.height>backdrop.y+1)return "FAIL: body overlaps reading controls"
      if(notice.visible)return "FAIL: empty status reserves space"
      var row=find(panel,"mailMessage0")
      var date=find(panel,"mailReceivedDate0")
      var sender=find(panel,"mailSender0")
      var separator=find(panel,"mailMessageSeparator0")
      if(!row || row.background.border.width!==0 || !separator || separator.height!==1)return "FAIL: message separators"
      if(!date || date.text!==panel.receivedDate(fixture.messages[0]))return "FAIL: received date"
      if(date.mapToItem(panel,0,0).x<=sender.mapToItem(panel,0,0).x)return "FAIL: date should be to the right of sender"
      var reply=find(panel,"mailReply")
      if(reply.text!=="" || reply.Accessible.name!=="Reply…")return "FAIL: accessible icon action"
      var compose=find(panel,"mailCompose")
      if(!compose || compose.parent!==reply.parent || compose.width!==reply.width || compose.height!==reply.height || compose.text!=="" || compose.Accessible.name!=="Compose…")return "FAIL: compose toolbar icon"
      if(find(panel,"mailAddAccount"))return "FAIL: account creation still in mail sidebar"
      var trash=find(panel,"mailTrash")
      if(!trash || !trash.visible || !trash.enabled || trash.Accessible.name!=="Delete (move to trash)" || trash.y!==compose.y || trash.x<=compose.x || trash.x>=reply.x)return "FAIL: visible Delete action beside Compose"


      return "PASS: message separators, right-aligned received date and accessible icon actions"
    }
    function html(source:string):string {
      fixture.select("reader-message-"+(++testRoot.htmlSerial));fixture.htmlSource=source;fixture.selectedBody={text:"HTML fallback\n\nSecond paragraph",source:"html"};fixture.bodyMode="reader"
      return "PASS: synthetic HTML selected"
    }
    function readerMode(mode:string):string {
      var reader=find(panel,"mailReader");reader.bodyModeRequested(mode)
      if(fixture.bodyMode!==mode)return "FAIL: reader mode not saved"
      return "PASS: reader mode"
    }
    function contentFonts(body:int,list:int,scale:real):string {
      panel.bodyFontSize=body;panel.messageListFontSize=list;panel.textScale=scale
      return "PASS: content fonts updated"
    }
    function readerState():string {
      var reader=find(panel,"mailReader");var body=null
      function textEdit(item){if(item.textFormat!==undefined && item.readOnly!==undefined && item.text!==undefined)return item;var children=item.children || [];for(var i=0;i<children.length;i++){var found=textEdit(children[i]);if(found)return found}return null}
      body=textEdit(reader)
      return JSON.stringify({fontSize:reader.bodyFontSize,titleFont:find(panel,"mailMessageTitle0").font.pixelSize,mode:reader.shownMode,rich:reader.richBody,blocked:reader.remoteImages,allowed:fixture.remoteImagesAllowed,always:fixture.alwaysShowImages,approvals:fixture.imageApprovals,body:body?body.text:"",links:fixture.openedLinks,sent:fixture.sendCount})
    }
    function approveImages():string {
      var reader=find(panel,"mailReader")
      // Activate the native image notice, not the account preference.
      function notice(item){if(item.actionLabel==="Load images")return item;var children=item.children||[];for(var i=0;i<children.length;i++){var hit=notice(children[i]);if(hit)return hit}return null}
      var banner=notice(reader);if(!banner || !banner.visible)return "FAIL: blocked image notice missing"
      banner.activated();if(fixture.alwaysShowImages || fixture.imageApprovals!==1)return "FAIL: approval changed standing preference"
      return "PASS: one-message approval"
    }
    function readerLink(url:string):string {find(panel,"mailReader").openLink(url);return "PASS: link handled"}
    function heavy(value:bool):string {fixture.selectedReaderTooHeavy=value;fixture.selectedTooHeavy=value;return "PASS: heavy layout preference"}
    function clearReader():string {fixture.clearSelection();return "PASS: selection cleared"}
    function verifyEmptyReader():string {return !find(panel,"mailReader").visible?"PASS: empty reader":"FAIL: inactive reader shown"}
    function closeCompose():string {find(panel,"mailComposeShell").editor.finish();return "PASS"}
    function exercise():string {
      var first=find(panel,"mailMessage0")
      if(!first)return "FAIL: message row missing"
      first.clicked()
      return "selected="+fixture.selectedId
    }
    function verify():string {
      var reader=find(panel,"mailReader")
      if(!reader || reader.shownMode!=="plain")return "FAIL: plain-text fallback"
      var search=find(panel,"mailSearch");search.text="test search";search.accepted()
      find(panel,"mailRefresh").clicked()
      if(fixture.searchValue!=="test search" || fixture.refreshes!==1)return "FAIL: search or refresh"
      fixture.clearSelection()
      fixture.current=null;fixture.accountCount=0;fixture.hasSavedAccounts=false
      panel.chooseProvider("imap")
      if(fixture.addedProvider!=="imap")return "FAIL: reopening canceled first-account setup"
      return "PASS: message selection, multiline plain-text reader, search, refresh and clear selection"
    }
  }
}
