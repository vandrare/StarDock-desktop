import QtQuick
import Quickshell.Io

Item {
  id:root
  property string error:""
  property var command:["/usr/bin/python3",String(Qt.resolvedUrl("scripts/notify_mail.py")).replace(/^file:\/\//,"")]
  signal activated(string accountId,string messageId)
  function notify(accountId,messageId,title,body){
    error=""
    var process=worker.createObject(root,{accountId:String(accountId),messageId:String(messageId),payload:JSON.stringify({title:String(title),body:String(body)})})
    process.running=true
  }
  Component {
    id:worker
    Process {
      id:process
      property string accountId
      property string messageId
      property string payload
      command:root.command
      stdinEnabled:true
      onStarted:{write(payload);stdinEnabled=false;deadline.start()}
      stdout:StdioCollector {onStreamFinished:if(text.trim()==="default")root.activated(process.accountId,process.messageId)}
      stderr:StdioCollector {}
      onExited:function(code){deadline.stop();if(code!==0)root.error="Could not send a desktop mail notification. Check that your notification service is running.";destroy()}
      property Timer deadline:Timer {interval:30000;onTriggered:{root.error="Desktop mail notification timed out";process.running=false}}
    }
  }
}
