.pragma library
function sectionTitleSize(value) { return Math.max(12,Math.min(72,Math.round(Number(value)||36))) }
function sidebarWidth(value) { var n=Number(value===undefined?33:value);return isFinite(n)?Math.max(20,Math.min(35,Math.round(n))):33 }
function popupAppearance(value) {
  value=value || {}
  var size=Number(value.shadowSize===undefined?20:value.shadowSize),opacity=Number(value.overlayOpacity===undefined?35:value.overlayOpacity)
  return {shadowSize:isFinite(size)?Math.max(0,Math.min(64,Math.round(size))):20,shadowColor:/^#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?$/.test(value.shadowColor || "")?value.shadowColor:"#000000",overlayOpacity:isFinite(opacity)?Math.max(0,Math.min(100,Math.round(opacity))):35}
}
var fontOptions = [
  {key:"emailBody",label:"Email message body",defaultSize:14,min:10,max:24},
  {key:"notesBody",label:"Notes editor",defaultSize:14,min:10,max:24},
  {key:"summaries",label:"Sidebar summaries and message list",defaultSize:12,min:10,max:18},
  {key:"rssBody",label:"RSS article popup body",defaultSize:14,min:10,max:24},
  {key:"rssHeadline",label:"RSS feed headlines",defaultSize:15,min:12,max:22}
]
function fontOverrides(value) {
  var source=value || {},result={}
  for(var i=0;i<fontOptions.length;i++){
    var option=fontOptions[i],n=Number(source[option.key])
    if(source[option.key]!==undefined && source[option.key]!==null && isFinite(n))result[option.key]=Math.max(option.min,Math.min(option.max,Math.round(n)))
  }
  return result
}
function fontSizes(value) {
  var overrides=fontOverrides(value),result={}
  for(var i=0;i<fontOptions.length;i++){var option=fontOptions[i];result[option.key]=overrides[option.key]===undefined?option.defaultSize:overrides[option.key]}
  return result
}
var moduleOptions = [{key:"overview",title:"Overview"},{key:"weather",title:"Weather"},{key:"calendar",title:"Calendar"},{key:"notes",title:"Notes"},{key:"email",title:"Email"}]
function modules(value) {
  if(!value || typeof value.length!=="number")return ["overview","weather","calendar","notes"]
  var result=[]
  for(var i=0;i<value.length;i++)if(moduleOptions.some(function(option){return option.key===value[i]}) && result.indexOf(value[i])<0 && result.length<4)result.push(value[i])
  for(var j=0;result.length<3 && j<moduleOptions.length;j++)if(result.indexOf(moduleOptions[j].key)<0)result.push(moduleOptions[j].key)
  return result
}
var dateFormats = ["MMM d, yyyy", "dddd, MMMM d, yyyy", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "d MMM yyyy"]
function clock(value) {
  value=value || {}
  return {fontSize:Math.max(12,Math.min(64,Math.round(Number(value.fontSize)||36))),hourFormat:value.hourFormat==="24"?"24":"12",dateFormat:dateFormats.indexOf(value.dateFormat)>=0?value.dateFormat:dateFormats[0]}
}
var firstFeed = "https://www.jpost.com/rss/rssfeedsfrontpage.aspx"
function rss(value) {
  value = value || {}
  var feeds = []
  if (value.feeds && typeof value.feeds.length === "number") {
    for (var i=0;i<Math.min(10,value.feeds.length);i++) feeds.push(value.feeds[i])
  } else feeds = [{url: firstFeed, count: 10}]
  var maxWords = Number(value.maxWords === undefined ? 300 : value.maxWords)
  maxWords = isFinite(maxWords) ? Math.max(0,Math.min(10000,Math.round(maxWords))) : 300
  return { enabled:value.enabled!==false, maxWords: maxWords, feeds: feeds.map(function(feed) { return {url: String(feed.url || "").trim(), count: Math.max(1, Math.min(50, Math.round(Number(feed.count) || 10)))} }), scrollSpeed: Math.max(0, Math.min(150, Number(value.scrollSpeed === undefined ? 28 : value.scrollSpeed) || 0)) }
}

function popupWidth(value) {
  var n = Number(value === undefined ? 33 : value)
  return isFinite(n) ? Math.max(20, Math.min(100, Math.round(n))) : 33
}

function weather(value) {
  value=value || {}
  var latitude=Number(value.latitude === undefined ? 33.4484 : value.latitude)
  var longitude=Number(value.longitude === undefined ? -112.074 : value.longitude)
  return {location:String(value.location || "Phoenix, Arizona, United States"),latitude:isFinite(latitude)?Math.max(-90,Math.min(90,latitude)):33.4484,longitude:isFinite(longitude)?Math.max(-180,Math.min(180,longitude)):-112.074,countryCode:String(value.countryCode || "US"),temperatureUnit:value.temperatureUnit === "celsius"?"celsius":"fahrenheit",units:value.units === "metric"?"metric":"imperial",refreshMinutes:Math.max(5,Math.min(120,Math.round(Number(value.refreshMinutes)||15))),mapZoom:Math.max(3,Math.min(10,Math.round(Number(value.mapZoom)||7)))}
}

var overviewSections=["weather","calendar","email","notes"]
function overview(value) {
  value=value || {}
  var order=[],hidden=[],choices=value.order || [],omitted=value.hidden || []
  for(var i=0;i<choices.length;i++)if(overviewSections.indexOf(choices[i])>=0 && order.indexOf(choices[i])<0)order.push(choices[i])
  overviewSections.forEach(function(key){if(order.indexOf(key)<0)order.push(key)})
  for(var j=0;j<omitted.length;j++)if(overviewSections.indexOf(omitted[j])>=0 && hidden.indexOf(omitted[j])<0)hidden.push(omitted[j])
  return {order:order,hidden:hidden}
}
