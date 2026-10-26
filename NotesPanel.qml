import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

RowLayout {
  id: root
  property var notes: []
  property int selectedIndex: 0
  property Component heading
  property color bg
  property color fg
  property color accent
  property color edge
  property color muted
  property real textScale: 1
  readonly property bool hasSelection: selectedIndex>=0 && selectedIndex<notes.length
  readonly property var selectedNote: hasSelection ? notes[selectedIndex] : ({title:"",body:""})
  signal edited(var entries)
  spacing: 16
  function update(key,value) {
    if(!hasSelection || selectedNote[key]===value)return
    var entries=notes.slice()
    var note={title:selectedNote.title,body:selectedNote.body,updated:Date.now()}
    note[key]=value; entries[selectedIndex]=note
    root.edited(entries)
  }
  ColumnLayout {
    Layout.fillWidth: true; Layout.fillHeight: true
    Layout.preferredWidth: (root.width-root.spacing)*.25
    Layout.minimumWidth: 0
    spacing: 12
    Loader { sourceComponent: root.heading; Layout.fillWidth: true }
    ScrollView {
      id: titlesScroll
      objectName: "noteTitlesScroll"
      Layout.fillWidth: true; Layout.fillHeight: true
      rightPadding: 24; clip: true; contentWidth: availableWidth
      ListView {
        id: titles
        objectName: "noteTitles"
        model: root.notes
        currentIndex: root.selectedIndex
        spacing: 6
        delegate: AppButton {
          id: noteTitleButton
          required property var modelData
          required property int index
          width: titles.width
          text: modelData.title.trim() || "Untitled note"
          checked: index===root.selectedIndex
          palette.buttonText: checked ? root.accent : root.fg
          background: Rectangle {
            radius: 6
            color: noteTitleButton.checked || noteTitleButton.hovered ? Qt.rgba(root.accent.r,root.accent.g,root.accent.b,.15) : "transparent"
            border.color: noteTitleButton.activeFocus ? root.accent : "transparent"
          }
          onClicked: root.selectedIndex=index
          ToolTip.visible: hovered; ToolTip.text: text
        }
      }
    }
  }
  ColumnLayout {
    Layout.fillWidth: true; Layout.fillHeight: true
    Layout.preferredWidth: (root.width-root.spacing)*.75
    Layout.minimumWidth: 0
    spacing: 12
    RowLayout {
      Layout.fillWidth: true
      TextField {
        id: titleField
        objectName: "noteTitle"
        Layout.fillWidth: true; Layout.minimumWidth: 0
        enabled: root.hasSelection
        text: root.selectedNote.title
        placeholderText: "Note title"
        color: root.fg; selectByMouse: true
        font.pixelSize: 16*root.textScale
        background: Rectangle { radius: 8; color: root.bg; border.color: root.edge }
        onTextEdited: root.update("title",text)
      }
    AppButton {
      objectName: "newNoteButton"; text: "+ New"
      onClicked: { var entries=root.notes.slice(); entries.push({title:"Untitled note",body:"",updated:Date.now()}); root.edited(entries); root.selectedIndex=entries.length-1; titleField.forceActiveFocus(); titleField.selectAll() }
    }
      AppButton {
        objectName: "deleteNoteButton"; text: "Delete"; enabled: root.hasSelection
        onClicked: { var entries=root.notes.slice(); entries.splice(root.selectedIndex,1); root.edited(entries); root.selectedIndex=Math.max(0,Math.min(root.selectedIndex,entries.length-1)) }
      }
    }
    ScrollView {
      id: contentScroll
      objectName: "noteContentScroll"
      Layout.fillWidth: true; Layout.fillHeight: true
      clip: true; rightPadding: 24
      TextArea {
        objectName: "scratchpad"
        width: contentScroll.availableWidth
        height: Math.max(implicitHeight,contentScroll.availableHeight)
        enabled: root.hasSelection
        text: root.selectedNote.body
        placeholderText: root.hasSelection ? "Write your note…" : "Create a note to get started"
        color: root.fg; selectionColor: root.accent; selectedTextColor: root.bg
        font.pixelSize: 14*root.textScale
        wrapMode: TextEdit.Wrap; textFormat: TextEdit.PlainText
        selectByMouse: true; padding: 16
        background: Rectangle { radius: 10; color: root.bg; border.color: root.edge }
        onTextChanged: root.update("body",text)
      }
    }
  }
}
