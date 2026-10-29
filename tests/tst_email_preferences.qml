import QtQuick
import QtTest
import ".."

Item {
  width:640;height:800
  QtObject {
    id:host
    property var saved:null
    function updateEntryInline(id,value){saved=value}
  }
  QtObject {
    id:service
    property var settings:({refreshIntervalSec:120,notifyNewMail:"Off",calendarWeekStart:1})
    property var backend:({ready:true})
    property var shell:host
    property string pluginId:"test"
    property bool notifyNewMail:settings.notifyNewMail!=="Off"
    property bool hasNotifications:true
    property bool alwaysShowImages:false
    property int accountCount:1
    property string notificationError:""
    function applySettings(value){settings=value}
    function setAlwaysShowImages(value){alwaysShowImages=value}
  }
  EmailPreferences {id:preferences;width:600;service:service;fg:"white";muted:"gray"}
  SignalSpy {id:signatures;target:preferences;signalName:"signaturesRequested"}
  SignalSpy {id:accounts;target:preferences;signalName:"accountsRequested"}
  SignalSpy {id:add;target:preferences;signalName:"addAccountRequested"}
  TestCase {
    name:"EmailPreferences";when:windowShown
    function test_apply_cancel_and_signature_shortcut(){
      preferences.load()
      verify(!preferences.accountsExpanded)
      findChild(preferences,"emailAccountsHeader").clicked()
      verify(preferences.accountsExpanded)
      findChild(preferences,"emailAddAccount").clicked()
      findChild(preferences,"emailAccountSettings").clicked()
      compare(add.count,1);compare(accounts.count,1)
      var interval=findChild(preferences,"emailRefreshInterval")
      var alerts=findChild(preferences,"emailNotifications")
      var images=findChild(preferences,"emailRemoteImages")
      compare(interval.value,120);verify(!alerts.checked);verify(!images.checked)
      interval.value=300;alerts.checked=true;images.checked=true
      compare(service.settings.refreshIntervalSec,120)
      verify(!service.alwaysShowImages)
      preferences.load() // Reopening after Cancel discards the unsaved draft.
      compare(interval.value,120);verify(!alerts.checked);verify(!images.checked)
      interval.value=300;alerts.checked=true;images.checked=true
      preferences.save()
      compare(host.saved.refreshIntervalSec,300)
      compare(host.saved.calendarWeekStart,1)
      compare(host.saved.notifyNewMail,"On")
      verify(service.alwaysShowImages)
      preferences.load();compare(interval.value,300)
      findChild(preferences,"emailSignatures").clicked()
      compare(signatures.count,1)
      service.accountCount=0
      verify(!findChild(preferences,"emailSignatures").enabled)
    }
  }
}
