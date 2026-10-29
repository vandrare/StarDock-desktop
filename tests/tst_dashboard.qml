import QtQuick
import QtQuick.Controls.Basic
import QtTest
import ".."
import "../ArticleText.js" as ArticleText
import "../CalendarPreferences.js" as CalendarPreferences
import "../Config.js" as Config
import "../Overview.js" as Overview
Item {
  id: harness
  width: 1320; height: 940
  Dashboard { id: dashboard; anchors.fill: parent }
  Popup {id:externalPopup;parent:Overlay.overlay;modal:true;width:200;height:100}
  Loader {
    id:latePopupLoader;active:false
    sourceComponent:Component {Item {property alias popup:latePopup;Popup {id:latePopup;modal:true;width:200;height:100}}}
  }
  property int mailFlushCount:0
  property int emailSettingsSaves:0
  Component {
    id:emailSettingsProbe
    Item {
      function load(){}
      function save(){harness.emailSettingsSaves++}
    }
  }
  Component {
    id:mailProbe
    Item {
      objectName:"mailModuleProbe"
      property string draftText:""
      property bool flushSucceeds:true
      function flushDrafts(done) {harness.mailFlushCount++;done(flushSucceeds)}
    }
  }
  Component {
    id:calendarProbe
    Item {
      objectName:"calendarModuleProbe"
      property var opened:null
      property bool needsExitReview:false
      property bool leaveAllowed:true
      function requestLeave(done){done(leaveAllowed)}
      function openEvent(event){opened=event}
    }
  }
  SignalSpy { id: closeSpy; target: dashboard; signalName: "closeRequested" }
  TextEdit { id: clipboard; visible: false }
  Text { id: referenceText; visible: false; wrapMode: Text.Wrap; textFormat: Text.StyledText; lineHeight: 1.45 }
  TestCase {
    name: "Dashboard"
    when: windowShown
    function init() {
      harness.width=1320; harness.height=940
      dashboard.popupStyleExtras=[]
      latePopupLoader.active=false
      dashboard.configuration = {colors: {}, textScale: 1, mainPanel: "overview"}
      dashboard.focusedPanel = "overview"
      dashboard.slots = ["weather", "calendar", "notes"]
      dashboard.demoNote = "Session note"
      dashboard.notesData=[{title:"First note",body:"Session note"}]
      dashboard.notesSelection=0
      dashboard.mailService=null
      dashboard.emailPanelComponent=null
      dashboard.calendarPanelComponent=null
      dashboard.accountPreferencesFlush=null
      dashboard.emailSettingsComponent=null
      harness.emailSettingsSaves=0
      dashboard.calendarSettingsComponent=null
      dashboard.accountSettingsError=""
      dashboard.calendarEvents=[]
      harness.mailFlushCount=0
      dashboard.availableScreenWidth=1920
      var stories=[]
      for (var i=0;i<10;i++) stories.push({title:"Story "+i,body:"Summary "+i,published:"2026-10-24T12:00:00Z",publisher:"Test feed",url:"https://example.com/"+i})
      dashboard.headlines = stories
      closeSpy.clear()
    }
    function test_overview_order_visibility_and_note_navigation() {
      dashboard.notesData=[{title:"Real note",body:"First line\nSecond line",updated:1}]
      dashboard.configuration={colors:{},overview:{order:["notes","weather","calendar","email"],hidden:["calendar"]}}
      wait(30)
      var panel=findChild(dashboard,"liveOverview")
      compare(panel.sections.join(","),"notes,weather")
      compare(panel.rows("notes")[0].detail,"First line")
      mouseClick(findChild(dashboard,"overviewRow_notes_0"))
      compare(dashboard.focusedPanel,"notes");compare(dashboard.notesSelection,0)
      dashboard.promote(dashboard.slots.indexOf("overview"))
      wait(30);panel=findChild(dashboard,"liveOverview")
      compare(panel.sections.join(","),"notes,weather")
      var normalized=Config.overview({order:["notes","notes","invalid"],hidden:["invalid","email","email"]})
      compare(normalized.order.join(","),"notes,weather,calendar,email")
      compare(normalized.hidden.join(","),"email")
    }
    function test_overview_live_weather_mail_and_responsive_cards() {
      dashboard.configuration={colors:{},enabledModules:["overview","weather","notes","email"]}
      dashboard.weatherData={location:"Test location",current:{temperature:72,probability:10,code:0},units:{temperature:"°F"},alerts:{items:[{title:"Weather notice",headline:"Synthetic alert detail"}]}}
      dashboard.notesData=[{title:"Shopping list",body:"Coffee and bread",updated:1},{title:"Ideas",body:"A useful thought",updated:2}]
      var called={account:"",message:""}
      dashboard.mailService={hasSavedAccounts:true,unreadTotal:2,barMessages:[{id:"mail-1",accountId:"account-1",subject:"Synthetic overview email",from:{display:"Test sender"}}],switchTo:function(id){called.account=id},select:function(id){called.message=id}}
      wait(30)
      var panel=findChild(dashboard,"liveOverview")
      compare(panel.rows("weather")[0].detail,"Synthetic alert detail")
      compare(panel.rows("email")[0].messageId,"mail-1")
      grabImage(dashboard).save("/tmp/starlink-live-overview.png")
      mouseClick(findChild(dashboard,"overviewRow_email_0"))
      compare(dashboard.focusedPanel,"email");wait(20)
      compare(called.account,"account-1");compare(called.message,"mail-1")
      dashboard.promote(dashboard.slots.indexOf("overview"));harness.width=760;wait(30)
      panel=findChild(dashboard,"liveOverview");compare(panel.columns,1)
      verify(findChild(dashboard,"overviewCard_weather").width<=panel.width+1)
      dashboard.mailService=null
    }
    function test_overview_schedule_includes_ongoing_events_and_next_appointment() {
      var now=new Date(2026,9,26,12).getTime()
      var values=[{summary:"Tomorrow",start:{ms:now+86400000},end:{ms:now+90000000}},{summary:"Ongoing",start:{ms:now-3600000},end:{ms:now+3600000}},{summary:"Finished",start:{ms:now-7200000},end:{ms:now-3600000}}]
      compare(Overview.eventsToday(values,now).length,2)
      compare(Overview.nextEvent(values,now).summary,"Ongoing")
      dashboard.calendarPanelComponent=calendarProbe
      dashboard.calendarEvents=values;dashboard.clockNow=new Date(now)
      wait(30)
      var button=findChild(dashboard,"overviewNextEvent")
      verify(button.visible);mouseClick(button)
      compare(dashboard.focusedPanel,"calendar")
      wait(30);compare(findChild(dashboard,"calendarModuleProbe").opened.summary,"Ongoing")
      dashboard.clockNow=new Date()
    }
    function test_overview_settings_draft_and_saved_configuration() {
      mouseClick(findChild(dashboard,"settingsButton"));wait(20)
      var editor=findChild(dashboard,"settingsEditor")
      var draft=findChild(dashboard,"overviewDraft")
      draft.move(3,0,1);draft.setProperty(0,"shown",false)
      editor.applyRequested({},1,undefined,33,undefined,undefined,36,dashboard.enabledModules,editor.overviewOptions(),33,{}, {})
      compare(dashboard.configuration.overview.order[0],"notes")
      compare(dashboard.configuration.overview.hidden[0],"notes")
      dashboard.openSettings();wait(20)
      compare(findChild(dashboard,"overviewAccordion").expanded,false)
      compare(draft.get(0).moduleKey,"notes");verify(!draft.get(0).shown)
      editor.canceled()
    }
    function test_account_preference_save_must_finish_before_configuration_changes() {
      var pending=null
      dashboard.accountPreferencesFlush=function(done){pending=done}
      dashboard.updateConfiguration({accent:"#123456"},1)
      compare(dashboard.configuration.colors.accent,undefined)
      pending(true)
      compare(dashboard.configuration.colors.accent,"#123456")
      dashboard.accountPreferencesFlush=null
    }
    function test_calendar_preferences_normalization() {
      var value=CalendarPreferences.normalize({calendarDefaultView:"invalid",calendarWeekStart:0,calendarDuration:99999,calendarSnoozeMinutes:-10,calendarTimeFormat:"24",calendarTimeZone:"America/Phoenix"})
      compare(value.calendarDefaultView,"month");compare(value.calendarWeekStart,0)
      compare(value.calendarDuration,1440);compare(value.calendarSnoozeMinutes,1)
      compare(value.calendarTimeFormat,"24");compare(value.calendarTimeZone,"America/Phoenix")
      compare(CalendarPreferences.normalize({calendarTimeZone:"bad\nzone"}).calendarTimeZone,"")
    }
    function test_calendar_disable_retains_unsaved_editor_until_approved() {
      dashboard.calendarPanelComponent=calendarProbe
      wait(20)
      var panel=findChild(dashboard,"calendarModuleProbe")
      panel.needsExitReview=true;panel.leaveAllowed=false
      dashboard.updateConfiguration({},1,undefined,undefined,undefined,undefined,undefined,["overview","weather","notes"])
      verify(dashboard.enabledModules.indexOf("calendar")>=0)
      compare(dashboard.focusedPanel,"calendar")
      compare(findChild(dashboard,"calendarModuleProbe"),panel)
      panel.leaveAllowed=true
      dashboard.updateConfiguration({},1,undefined,undefined,undefined,undefined,undefined,["overview","weather","notes"])
      verify(dashboard.enabledModules.indexOf("calendar")<0)
      wait(20)
      verify(findChild(dashboard,"calendarModuleProbe")===null)
    }
    function test_calendar_summary_filters_sorts_and_opens_without_email() {
      var now=Date.now()
      dashboard.calendarPanelComponent=calendarProbe
      dashboard.calendarEvents=[
        {summary:"Later",start:{ms:now+5000},end:{ms:now+6000}},
        {summary:"Ended",start:{ms:now-5000},end:{ms:now-1000}},
        {summary:"Ongoing",start:{ms:now-5000},end:{ms:now+1000}},
        {summary:"Soon",start:{ms:now+2000},end:{ms:now+3000}},
        {summary:"Fourth",start:{ms:now+8000},end:{ms:now+9000}}]
      compare(dashboard.calendarPreviews.length,3)
      compare(dashboard.calendarPreviews[0].summary,"Ongoing")
      compare(dashboard.calendarPreviews[1].summary,"Soon")
      verify(dashboard.enabledModules.indexOf("email")<0)
      tryVerify(function(){return findChild(dashboard,"calendarPreview1")!==null})
      var preview=findChild(dashboard,"calendarPreview1")
      verify(preview!==null)
      mouseClick(preview)
      compare(dashboard.focusedPanel,"calendar")
      wait(30)
      var panel=findChild(dashboard,"calendarModuleProbe")
      compare(panel.opened.summary,"Soon")
      dashboard.promote(dashboard.slots.indexOf("notes"))
      compare(findChild(dashboard,"calendarModuleProbe"),panel)
    }
    function test_module_selection_limits_layout_and_email() {
      mouseClick(findChild(dashboard,"settingsButton"))
      var dialog=findChild(dashboard,"settingsDialog")
      tryCompare(dialog,"visible",true)
      var section=findChild(dashboard,"modulesAccordion")
      compare(section.expanded,false)
      mouseClick(findChild(dashboard,"modulesAccordionHeader"))
      wait(30)
      var switches=findChild(dashboard,"moduleRepeater")
      var email=switches.itemAt(4)
      verify(!email.checked)
      verify(!email.enabled)
      mouseClick(switches.itemAt(0))
      verify(!switches.itemAt(1).enabled)
      verify(email.enabled)
      mouseClick(findChild(dashboard,"applySettings"))
      compare(dashboard.enabledModules.length,3)
      compare(dashboard.slots.length,2)
      compare(dashboard.focusedPanel,"weather")
      wait(30)
      verify(findChild(dashboard,"summary2")===null)
      var first=findChild(dashboard,"summary0")
      var second=findChild(dashboard,"summary1")
      verify(Math.abs(first.height-second.height)<=1,"Heights "+first.height+" / "+second.height)
      mouseClick(findChild(dashboard,"settingsButton"))
      tryCompare(dialog,"visible",true)
      mouseClick(findChild(dashboard,"modulesAccordionHeader"))
      mouseClick(switches.itemAt(4))
      mouseClick(findChild(dashboard,"applySettings"))
      compare(dashboard.enabledModules.length,4)
      verify(dashboard.enabledModules.indexOf("email")>=0)
      dashboard.promote(dashboard.slots.indexOf("email"))
      compare(dashboard.focusedPanel,"email")
      dashboard.updateConfiguration({},1)
      verify(dashboard.configuration.enabledModules.indexOf("email")>=0)
      compare(dashboard.slots.length,3)
    }
    function test_notification_navigation_keeps_message_account_ownership() {
      dashboard.configuration={colors:{},enabledModules:["weather","notes","email"]}
      var calls=[]
      var mail={activeAccountId:"first",switchTo:function(id){if(id==="removed")return false;this.activeAccountId=id;return true},select:function(id){calls.push({account:this.activeAccountId,message:id})}}
      dashboard.mailService=mail
      dashboard.openMail("first","first-message")
      dashboard.openMail("second","second-message")
      wait(20)
      compare(calls.length,1)
      compare(calls[0].account,"second")
      compare(calls[0].message,"second-message")
      dashboard.openMail("removed","must-not-open")
      wait(20)
      compare(calls.length,1)
    }
    function test_email_preview_opens_message_in_email_panel() {
      dashboard.configuration={colors:{},enabledModules:["overview","weather","notes","email"]}
      var called={account:"",message:""}
      dashboard.mailService={unreadTotal:2,barMessages:[{id:"mail-1",accountId:"account-1",subject:"Inbox message",unread:true,from:{display:"Sender"}}],switchTo:function(id){called.account=id},select:function(id){called.message=id}}
      wait(30)
      compare(dashboard.mailPreviews.length,1)
      findChild(dashboard,"mailPreview0").clicked()
      compare(dashboard.focusedPanel,"email")
      compare(called.account,"account-1")
      wait(20)
      compare(called.message,"mail-1")
      verify(dashboard.slots.indexOf("email")<0)
      dashboard.mailService=null
    }
    function test_mail_editor_survives_module_swaps_and_flushes_on_disable() {
      dashboard.emailPanelComponent=mailProbe
      dashboard.configuration={colors:{},enabledModules:["weather","notes","email"]}
      dashboard.promote(dashboard.slots.indexOf("email"))
      wait(30)
      var editor=findChild(dashboard,"mailModuleProbe")
      verify(editor!==null)
      editor.draftText="Unfinished draft"
      dashboard.promote(dashboard.slots.indexOf("weather"))
      wait(20)
      compare(findChild(dashboard,"mailModuleProbe"),editor)
      compare(editor.draftText,"Unfinished draft")
      dashboard.promote(dashboard.slots.indexOf("email"))
      compare(editor.draftText,"Unfinished draft")
      editor.flushSucceeds=false
      dashboard.updateConfiguration({},1,undefined,undefined,undefined,undefined,undefined,["overview","weather","notes"])
      compare(harness.mailFlushCount,1)
      verify(dashboard.enabledModules.indexOf("email")>=0)
      compare(editor.draftText,"Unfinished draft")
      editor.flushSucceeds=true
      dashboard.updateConfiguration({},1,undefined,undefined,undefined,undefined,undefined,["overview","weather","notes"])
      compare(harness.mailFlushCount,2)
      compare(dashboard.enabledModules.indexOf("email"),-1)
      wait(20)
      verify(findChild(dashboard,"mailModuleProbe")===null)
      dashboard.emailPanelComponent=null
      dashboard.calendarPanelComponent=null
      dashboard.accountPreferencesFlush=null
      dashboard.calendarSettingsComponent=null
      dashboard.accountSettingsError=""
      dashboard.calendarEvents=[]
    }
    function test_panel_swap() {
      mouseClick(findChild(dashboard, "summary0"))
      compare(dashboard.focusedPanel, "weather")
      compare(dashboard.slots[0], "overview")
      mouseClick(findChild(dashboard, "summary0"))
      compare(dashboard.focusedPanel, "overview")
      compare(dashboard.slots[0], "weather")
    }
    function test_title_clock_formats_and_saved_settings() {
      dashboard.clockNow=new Date(2026,9,25,13,5)
      var clock=findChild(dashboard,"titleClock")
      compare(clock.text,"1:05 PM · Oct 25, 2026")
      compare(clock.font.pixelSize,dashboard.sectionTitleSize)
      compare(clock.maximumLineCount,1)
      verify(Math.abs(clock.mapToItem(dashboard,clock.width/2,0).x-dashboard.width/2)<1)
      mouseClick(findChild(dashboard,"settingsButton"))
      tryCompare(findChild(dashboard,"settingsDialog"),"visible",true)
      findChild(dashboard,"clockHourFormat").currentIndex=1
      findChild(dashboard,"clockDateFormat").currentIndex=4
      mouseClick(findChild(dashboard,"applySettings"))
      compare(dashboard.configuration.clock.hourFormat,"24")
      compare(dashboard.configuration.clock.dateFormat,"yyyy-MM-dd")
      dashboard.clockNow=new Date(2026,9,25,13,5)
      compare(clock.text,"13:05 · 2026-10-25")
      dashboard.updateConfiguration({},1)
      compare(dashboard.configuration.clock.hourFormat,"24")
    }
    function test_weather_forecast_layout_and_settings() {
      var days=[]
      for(var i=0;i<7;i++) days.push({date:"2026-10-"+(24+i),high:80,low:60,code:0,probability:10,precipitation:0})
      dashboard.weatherData={location:"Phoenix",current:{temperature:75,code:0},units:{temperature:"°F",wind:"mph",precipitation:"in"},daily:days,alerts:{items:[],error:""}}
      dashboard.promote(0)
      wait(50)
      var left=findChild(dashboard,"weatherConditions")
      var right=findChild(dashboard,"weatherRadar")
      verify(left!==null && right!==null)
      verify(Math.abs(right.width/left.width-3)<0.15,"Weather columns should use a 25/75 split")
      compare(findChild(dashboard,"weatherForecast").count,7)
      mouseClick(findChild(dashboard,"settingsButton"))
      tryCompare(findChild(dashboard,"settingsDialog"),"visible",true)
      compare(findChild(dashboard,"weatherAccordion").expanded,false)
      var editor=findChild(dashboard,"weatherSettings")
      dashboard.locationResults=[{location:"Paris, France",latitude:48.85,longitude:2.35,countryCode:"FR"}]
      wait(20)
      findChild(dashboard,"weatherLocationResults").activated(0)
      findChild(dashboard,"weatherTemperatureUnit").currentIndex=1
      findChild(dashboard,"weatherMeasurementUnits").currentIndex=1
      compare(editor.draft().latitude,48.85)
      mouseClick(findChild(dashboard,"applySettings"))
      compare(dashboard.configuration.weather.location,"Paris, France")
      compare(dashboard.configuration.weather.temperatureUnit,"celsius")
      compare(dashboard.configuration.weather.units,"metric")
      dashboard.locationResults=[]
    }
    function test_weather_radar_playback_and_top_alignment() {
      dashboard.weatherData={units:{temperature:"°F",wind:"mph",precipitation:"in"},current:{temperature:75},daily:[],alerts:{items:[],error:""},map:{width:768,height:512,tiles:[],frames:[{url:"",time:"2026-10-25T16:00:00Z"},{url:"",time:"2026-10-25T16:06:00Z"}],zoom:7}}
      dashboard.promote(0)
      wait(30)
      var left=findChild(dashboard,"weatherConditions")
      var map=findChild(dashboard,"weatherMap")
      verify(Math.abs(map.mapToItem(dashboard,0,0).y-left.mapToItem(dashboard,0,0).y)<1,"Map should align with the top of the conditions column")
      dashboard.fullscreenMode=false
      wait(20)
      var normalHeight=map.height
      dashboard.fullscreenMode=true
      wait(20)
      verify(Math.abs(map.height-normalHeight*1.25)<1)
      dashboard.fullscreenMode=false
      compare(String(findChild(dashboard,"radarPlayPause").palette.button),String(dashboard.bg))
      var timer=findChild(dashboard,"radarPlaybackTimer")
      var panel=timer.parent
      verify(timer.running)
      var index=panel.frameIndex
      tryVerify(function(){return panel.frameIndex!==index},1000)
      findChild(dashboard,"radarPlayPause").clicked()
      compare(panel.playing,false)
      index=panel.frameIndex
      wait(750)
      compare(panel.frameIndex,index)
      var speed=findChild(dashboard,"radarPlaybackSpeed")
      speed.currentIndex=2; speed.activated(2)
      compare(timer.interval,350)
      findChild(dashboard,"radarPlayPause").clicked()
      verify(timer.running)
      verify(findChild(dashboard,"radarFrameTime").text.indexOf("local")>=0)
    }
    function test_note_preview_opens_selected_note() {
      dashboard.notesData=[{title:"Older",body:"Old first\nSecond",updated:1},{title:"Newest",body:"Preview first\nNot in preview",updated:4},{title:"Third",body:"Third first",updated:2},{title:"Second",body:"Second first",updated:3}]
      wait(30)
      compare(dashboard.recentNotes.length,3)
      compare(dashboard.recentNotes[0].title,"Newest")
      compare(dashboard.recentNotes[0].firstLine,"Preview first")
      findChild(dashboard,"notePreview1").clicked()
      compare(dashboard.focusedPanel,"notes")
      compare(dashboard.notesSelection,3)
      wait(20)
      compare(findChild(dashboard,"noteTitle").text,"Second")
      compare(findChild(dashboard,"scratchpad").text,"Second first")
    }
    function test_notes_create_edit_switch_delete_and_fill() {
      dashboard.promote(2)
      wait(30)
      var titles=findChild(dashboard,"noteTitles")
      compare(findChild(dashboard,"noteTitlesScroll").rightPadding,24)
      findChild(dashboard,"newNoteButton").clicked()
      wait(20)
      compare(dashboard.notesData.length,2)
      var title=findChild(dashboard,"noteTitle")
      clipboard.text="Recipe"; clipboard.selectAll(); clipboard.copy()
      title.forceActiveFocus(); title.selectAll(); title.paste()
      var pad=findChild(dashboard,"scratchpad")
      clipboard.text="First line\n\nThird line"; clipboard.selectAll(); clipboard.copy()
      pad.forceActiveFocus(); pad.selectAll(); pad.paste()
      compare(dashboard.notesData[1].title,"Recipe")
      compare(dashboard.notesData[1].body,"First line\n\nThird line")
      titles.itemAtIndex(0).clicked()
      compare(pad.text,"Session note")
      titles.itemAtIndex(1).clicked()
      compare(pad.text,"First line\n\nThird line")
      var scroll=findChild(dashboard,"noteContentScroll")
      verify(pad.height>=scroll.availableHeight)
      findChild(dashboard,"deleteNoteButton").clicked()
      compare(dashboard.notesData.length,1)
      compare(pad.text,"Session note")
      findChild(dashboard,"deleteNoteButton").clicked()
      compare(dashboard.notesData.length,0)
      verify(!findChild(dashboard,"deleteNoteButton").enabled)
      findChild(dashboard,"newNoteButton").clicked()
      compare(dashboard.notesData.length,1)
    }
    function test_all_modules_and_state() {
      dashboard.promote(2)
      compare(dashboard.focusedPanel, "notes")
      wait(20)
      var pad = findChild(dashboard, "scratchpad")
      verify(pad !== null)
      pad.text = "A thought worth keeping"
      dashboard.promote(0)
      dashboard.promote(0)
      wait(20)
      compare(findChild(dashboard, "scratchpad").text, "A thought worth keeping")
      dashboard.promote(1)
      compare(dashboard.focusedPanel, "calendar")
    }
    function test_theme_and_overrides() {
      dashboard.themeAccent = "#112233"
      compare(String(dashboard.accent), "#112233")
      dashboard.updateConfiguration({accent: "#abcdef"}, 1.2)
      compare(String(dashboard.accent), "#abcdef")
      dashboard.themeAccent = "#334455"
      compare(String(dashboard.accent), "#abcdef")
      dashboard.updateConfiguration({}, 1)
      compare(String(dashboard.accent), "#334455")
    }
    function fontControl(key,name) {
      var repeater=findChild(dashboard,"fontSizeRepeater")
      function find(item){if(item.objectName===name)return item;var children=item.children || [];for(var i=0;i<children.length;i++){var hit=find(children[i]);if(hit)return hit}return null}
      for(var i=0;i<repeater.count;i++)if(repeater.itemAt(i).modelData.key===key)return find(repeater.itemAt(i))
      return null
    }
    function test_global_popup_style_controls_and_overlay() {
      compare(Config.popupAppearance({}).shadowSize,20)
      compare(Config.popupAppearance({shadowSize:90,overlayOpacity:-5}).shadowSize,64)
      compare(Config.popupAppearance({overlayOpacity:-5}).overlayOpacity,0)
      dashboard.openSettings();wait(20)
      var settings=findChild(dashboard,"settingsDialog")
      compare(settings.background.settings.shadowSize,20)
      var size=findChild(dashboard,"popupShadowSize")
      var color=findChild(dashboard,"popupShadowColor")
      var opacity=findChild(dashboard,"popupOverlayOpacity")
      size.value=32;color.text="#334455";opacity.value=60
      compare(findChild(dashboard,"popupShadowPreview").settings.shadowSize,32)
      compare(dashboard.popupAppearance.shadowSize,20)
      settings.close()
      dashboard.openSettings();wait(20)
      compare(size.value,20);compare(color.text,"#000000");compare(opacity.value,35)
      size.value=32;color.text="#334455";opacity.value=60
      findChild(dashboard,"applySettings").clicked()
      compare(dashboard.configuration.popupAppearance.shadowSize,32)
      compare(dashboard.popupAppearance.overlayOpacity,60)
      mouseClick(findChild(dashboard,"aboutButton"));wait(30)
      var about=findChild(dashboard,"aboutDialog")
      compare(about.background.settings.shadowSize,32)
      compare(about.background.settings.shadowColor,"#334455")
      compare(about.background.radius,16)
      var dimmer=findChild(dashboard.Overlay.overlay,"popupDimmer")
      verify(dimmer!==null,"App dialogs should use the shared backdrop")
      verify(Math.abs(dimmer.color.a-.6)<.01)
      about.close()
      dashboard.popupStyleExtras=[externalPopup,latePopupLoader]
      wait(20)
      externalPopup.open();wait(20)
      compare(externalPopup.background.settings.shadowSize,32)
      externalPopup.close()
      latePopupLoader.active=true;wait(20)
      compare(latePopupLoader.item.popup.background.settings.shadowSize,32)
      dashboard.configuration=Object.assign({},dashboard.configuration,{popupAppearance:{shadowSize:0,overlayOpacity:0}})
      dashboard.openArticle(0);wait(20)
      var article=findChild(dashboard,"articleDialog")
      verify(!article.background.layer.enabled)
      compare(article.background.settings.overlayOpacity,0)
      article.close()
    }
    function test_content_font_defaults_previews_apply_and_cancel() {
      compare(Config.fontSizes({}).emailBody,14)
      compare(Config.fontSizes({}).notesBody,14)
      compare(Config.fontSizes({}).summaries,12)
      compare(Config.fontSizes({}).rssBody,14)
      compare(Config.fontSizes({}).rssHeadline,15)
      compare(Config.fontSizes({emailBody:99,summaries:1,rssHeadline:1}).emailBody,24)
      compare(Config.fontSizes({summaries:1}).summaries,10)
      compare(Config.fontSizes({rssHeadline:1}).rssHeadline,12)
      dashboard.openSettings();wait(20)
      var editor=findChild(dashboard,"settingsEditor")
      var size=fontControl("notesBody","fontSize_notesBody")
      var defaults=fontControl("notesBody","fontDefault_notesBody")
      verify(defaults.checked && !size.enabled)
      defaults.toggle();defaults.toggled()
      for(var i=0;i<6;i++)size.increase();size.valueModified()
      compare(fontControl("notesBody","fontPreview_notesBody").font.pixelSize,20)
      compare(dashboard.fontSizes.notesBody,14)
      findChild(dashboard,"settingsDialog").close()
      dashboard.openSettings();wait(20)
      verify(defaults.checked);compare(size.value,14)
      defaults.toggle();defaults.toggled();for(var i=0;i<6;i++)size.increase();size.valueModified()
      editor.updateFont("summaries",16)
      editor.updateFont("rssBody",18)
      editor.updateFont("rssHeadline",20)
      findChild(dashboard,"applySettings").clicked()
      compare(dashboard.configuration.fontSizes.notesBody,20)
      compare(dashboard.fontSizes.summaries,16)
      dashboard.promote(dashboard.slots.indexOf("notes"));wait(20)
      compare(findChild(dashboard,"scratchpad").font.pixelSize,20)
      compare(findChild(dashboard,"summaryTitle0").font.pixelSize,16)
      compare(findChild(dashboard,"rssHeadline0").font.pixelSize,20)
      dashboard.openArticle(0);wait(20)
      compare(findChild(dashboard,"articleBody").font.pixelSize,18)
      findChild(dashboard,"articleDialog").close()
      dashboard.openSettings();wait(20)
      defaults.toggle();defaults.toggled()
      findChild(dashboard,"applySettings").clicked()
      compare(dashboard.fontSizes.notesBody,14)
      verify(dashboard.configuration.fontSizes.notesBody===undefined)
      var settings=dashboard.configuration
      settings=Object.assign({},settings,{textScale:1.5})
      dashboard.configuration=settings;wait(20)
      compare(findChild(dashboard,"scratchpad").font.pixelSize,21)
    }
    function test_fullscreen_sidebar_width_and_rss_space() {
      dashboard.fullscreenMode=true
      var main=findChild(dashboard,"mainPanel")
      var side=findChild(dashboard,"summaryColumn")
      var feed=findChild(dashboard,"rssFeed")
      for(var i=0;i<2;i++){
        var percent=i===0?20:35
        dashboard.configuration={colors:{},sidebarWidthPercent:percent,rss:{enabled:true}}
        wait(30)
        verify(Math.abs(side.width/(side.width+main.width)*100-percent)<1,"Summary column should use the saved percentage")
      }
      var previousHeight=main.height
      dashboard.configuration={colors:{},sidebarWidthPercent:25,rss:{enabled:false}}
      wait(30)
      verify(!feed.visible)
      verify(main.height>previousHeight+150,"Panels must reclaim RSS space")
      verify(!findChild(dashboard,"newsScrollTimer").running)
      dashboard.openSettings();wait(20)
      var editor=findChild(dashboard,"settingsEditor")
      var rssSwitch=findChild(dashboard,"moduleSwitch_rss")
      verify(!rssSwitch.checked)
      compare(editor.moduleDraft.length,4)
      var slider=findChild(dashboard,"sidebarWidthPercent")
      compare(slider.from,20);compare(slider.to,35);compare(slider.value,25)
      slider.value=30;rssSwitch.checked=true;rssSwitch.toggled()
      findChild(dashboard,"applySettings").clicked()
      compare(dashboard.configuration.sidebarWidthPercent,30)
      verify(dashboard.configuration.rss.enabled)
      dashboard.fullscreenMode=false
    }
    function test_footer_spacing_and_article_shadow() {
      wait(30)
      var footer=findChild(dashboard,"dashboardFooter")
      var text=findChild(dashboard,"appFooter")
      var feed=findChild(dashboard,"rssFeed")
      var top=text.mapToItem(dashboard,0,0).y-feed.mapToItem(dashboard,0,feed.height).y
      var bottom=dashboard.height-text.mapToItem(dashboard,0,text.height).y
      verify(Math.abs(top-bottom)<2,"Footer should have equal space above and below its text")
      dashboard.openArticle(0)
      var popup=findChild(dashboard,"articleDialog")
      verify(popup.dropShadow && popup.background.layer.enabled)
      popup.close()
      compare(Config.sidebarWidth(-10),20);compare(Config.sidebarWidth(90),35);compare(Config.sidebarWidth(undefined),33)
    }
    function test_responsive_layout() {
      harness.width = 1320; harness.height = 940
      wait(20)
      verify(!dashboard.narrow)
      var main = findChild(dashboard, "mainPanel")
      var card = findChild(dashboard, "summary0")
      verify(main.width > card.width * 1.7)
      harness.width = 700; harness.height = 900
      wait(20)
      verify(dashboard.narrow)
      verify(findChild(dashboard, "rssFeed").y > main.y)
      verify(main.width > 600)
      harness.width = 918; harness.height = 478
      wait(20)
      var lastCard = findChild(dashboard,"summary2")
      var newsPanel = findChild(dashboard,"rssFeed")
      verify(lastCard.mapToItem(dashboard,0,lastCard.height).y <= newsPanel.mapToItem(dashboard,0,0).y, "Summary cards must not overlap RSS at wide, short sizes")
      harness.width = 661; harness.height = 478
      wait(20)
      var rss = findChild(dashboard, "rssFeed")
      verify(rss.mapToItem(dashboard, 0, rss.height).y <= dashboard.height, "RSS must stay inside a short tiled window")
      harness.width = 1320; harness.height = 940
    }
    function test_close_button() {
      mouseClick(findChild(dashboard, "closeButton"))
      compare(closeSpy.count, 1)
    }
    function test_rss_scrolling_and_popup_snapshot() {
      var feed = findChild(dashboard, "newsList")
      dashboard.updateConfiguration({}, 1, {feeds:[{url:"https://example.com/rss",count:10}],scrollSpeed:50})
      wait(20)
      feed.contentX=0
      dashboard.advanceNews(1)
      compare(feed.contentX, 50)
      dashboard.openArticle(2)
      var popup = findChild(dashboard, "articleDialog")
      tryCompare(popup,"visible",true)
      verify(!findChild(dashboard,"newsScrollTimer").running)
      compare(dashboard.selectedArticle.title,"Story 2")
      dashboard.headlines = [{title:"New story",body:"New summary",published:"",publisher:"Other",url:"https://example.com/new"}]
      compare(dashboard.selectedArticle.title,"Story 2")
      compare(dashboard.articleDate(""),"Date unavailable")
      popup.close()
    }
    function test_settings_accordions_and_rss_configuration() {
      mouseClick(findChild(dashboard,"settingsButton"))
      var dialog=findChild(dashboard,"settingsDialog")
      tryCompare(dialog,"visible",true)
      var appearance=findChild(dashboard,"appearanceAccordion")
      var rss=findChild(dashboard,"rssAccordion")
      verify(!appearance.expanded)
      verify(!rss.expanded)
      wait(50)
      mouseClick(findChild(dashboard,"rssAccordionHeader"))
      verify(rss.expanded)
      wait(20)
      var drafts=findChild(dashboard,"feedDraft")
      compare(drafts.count,1)
      compare(drafts.get(0).url,"https://www.jpost.com/rss/rssfeedsfrontpage.aspx")
      var rep=findChild(dashboard,"feedRepeater")
      var field=findChild(rep.itemAt(0),"feedUrl0")
      clipboard.text="https://example.com/feed.xml"
      clipboard.selectAll();clipboard.copy()
      field.forceActiveFocus();field.selectAll();field.paste()
      compare(drafts.get(0).url,"https://example.com/feed.xml")
      var count=findChild(rep.itemAt(0),"feedCount0")
      mouseClick(count,count.width-10,count.height/2)
      compare(drafts.get(0).count,11)
      findChild(dashboard,"rssSpeed").value=45
      findChild(dashboard,"rssMaxWords").value=150
      var apply=findChild(dashboard,"applySettings")
      mouseClick(apply)
      tryCompare(dialog,"visible",false)
      compare(dashboard.configuration.rss.feeds[0].url,"https://example.com/feed.xml")
      compare(dashboard.configuration.rss.feeds[0].count,11)
      compare(dashboard.configuration.rss.scrollSpeed,45)
      compare(dashboard.configuration.rss.maxWords,150)
      dashboard.updateConfiguration({},1)
      compare(dashboard.configuration.rss.feeds[0].count,11)
    }
    function test_rss_draft_validation_and_cancel() {
      mouseClick(findChild(dashboard,"settingsButton"))
      var dialog=findChild(dashboard,"settingsDialog")
      tryCompare(dialog,"visible",true)
      wait(50)
      mouseClick(findChild(dashboard,"rssAccordionHeader"))
      wait(20)
      mouseClick(findChild(dashboard,"addFeedButton"))
      var drafts=findChild(dashboard,"feedDraft")
      compare(drafts.count,2)
      var apply=findChild(dashboard,"applySettings")
      verify(!apply.enabled)
      var rep=findChild(dashboard,"feedRepeater")
      var field=findChild(rep.itemAt(1),"feedUrl1")
      clipboard.text="https://example.com/second.xml"
      clipboard.selectAll();clipboard.copy()
      field.forceActiveFocus();field.paste()
      tryCompare(apply,"enabled",true)
      dialog.close()
      compare(dashboard.rssConfiguration.feeds.length,1)
      compare(dashboard.rssConfiguration.feeds[0].url,"https://www.jpost.com/rss/rssfeedsfrontpage.aspx")
    }
    function test_article_image_layout_and_width() {
      var image=findChild(dashboard,"articleImage")
      compare(String(image.source),"")
      // This test exercises geometry; keep image decoding/network out of it.
      image.source = ""
      dashboard.headlines=[{title:"Article with image",body:"Article content",published:"2026-10-24T12:00:00Z",publisher:"Publisher",url:"https://example.com/story",image:"https://example.com/photo.jpg"}]
      dashboard.openArticle(0)
      var popup=findChild(dashboard,"articleDialog")
      tryCompare(popup,"visible",true)
      wait(20)
      verify(popup.width<=1920*.33, "Popup must default to 33% of available screen width")
      dashboard.availableScreenWidth=1600
      wait(20)
      verify(popup.width<=1600*.33)
      var picture=findChild(dashboard,"articlePicture")
      var text=findChild(dashboard,"articleText")
      verify(picture.visible)
      verify(Math.abs((text.availableWidth-16)/picture.width-3)<.1,"Image should occupy one third of the content width")
      compare(picture.x,0)
      var flowedText=findChild(dashboard,"articleBody")
      verify(flowedText.lineInset(0)>0)
      compare(flowedText.lineInset(picture.height+1),0)
      compare(image.verticalAlignment,Image.AlignTop)
      image.source='data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="120" height="60"><rect width="120" height="60" fill="blue"/></svg>'
      tryCompare(image,"status",Image.Ready)
      wait(20)
      verify(Math.abs(picture.height/picture.width-.5)<.01,"Loaded image must keep its intrinsic aspect ratio without a size binding loop")
      image.source=""
      verify(popup.height<500,"Short articles should not reserve a tall empty popup")
      var body=findChild(dashboard,"articleContent")
      var openButton=findChild(dashboard,"openOriginalArticle")
      var closeButton=findChild(dashboard,"closeArticle")
      compare(openButton.width,closeButton.width)
      compare(openButton.y,closeButton.y)
      var bodyText=findChild(dashboard,"articleBody")
      verify(body.height<=Math.max(picture.implicitHeight,bodyText.implicitHeight)+1,"Content row must not reserve blank height below the image")
      var gap=openButton.mapToItem(dashboard,0,0).y-body.mapToItem(dashboard,0,body.height).y
      verify(gap<=12,"Actions must follow the content without extra empty space")
      popup.close()
      tryVerify(function() { return String(image.source)==="" })
      dashboard.headlines=[{title:"No image",body:"Content",published:"",publisher:"Publisher",url:"https://example.com/no-image"}]
      dashboard.openArticle(0)
      wait(20)
      verify(!picture.visible)
      verify(text.width>findChild(dashboard,"articleContent").width-2)
      popup.close()
    }
    function test_appearance_popup_width_setting() {
      compare(dashboard.popupWidthPercent,33)
      mouseClick(findChild(dashboard,"settingsButton"))
      var dialog=findChild(dashboard,"settingsDialog")
      tryCompare(dialog,"visible",true)
      wait(50)
      var widthSlider=findChild(dashboard,"popupWidthPercent")
      compare(widthSlider.value,33)
      widthSlider.value=50
      mouseClick(findChild(dashboard,"applySettings"))
      tryCompare(dialog,"visible",false)
      compare(dashboard.configuration.popupWidthPercent,50)
      dashboard.openArticle(0)
      var popup=findChild(dashboard,"articleDialog")
      tryCompare(popup,"visible",true)
      compare(popup.width,960)
      popup.close()
      mouseClick(findChild(dashboard,"settingsButton"))
      tryCompare(dialog,"visible",true)
      compare(widthSlider.value,50)
      dialog.close()
      dashboard.updateConfiguration({},1)
      compare(dashboard.popupWidthPercent,50)
    }
    function test_long_article_is_scrollable_with_bounded_popup_height() {
      dashboard.updateConfiguration({},1,{maxWords:0})
      dashboard.headlines=[{title:"Long article",body:new Array(180).join("A line of article text. "),published:"",publisher:"Publisher",url:"https://example.com/story"}]
      dashboard.openArticle(0)
      var popup=findChild(dashboard,"articleDialog")
      tryCompare(popup,"visible",true)
      wait(20)
      verify(popup.height<=dashboard.height-32)
      var scroll=findChild(dashboard,"articleText")
      verify(scroll.contentHeight>scroll.availableHeight,"Long article text must remain scrollable")
      popup.close()
    }
    function test_article_height_grows_with_content_and_actions_stay_equal() {
      dashboard.headlines=[{title:"Article",body:"Brief text.",published:"",publisher:"Publisher",url:"https://example.com/story"}]
      dashboard.openArticle(0)
      var popup=findChild(dashboard,"articleDialog")
      tryCompare(popup,"visible",true)
      wait(20)
      var shortHeight=popup.height
      var open=findChild(dashboard,"openOriginalArticle")
      var close=findChild(dashboard,"closeArticle")
      compare(open.width,close.width)
      dashboard.selectedArticle={title:"Article",body:new Array(30).join("More article content to read. "),published:"",publisher:"Publisher",url:"https://example.com/story"}
      wait(20)
      verify(popup.height>shortHeight,"Longer articles should expand the popup")
      dashboard.availableScreenWidth=1400
      wait(20)
      compare(open.width,close.width)
      compare(open.y,close.y)
      mouseClick(close)
      tryCompare(popup,"visible",false)
    }
    function cleanup() {
      ["articleDialog","settingsDialog","aboutDialog"].forEach(function(name) { var popup=findChild(dashboard,name); if(popup) popup.close() })
    }
    function test_article_word_limit_and_more_link() {
      compare(ArticleText.excerpt("One two three four five",3).text,"One two three")
      verify(ArticleText.excerpt("One two three four",3).truncated)
      verify(!ArticleText.excerpt("One two three",3).truncated)
      verify(!ArticleText.excerpt("One two three four",0).truncated)
      var markup=ArticleText.markup("One two three four",3,"https://example.com/story?a=1&b=2")
      verify(markup.indexOf(' ...&lt;<a href="https://example.com/story?a=1&amp;b=2">more</a>&gt;')>=0)
      verify(ArticleText.markup('<img src="https://example.com/tracker"> text',0,"").indexOf("<img")===-1)
      dashboard.updateConfiguration({},1,{maxWords:3})
      dashboard.headlines=[{title:"Word limit",body:"One two three four five",published:"",publisher:"Publisher",url:"https://example.com/story"}]
      dashboard.openArticle(0)
      var popup=findChild(dashboard,"articleDialog")
      tryCompare(popup,"visible",true)
      var text=findChild(dashboard,"articleBody")
      verify(text.text.indexOf("four")===-1)
      verify(text.text.indexOf('href="https://example.com/story"')>=0)
      wait(20)
      var linked=false
      for(var y=3;y<text.height && !linked;y+=5)
        for(var x=3;x<text.width && !linked;x+=5)
          linked=text.linkAt(x,y)==="https://example.com/story"
      verify(linked,"The visible more text must activate the original article link")
      dashboard.updateConfiguration({},1,{maxWords:0})
      verify(text.text.indexOf("five")>=0)
      verify(text.text.indexOf("more</a>")===-1)
      popup.close()
    }
    function test_article_text_wraps_below_image() {
      var image=findChild(dashboard,"articleImage")
      image.source=""
      dashboard.updateConfiguration({},1,{maxWords:0})
      dashboard.headlines=[{title:"Float",body:new Array(100).join("Article words flow around the image. "),published:"",publisher:"Publisher",url:"https://example.com/story",image:"https://example.com/photo.jpg"}]
      dashboard.openArticle(0)
      var popup=findChild(dashboard,"articleDialog")
      tryCompare(popup,"visible",true)
      wait(20)
      var body=findChild(dashboard,"articleBody")
      var picture=findChild(dashboard,"articlePicture")
      referenceText.font=body.font
      referenceText.width=body.width-picture.width-16
      referenceText.text=body.text
      wait(20)
      verify(body.implicitHeight<referenceText.implicitHeight,"Text must regain full width below the image, rather than stay in a column")
      compare(body.lineInset(picture.height+1),0)
      popup.close()
    }
    function test_email_settings_section_applies_only_when_confirmed() {
      dashboard.emailSettingsComponent=emailSettingsProbe
      dashboard.openSettings()
      var dialog=findChild(dashboard,"settingsDialog")
      tryCompare(dialog,"visible",true)
      var section=findChild(dashboard,"emailAccordion")
      verify(section && !section.expanded)
      compare(harness.emailSettingsSaves,0)
      dialog.close()
      compare(harness.emailSettingsSaves,0)
      dashboard.openSettings()
      tryCompare(dialog,"visible",true)
      verify(!section.expanded)
      findChild(dashboard,"applySettings").clicked()
      compare(harness.emailSettingsSaves,1)
      tryCompare(dialog,"visible",false)
    }
    function test_settings_start_collapsed_and_keep_scrollbar_gutter() {
      mouseClick(findChild(dashboard,"settingsButton"))
      var dialog=findChild(dashboard,"settingsDialog")
      tryCompare(dialog,"visible",true)
      wait(50)
      var appearance=findChild(dashboard,"appearanceAccordion")
      var rss=findChild(dashboard,"rssAccordion")
      verify(!appearance.expanded)
      verify(!rss.expanded)
      var scroll=findChild(dashboard,"settingsScroll")
      var arrow=findChild(dashboard,"appearanceAccordionArrow")
      verify(scroll.width-arrow.mapToItem(scroll,arrow.width,0).x>=24,"Accordion arrow needs a scrollbar gutter")
      mouseClick(findChild(dashboard,"appearanceAccordionHeader"))
      verify(appearance.expanded)
      dialog.close()
      mouseClick(findChild(dashboard,"settingsButton"))
      tryCompare(dialog,"visible",true)
      verify(!appearance.expanded)
      verify(!rss.expanded)
      dialog.close()
    }
    function test_dialogs() {
      mouseClick(findChild(dashboard, "settingsButton"))
      var settings = findChild(dashboard, "settingsDialog")
      tryCompare(settings, "visible", true)
      settings.close()
      mouseClick(findChild(dashboard, "aboutButton"))
      var about = findChild(dashboard, "aboutDialog")
      tryCompare(about, "visible", true)
      about.close()
    }
  }
}
