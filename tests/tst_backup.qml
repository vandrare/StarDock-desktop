import QtQuick
import QtTest
import ".."

Item {
  width:600;height:1000
  QtObject {
    id:service
    property bool ready:true
    property bool busy:false
    property string error:""
    property string message:""
    property var preview:null
    property var request:({})
    property var state:({settings:{directory:"/tmp/backups",schedule:"off",keep:10},status:{},backups:[]})
    property int restoreCount:0
    function run(value){request=value}
    function restore(){restoreCount++}
  }
  BackupSettings {id:settings;width:580;service:service;fg:"white";bg:"black";muted:"gray";accent:"cyan";edge:"gray"}
  TestCase {
    name:"BackupSettings";when:windowShown
    function test_save_preview_and_restore_guard(){
      settings.load()
      compare(findChild(settings,"backupDirectory").text,"/tmp/backups")
      compare(findChild(settings,"backupSchedule").currentIndex,0)
      settings.save()
      compare(service.request.op,"configure")
      compare(service.request.settings.keep,10)
      verify(!findChild(settings,"restoreBackup").enabled)
      var path=findChild(settings,"restoreBackupPath")
      path.text="/tmp/snapshot.json"
      findChild(settings,"previewBackup").clicked()
      compare(service.request.op,"preview")
      compare(service.request.path,path.text)
      service.preview={path:path.text,createdAt:"Today",sections:["Notes"],notes:3,calendars:0,accountPreferences:0}
      verify(findChild(settings,"restoreBackup").enabled)
      findChild(settings,"restoreBackup").clicked()
      compare(service.restoreCount,0)
      verify(findChild(settings,"confirmBackupRestore").visible)
      findChild(settings,"confirmBackupRestore").close()
      path.text="/tmp/different.json"
      compare(service.preview,null)
      verify(!findChild(settings,"restoreBackup").enabled)
      settings.dirty=true
      verify(!findChild(settings,"backupNow").enabled)
    }
  }
}
