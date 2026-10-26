.pragma library
function eventsToday(events,now) {
  var date=new Date(now),start=new Date(date.getFullYear(),date.getMonth(),date.getDate()).getTime()
  var end=new Date(date.getFullYear(),date.getMonth(),date.getDate()+1).getTime()
  return (events || []).filter(function(event){return event.start && Number(event.start.ms)<end && Number(event.end?event.end.ms:event.start.ms)>start}).sort(function(a,b){return Number(a.start.ms)-Number(b.start.ms)})
}
function nextEvent(events,now) {
  return (events || []).filter(function(event){return event.start && Number(event.end?event.end.ms:event.start.ms)>now}).sort(function(a,b){return Number(a.start.ms)-Number(b.start.ms)})[0] || null
}
