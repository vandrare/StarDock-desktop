import QtQuick
import "../vendor/omamail/ui/message/Html.js" as Html
QtObject {
  id:root
  property QtObject backend: QtObject {
    property bool ready:true
    property int apiVersion:7
    property string failure:""
    property int revision:0
    property var record:({version:1,active:false})
    function call(method,params,done) {
      var result={}
      if(method==="compose.recoveryRead")result={revision:String(revision),record:record}
      else if(method==="compose.recoverySave") {record=JSON.parse(JSON.stringify(params.record));revision++;result={revision:String(revision),record:record}}
      else if(method==="message.composeText")result={body:params.summary?"\n\nQuoted message":"",quote:params.summary?"Quoted message":"",replySubject:params.summary?"Re: "+params.summary.subject:""}
      else if(method==="outbox.snapshot")result={entries:root.outboxState ? [{state:root.outboxState}] : []}
      else if(method==="attachment.read")result={ok:true,filename:"fixture.txt",mimeType:"text/plain",size:4,data:"dGVzdA==",path:params.path}
      if(done)Qt.callLater(function(){done(result,null)})
    }
  }
  property string htmlSource:""
  readonly property var rendered:Html.sanitize(htmlSource,{withReader:true})
  readonly property bool selectedHasHtml:htmlSource!==""
  readonly property var selectedDocument:rendered.document
  readonly property var selectedReaderDocument:rendered.reader.document
  property bool selectedReaderTooHeavy:false
  readonly property bool selectedReaderEmpty:rendered.reader.empty
  readonly property int selectedReaderRemoteImages:rendered.reader.blockedImages
  readonly property int selectedRemoteImages:rendered.remoteImages
  property bool selectedTooHeavy:false
  property bool remoteImagesAllowed:false
  property bool alwaysShowImages:false
  property bool alwaysRenderHeavyMessages:false
  property string bodyMode:"reader"
  property real bodyZoom:1
  property var selectedImages:[]
  property var selectedInvite:null
  property string selectedResponse:""
  property bool canRespondToInvite:false
  property bool rsvpSending:false
  property bool rsvpFallbackAvailable:false
  property string rsvpCalendarUrl:""
  property var eventSuggestions:[]
  property bool showsRail:false
  property bool canOpenOnWeb:false
  property int unsubscribeCount:0
  function unsubscribe(){unsubscribeCount++}
  property string unsubscribeLabel:""
  property string unsubscribeDetail:""
  property bool unsubscribing:false
  property int imageApprovals:0
  property var openedLinks:[]
  function setBodyMode(mode){bodyMode=mode}
  function setBodyZoom(value){bodyZoom=value}
  function showMessageImages(){imageApprovals++;remoteImagesAllowed=true}
  function setAlwaysShowImages(value){alwaysShowImages=value;remoteImagesAllowed=value}
  function openExternal(url){openedLinks=openedLinks.concat([url]);return true}
  property var current: ({mailboxes:[{key:"inbox",label:"Inbox"}],mailboxKey:"inbox"})
  property bool ready: true
  property bool hasSavedAccounts: true
  property int accountCount: 1
  property string addedProvider: ""
  function addAccount(provider) { addedProvider=provider;accountCount=1 }
  function configureCurrentAccount(values) { return accountCount>0 }
  property int unreadTotal: 1
  property int inboxUnread: 1
  property string accountEmail: "fixture@example.test"
  property var accountSummaries: [{id:"fixture",label:"Test mailbox",email:"fixture@example.test",active:true}]
  property var messages: [{id:"fixture-message",dateMs:1792929600000,subject:"Mail reader test",from:{display:"Test Sender",email:"sender@example.test"},to:[{email:"fixture@example.test"}],cc:[{email:"copy@example.test"}],threadId:"fixture-thread",messageId:"<fixture-id@example.test>",labelIds:["INBOX","UNREAD"],snippet:"Preview text",starred:false,unread:true}]
  property string selectedId: ""
  property var selectedMessage: null
  property var selectedBody: ({text:""})
  property bool detailLoading: false
  property bool listLoading: false
  property bool hasMore: false
  property string lastError: ""
  property string activityStatus: ""
  property string searchValue: ""
  property int refreshes: 0
  property bool listLoaded:true
  property string searchQuery:""
  property bool canMoveToLabel:false
  property bool canSend:true
  property bool canArchive:true
  property bool canStar:true
  property bool detailPainted:true
  property string contentDirection:"Auto"
  readonly property string mailboxKey:current ? current.mailboxKey : ""
  property string activeAccountId:"fixture"
  property string composeAccountId:"fixture"
  property var selectedAttachments:[]
  property var recipientContacts:[]
  property var sendAsAliases:[]
  property var sendIdentities:[{accountId:"fixture",email:"fixture@example.test",displayName:"Test",label:"Test mailbox"}]
  property var senderSources:[]
  property bool sendPending:false
  property int sendSecondsRemaining:10
  property bool sending:false
  property int sendCount:0
  property var lastSend:null
  property var lastDraft:null
  property bool draftShouldFail:false
  property string outboxState:""
  property var actions:[]
  property int attachmentSaves:0
  signal replySent(string sendId)
  signal replyFailed(string sendId)
  function signatureFor(id) {return ""}
  function cachePath(name) {return "/tmp/starlink-mail-fixture/"+name}
  function accountEmailFor(id) {return accountEmail}
  function preferredSendAs(recipients) {return sendIdentities[0]}
  function refreshRecipientContacts() {}
  function switchTo(id) {activeAccountId=id;return true}
  function fail(text) {lastError=text}
  function send(fields) {lastSend=JSON.parse(JSON.stringify(fields));sendCount++;sendPending=true;outboxState="queued";return "fixture-send-"+sendCount}
  function undoSend(callback) {sendPending=false;outboxState="cancelled";if(callback)Qt.callLater(function(){callback("fixture-send-"+root.sendCount)});return true}
  function saveDraft(fields,callback) {lastDraft=JSON.parse(JSON.stringify(fields));Qt.callLater(function(){callback(root.draftShouldFail?null:{saved:true},root.draftShouldFail?"fixture save failed":null)})}
  function act(id,action) {var next=actions.slice();next.push({id:id,action:action});actions=next;return true}
  function toggleStar(id) {return act(id,"star")}
  function chooseFiles(done) {done({ok:true,paths:["/tmp/fixture.txt"]});return true}
  function loadAttachments(id,items,done) {Qt.callLater(function(){done([{filename:"original.txt",data:"dGVzdA==",size:4}],null)});return null}
  function attachmentIsSaving(id,attachmentId) {return false}
  function saveAttachment(id,item) {attachmentSaves++}
  function openAttachment(id,item) {}
  function select(id) { remoteImagesAllowed=alwaysShowImages;selectedId=id; selectedMessage=messages[0]; selectedBody={text:"First line\n\nThird line <img src=\"https://example.test/tracker\">"} }
  function clearSelection() { selectedId="";selectedMessage=null;selectedBody={text:""} }
  function refresh() { refreshes++ }
  function search(value) { searchValue=value }
  function selectMailbox(key) { clearSelection() }
  function switchToIndex(index) {}
}
