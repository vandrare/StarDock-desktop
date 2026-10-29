import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "vendor/omamail/ui/components" as MailUi

Dialog {
  id:root
  property var service:null
  property var beforeRemove:null
  property color bg
  property color fg
  property color muted
  property color accent
  property color edge
  property string fontFamily
  property bool picker:true
  property string notice:""
  property bool signaturesFirst:false
  function openAddAccount(){picker=true;notice="";open();setup.open()}
  function openSignatures(){signaturesFirst=true;open();Qt.callLater(scrollToSignatures)}
  function scrollToSignatures(){
    if(!signaturesFirst || !settingsLoader.item)return
    function find(item){if(item.objectName==="settings-signature-section")return item;var children=item.children || [];for(var i=0;i<children.length;i++){var hit=find(children[i]);if(hit)return hit}return null}
    var target=find(settingsLoader.item)
    if(target && target.visible)scroll.contentItem.contentY=Math.max(0,Math.min(target.mapToItem(settingsLoader.item,0,0).y,scroll.contentItem.contentHeight-scroll.availableHeight))
  }
  onClosed:signaturesFirst=false
  signal calendarRequested()
  parent:Overlay.overlay;anchors.centerIn:parent;modal:true
  title:"Accounts & calendars";padding:24
  width:Math.min(parent?parent.width-32:860,860);height:Math.min(parent?parent.height-32:800,800)
  palette.windowText:fg;palette.text:fg;palette.buttonText:fg;palette.base:bg;palette.highlight:accent
  background:Rectangle {color:root.bg;border.color:root.edge;radius:12}
  function edit(index){if(!service || !service.switchToIndex(index))return;picker=false;setup.open()}
  function clientSetup(){var id=service.gmailAccountId();if(id){service.switchTo(id);picker=false}else picker=true;setup.open()}
  component DoneButton:AppButton {
    id:button
    palette.buttonText:root.fg
    background:Rectangle {implicitWidth:120;implicitHeight:40;radius:6;color:button.hovered?Qt.rgba(root.accent.r,root.accent.g,root.accent.b,.15):root.bg}
  }
  contentItem:ScrollView {
    id:scroll
    rightPadding:24;clip:true;contentWidth:availableWidth
    Loader {
      id:settingsLoader
      onLoaded:Qt.callLater(root.scrollToSignatures)
      width:scroll.availableWidth;active:root.opened
      sourceComponent:Component {
        MailUi.SettingsPage {
          readingSettingsVisible:true
          service:root.service;calendarController:root.service?root.service.calendarController:null
          textColor:root.fg;dimColor:root.muted;accentColor:root.accent;urgentColor:root.accent;panelFontFamily:root.fontFamily
          onAddRequested:{root.picker=true;setup.open()}
          onEditRequested:function(index){root.edit(index)}
          onCalendarSignInRequested:function(index){root.edit(index);Qt.callLater(function(){if(root.service)root.service.signIn()})}
          onClientSetupRequested:root.clientSetup()
          onOpenCalendarRequested:{root.close();root.calendarRequested()}
        }
      }
    }
  }
  footer:DoneButton {text:"Done";onClicked:root.close()}
  MailUi.SetupPages {
    id:pages
    service:root.service;textColor:root.fg;dimColor:root.muted;accentColor:root.accent;dangerColor:root.accent;panelFontFamily:root.fontFamily
    onChosen:function(provider){if(provider==="m365" && root.service.backend.apiVersion<8){root.notice="Microsoft 365 requires a newer backend. Use Outlook personal or another supported provider.";return}root.notice="";root.service.addAccount(provider);root.picker=false}
    onRemoveRequested:remove.open()
  }
  Dialog {
    id:setup
    parent:Overlay.overlay;anchors.centerIn:parent;modal:true
    title:root.picker?"Add an account":"Account settings";padding:24
    width:Math.min(parent.width-32,760);height:Math.min(parent.height-32,760)
    palette:root.palette
    background:Rectangle {color:root.bg;border.color:root.edge;radius:12}
    contentItem:ColumnLayout {
      Label {visible:!!root.notice;text:root.notice;color:root.accent;wrapMode:Text.Wrap;Layout.fillWidth:true}
      ScrollView {id:setupScroll;Layout.fillWidth:true;Layout.fillHeight:true;rightPadding:24;clip:true;contentWidth:availableWidth
        Loader {width:setupScroll.availableWidth;active:setup.opened;sourceComponent:pages.pageFor(root.service?root.service.providerId:"gmail",root.picker)}
      }
    }
    footer:DoneButton {text:"Done";onClicked:setup.close()}
    onClosed:if(root.service)root.service.discardCurrentDraft()
  }
  Dialog {
    id:remove
    parent:Overlay.overlay;anchors.centerIn:parent;modal:true
    title:"Remove this account?";width:Math.min(460,parent?parent.width-32:460);height:220
    property string accountId:""
    property bool removing:false
    closePolicy:removing?Popup.NoAutoClose:Popup.CloseOnEscape
    onOpened:{root.notice="";removing=false;accountId=root.service.accountList.accounts[root.service.editingIndex()].id || ""}
    background:Rectangle {color:root.bg;border.color:root.edge;radius:12}
    contentItem:Label {text:"Remove this account from the dashboard? Server messages and events are kept. Any open mail draft will be saved first."+(root.notice?"\n\n"+root.notice:"");wrapMode:Text.Wrap;color:root.fg}
    footer:RowLayout {
      DoneButton {text:"Cancel";enabled:!remove.removing;onClicked:remove.close()}
      DoneButton {text:"Remove";enabled:!remove.removing;onClicked:{
        remove.removing=true
        var id=remove.accountId
        function finish(ok){remove.removing=false;if(!ok){root.notice="Could not save the mail draft. Account kept.";return}if(id)root.service.removeAccount(id);else root.service.discardCurrentDraft();remove.close();setup.close()}
        if(root.beforeRemove)root.beforeRemove(finish);else finish(true)
      }}
    }
  }
}
