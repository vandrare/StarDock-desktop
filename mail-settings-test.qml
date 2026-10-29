import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
  id:root
  property var activations:[]
  EmailService {id:host;calendarEnabled:false}
  MailNotifications {
    id:bridge
    command:["/usr/bin/python3","-c","import json,sys; p=json.load(sys.stdin); sys.exit(1) if p['body']=='FAIL' else print('default')"]
    onActivated:function(accountId,messageId){root.activations=root.activations.concat([{accountId:accountId,messageId:messageId}])}
  }
  FloatingWindow {
    implicitWidth:600;implicitHeight:700;title:"StarDock synthetic mail settings test"
    EmailPreferences {id:preferences;anchors.fill:parent;service:host.service;fg:"white";muted:"gray"}
  }
  function find(item,name){if(item.objectName===name)return item;var children=item.children || [];for(var i=0;i<children.length;i++){var hit=find(children[i],name);if(hit)return hit}return null}
  IpcHandler {
    target:"mailsettings"
    function status():string {return JSON.stringify({ready:host.service.backend.ready,interval:host.service.settings.refreshIntervalSec,notifications:host.service.notifyNewMail,images:host.service.alwaysShowImages,error:host.preferencesError,bridgeError:bridge.error,activations:root.activations})}
    function save():void {
      preferences.load()
      find(preferences,"emailRefreshInterval").value=300
      find(preferences,"emailNotifications").checked=true
      find(preferences,"emailRemoteImages").checked=true
      preferences.save()
    }
    function notify():void {bridge.notify("first-account","message-one","Synthetic sender","Subject");bridge.notify("second-account","message-two","Another sender","Subject")}
    function fail():void {bridge.notify("ignored-account","ignored-message","Failure fixture","FAIL")}
    function quit():void {host.flushPreferences(function(ok){if(ok)host.service.backend.shutdown(function(error){Qt.quit()})})}
  }
}
