import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts

ColumnLayout {
  id:root
  property var service:null
  property color fg
  property color bg
  property color muted
  property color accent
  property color edge
  property var dialogWindow:null
  property bool dirty:false
  readonly property bool busy:!!service && service.busy
  function load(){if(!service || !service.ready)return;var value=service.state.settings;directory.text=value.directory;schedule.currentIndex=["off","daily","weekly"].indexOf(value.schedule);keep.value=value.keep;dirty=false}
  function save(){if(service)service.run({op:"configure",settings:{directory:directory.text.trim(),schedule:["off","daily","weekly"][schedule.currentIndex],keep:keep.value}})}
  Component.onCompleted:load()
  Connections {target:root.service;function onReadyChanged(){if(!root.dirty)root.load()} function onStateChanged(){if(root.service.request && root.service.request.op==="configure")root.load()}}
  Label {text:"Backups contain notes and supported configuration. Saved passwords, OAuth credentials, message caches, outgoing drafts and attachments are excluded. Notes and signatures may contain private content. Feed and calendar URLs containing credentials, query strings or fragments are omitted.";color:root.muted;wrapMode:Text.Wrap;Layout.fillWidth:true;font.pixelSize:11}
  Label {text:"Backup location";color:root.fg}
  RowLayout {
    Layout.fillWidth:true
    TextField {id:directory;objectName:"backupDirectory";Layout.fillWidth:true;enabled:!root.busy;onTextEdited:root.dirty=true;selectByMouse:true}
    AppButton {text:"Browse…";enabled:!root.busy;onClicked:folderPicker.open()}
  }
  Label {text:"Automatic backups";color:root.fg}
  ComboBox {id:schedule;objectName:"backupSchedule";Layout.fillWidth:true;model:["Off","Daily","Weekly"];enabled:!root.busy;onActivated:root.dirty=true}
  Label {text:"Scheduled backups run while the dashboard is open. Overdue backups run on the next launch.";color:root.muted;wrapMode:Text.Wrap;Layout.fillWidth:true;font.pixelSize:11}
  RowLayout {
    Label {text:"Backups to keep";color:root.fg;Layout.fillWidth:true}
    SpinBox {id:keep;objectName:"backupKeep";from:1;to:365;value:10;enabled:!root.busy;editable:true;onValueModified:root.dirty=true}
  }
  AppButton {objectName:"saveBackupSettings";text:"Save backup settings";Layout.fillWidth:true;enabled:!!root.service && root.service.ready && !root.busy && !!directory.text.trim();onClicked:root.save()}
  Label {text:"Backup settings save separately from the dashboard Apply button.";color:root.muted;wrapMode:Text.Wrap;Layout.fillWidth:true;font.pixelSize:11}
  AppButton {objectName:"backupNow";text:root.busy?"Working…":"Back up now";Layout.fillWidth:true;enabled:!!root.service && root.service.ready && !root.busy && !root.dirty;onClicked:root.service.run({op:"backup"})}
  Label {
    Layout.fillWidth:true;wrapMode:Text.Wrap;textFormat:Text.PlainText;color:root.muted;font.pixelSize:11
    text:root.service?("Last backup: "+(root.service.state.status.lastBackup || "None")+"\nLast restore: "+(root.service.state.status.lastRestore || "None")):"Loading backup settings…"
  }
  Label {text:root.service?(root.service.error || root.service.state.status.lastError || root.service.message):"";visible:!!text;textFormat:Text.PlainText;wrapMode:Text.Wrap;Layout.fillWidth:true;color:root.accent}
  Label {text:"Restore a backup";color:root.fg;font.bold:true}
  ComboBox {
    id:backups
    objectName:"backupSelection"
    Layout.fillWidth:true;enabled:!root.busy
    model:root.service?root.service.state.backups:[];textRole:"createdAt"
    displayText:currentIndex>=0?currentText:"No backups in the selected folder"
    onActivated:restorePath.text=model[currentIndex].path
  }
  RowLayout {
    Layout.fillWidth:true
    TextField {id:restorePath;objectName:"restoreBackupPath";Layout.fillWidth:true;onTextChanged:if(root.service)root.service.preview=null;placeholderText:"Select or enter a backup file";selectByMouse:true;enabled:!root.busy}
    AppButton {text:"Browse…";enabled:!root.busy;onClicked:filePicker.open()}
  }
  AppButton {objectName:"previewBackup";text:"Preview restore";Layout.fillWidth:true;enabled:!!root.service && !root.busy && !!restorePath.text;onClicked:root.service.run({op:"preview",path:restorePath.text.trim()})}
  Label {
    objectName:"backupPreview"
    visible:!!root.service && !!root.service.preview
    Layout.fillWidth:true;wrapMode:Text.Wrap;color:root.fg;textFormat:Text.PlainText
    text:root.service && root.service.preview ? "Created: "+root.service.preview.createdAt+"\nReplaces:\n• "+root.service.preview.sections.join("\n• ")+"\n\n"+root.service.preview.notes+" notes · "+root.service.preview.calendars+" calendar sources\n"+root.service.preview.accountPreferences+" account preference record(s); only matching connected accounts are updated.\n\nA safety backup is created first. The dashboard closes and restarts to restore files. Remote images start blocked. Accounts and saved credentials are kept; reconnect accounts on a new machine." : ""
  }
  AppButton {objectName:"restoreBackup";text:"Restore this backup…";Layout.fillWidth:true;enabled:!!root.service && !!root.service.preview && !root.busy;onClicked:confirmRestore.open()}
  FolderDialog {id:folderPicker;parentWindow:root.dialogWindow;title:"Choose backup folder";onAccepted:{directory.text=decodeURIComponent(String(selectedFolder).replace(/^file:\/\//,""));root.dirty=true}}
  FileDialog {id:filePicker;parentWindow:root.dialogWindow;title:"Choose StarDock backup";nameFilters:["StarDock backups (*.json)"];onAccepted:restorePath.text=decodeURIComponent(String(selectedFile).replace(/^file:\/\//,""))}
  Dialog {
    id:confirmRestore
    objectName:"confirmBackupRestore"
    parent:Overlay.overlay;anchors.centerIn:parent;modal:true
    title:"Restore the previewed backup?";width:Math.min(parent?parent.width-32:480,480);height:280
    background:Rectangle {color:root.bg;border.color:root.edge;radius:12}
    contentItem:Label {text:"This replaces the categories listed in the preview. A safety backup is saved before changes are applied. The dashboard will restart.\n\n"+(root.service && root.service.preview?root.service.preview.path:"");textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.fg}
    footer:RowLayout {
      AppButton {text:"Cancel";Layout.fillWidth:true;onClicked:confirmRestore.close()}
      AppButton {text:"Restore and restart";Layout.fillWidth:true;onClicked:{confirmRestore.close();root.service.restore()}}
    }
  }
}
