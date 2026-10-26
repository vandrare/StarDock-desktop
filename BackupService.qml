import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id:root
  property var state:({settings:{directory:"",schedule:"off",keep:10},status:{},backups:[]})
  property var liveSnapshot:({})
  property var prepareBackup:null
  property var prepareRestore:null
  property bool automaticReady:true
  property bool ready:false
  property bool preparing:false
  readonly property bool busy:process.running || preparing
  property string error:""
  property string message:""
  property var preview:null
  property var request:({})
  property string output:""
  signal restoreReady(string ticket)
  signal restoreFailed()
  function execute(value) {
    request=value;output="";error="";message="";process.stdinEnabled=true;process.running=true
  }
  function run(value) {
    if(busy)return false
    if(value.op==="backup" || value.op==="scheduled"){
      preparing=true
      function begin(ok){root.preparing=false;if(!ok){root.error="Could not save account preferences before backup";return}root.execute(Object.assign({},value,{live:root.liveSnapshot}))}
      if(prepareBackup)prepareBackup(begin);else begin(true)
    }else execute(value)
    return true
  }
  function restore() {
    if(busy || !preview)return
    var approved={path:preview.path,digest:preview.digest}
    preparing=true
    function begin(ok){root.preparing=false;if(!ok){root.error="Restore canceled or unsaved changes could not be saved";root.restoreFailed();return}root.execute({op:"stage",path:approved.path,digest:approved.digest})}
    if(prepareRestore)prepareRestore(begin);else begin(false)
  }
  Component.onCompleted:run({op:"status"})
  Timer {interval:60000;running:root.ready && root.automaticReady;repeat:true;triggeredOnStart:true;onTriggered:if(!root.busy)root.run({op:"scheduled"})}
  Process {
    id:process
    command:["/usr/bin/python3",String(Qt.resolvedUrl("scripts/dashboard_backup.py")).replace(/^file:\/\//,"")]
    stdinEnabled:true
    onStarted:{write(JSON.stringify(root.request));stdinEnabled=false;deadline.restart()}
    stdout:StdioCollector {waitForEnd:true;onStreamFinished:root.output=String(text || "")}
    stderr:StdioCollector {waitForEnd:true}
    onExited:function(code){
      deadline.stop()
      try {
        var result=JSON.parse(root.output)
        if(!result.ok)throw new Error(result.error || "Backup operation failed")
        root.state=result;root.ready=true
        if(result.preview)root.preview=result.preview
        else if(root.request.op==="preview")root.preview=null
        if(result.created)root.message="Backup created: "+result.created
        if(root.request.op==="configure")root.message="Backup settings saved"
        if(result.ticket)root.restoreReady(result.ticket)
      }catch(error){root.ready=true;root.error=String(error.message || error);if(root.request.op==="preview")root.preview=null;if(root.request.op==="stage")root.restoreFailed()}
    }
  }
  Timer {id:deadline;interval:60000;onTriggered:{process.running=false;root.error="Backup operation timed out";if(root.request.op==="stage")root.restoreFailed()}}
}
