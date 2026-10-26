.pragma library
var views=["month","week","day","agenda"]
var dates=["MMM d, yyyy","MM/dd/yyyy","dd/MM/yyyy","yyyy-MM-dd","d MMM yyyy"]
function normalize(settings) {
  var value=settings || {}
  return {calendarDefaultView:views.indexOf(value.calendarDefaultView)>=0?value.calendarDefaultView:"month",
    calendarWeekStart:value.calendarWeekStart===0?0:1,
    calendarDuration:Math.max(5,Math.min(1440,Math.round(Number(value.calendarDuration)||60))),
    calendarTimeZone:typeof value.calendarTimeZone==="string" && /^[A-Za-z0-9_+./-]{0,100}$/.test(value.calendarTimeZone)?value.calendarTimeZone:"",
    calendarTimeFormat:value.calendarTimeFormat==="24"?"24":"12",
    calendarDateFormat:dates.indexOf(value.calendarDateFormat)>=0?value.calendarDateFormat:dates[0],
    calendarRemindersEnabled:value.calendarRemindersEnabled===true,
    calendarSnoozeMinutes:Math.max(1,Math.min(1440,Math.round(Number(value.calendarSnoozeMinutes)||5)))}
}
