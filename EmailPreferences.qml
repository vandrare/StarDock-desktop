import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
  id:root
  property var service:null
  property color fg
  property color muted
  property string saveError:""
  signal signaturesRequested()
  signal accountsRequested()
  signal addAccountRequested()
  property bool accountsExpanded:false
  function load(){
    accountsExpanded=false
    refresh.value=Math.max(30,Math.min(3600,Number(service && service.settings.refreshIntervalSec)||120))
    notifications.checked=!!service && service.notifyNewMail
    images.checked=!!service && service.alwaysShowImages
  }
  function save(){
    if(!service)return
    var values=Object.assign({},service.settings,{refreshIntervalSec:refresh.value,notifyNewMail:notifications.checked?"On":"Off"})
    service.applySettings(values)
    service.shell.updateEntryInline(service.pluginId,values)
    service.setAlwaysShowImages(images.checked)
  }
  Component.onCompleted:load()
  Label {visible:!!root.saveError;text:root.saveError;textFormat:Text.PlainText;color:root.fg;wrapMode:Text.Wrap;Layout.fillWidth:true}
  AbstractButton {
    objectName:"emailAccountsHeader"
    Layout.fillWidth:true;implicitHeight:40
    Accessible.name:"Email accounts"
    onClicked:root.accountsExpanded=!root.accountsExpanded
    contentItem:RowLayout {
      Label {text:"Accounts";color:root.fg;font.bold:true;Layout.fillWidth:true}
      Label {text:root.accountsExpanded?"⌃":"⌄";color:root.fg;font.pixelSize:20}
    }
  }
  ColumnLayout {
    visible:root.accountsExpanded;Layout.fillWidth:true;spacing:8
    AppButton {objectName:"emailAddAccount";text:"+ Account…";Layout.fillWidth:true;enabled:!!root.service && !!root.service.backend && root.service.backend.ready;onClicked:root.addAccountRequested()}
    AppButton {objectName:"emailAccountSettings";text:"Accounts & settings…";Layout.fillWidth:true;enabled:!!root.service && !!root.service.backend && root.service.backend.ready;onClicked:root.accountsRequested()}
    AppButton {objectName:"emailSignatures";text:"Account signatures…";Layout.fillWidth:true;enabled:!!root.service && root.service.accountCount>0;onClicked:root.signaturesRequested()}
  }
  Label {text:"Check for new mail every (seconds)";color:root.fg}
  SpinBox {id:refresh;objectName:"emailRefreshInterval";from:30;to:3600;stepSize:30;editable:true}
  Label {text:"Default: 120 seconds. Mail checks run while StarDock is running, including when another module is open.";color:root.muted;wrapMode:Text.Wrap;Layout.fillWidth:true;font.pixelSize:11}
  Switch {id:notifications;objectName:"emailNotifications";text:"Desktop notifications for new mail";enabled:!!root.service && root.service.hasNotifications;palette.windowText:root.fg}
  Label {text:"Notifications include the sender and subject. Selecting Read opens the message in its account. StarDock must be running with Email enabled.";color:root.muted;wrapMode:Text.Wrap;Layout.fillWidth:true;font.pixelSize:11}
  Label {visible:!!root.service && !!root.service.notificationError;text:root.service?root.service.notificationError:"";textFormat:Text.PlainText;color:root.fg;wrapMode:Text.Wrap;Layout.fillWidth:true}
  Switch {id:images;objectName:"emailRemoteImages";text:"Always show remote images";palette.windowText:root.fg}
  Label {text:"Off by default. Loading remote images can tell the sender when you open a message. Leave this off to approve images for individual messages.";color:root.muted;wrapMode:Text.Wrap;Layout.fillWidth:true;font.pixelSize:11}
  Label {text:"Signatures belong to individual accounts and save separately when you leave the signature field. Other Email changes save with Apply; Cancel discards them.";color:root.muted;wrapMode:Text.Wrap;Layout.fillWidth:true;font.pixelSize:11}
}
