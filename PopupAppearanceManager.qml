import QtQuick
import QtQuick.Controls.Basic
import "Config.js" as Config

Item {
  id:root
  property var target:null
  property var overlay:null
  property var extraTargets:[]
  property var appearance:({})
  property color backgroundColor
  property color borderColor
  property var styled:[]
  property var watchedLoaders:[]
  function scheduleScan(){Qt.callLater(root.scan)}
  function decorate(popup){
    if(styled.indexOf(popup)>=0)return
    var previous=popup.background
    var surface=surfaceComponent.createObject(previous?previous.parent:popup.contentItem,{implicitWidth:previous?previous.implicitWidth:0,implicitHeight:previous?previous.implicitHeight:0})
    popup.background=surface
    popup.Overlay.modal=dimmerComponent
    popup.Overlay.modeless=dimmerComponent
    styled=styled.concat([popup])
  }
  function scan(){
    styled=styled.filter(function(popup){return Qt.isQtObject(popup)})
    watchedLoaders=watchedLoaders.filter(function(loader){return Qt.isQtObject(loader)})
    var visited=[]
    function walk(node){
      if(!node || !Qt.isQtObject(node) || visited.indexOf(node)>=0)return
      visited.push(node)
      if(node.itemChanged && typeof node.itemChanged.connect==="function" && watchedLoaders.indexOf(node)<0){node.itemChanged.connect(root.scheduleScan);watchedLoaders.push(node)}
      if(typeof node.open==="function" && typeof node.close==="function" && node.background!==undefined && node.modal!==undefined)root.decorate(node)
      var lists=[node.data,node.children,node.contentData]
      for(var i=0;i<lists.length;i++){
        var list=lists[i],length=0
        // Some native append-only lists have no count function.
        try {length=list?list.length:0}catch(_error){continue}
        if(typeof length==="number")for(var j=0;j<length;j++)walk(list[j])
      }
      if(node.contentItem)walk(node.contentItem)
      if(node.item)walk(node.item)
    }
    walk(target)
    for(var i=0;i<extraTargets.length;i++)walk(extraTargets[i])
  }
  Component.onCompleted:Qt.callLater(scan)
  onTargetChanged:Qt.callLater(scan)
  onExtraTargetsChanged:Qt.callLater(scan)
  onOverlayChanged:Qt.callLater(scan)
  Connections {target:root.overlay;function onChildrenChanged(){Qt.callLater(root.scan)}}
  Component {id:surfaceComponent;PopupSurface {appearance:root.appearance;color:root.backgroundColor;border.color:root.borderColor}}
  Component {id:dimmerComponent;Rectangle {objectName:"popupDimmer";color:Qt.rgba(0,0,0,Config.popupAppearance(root.appearance).overlayOpacity/100)}}
}
