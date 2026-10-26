.pragma library
function excerpt(body, limit) {
  var source = String(body || "")
  if (!limit) return {text:source,truncated:false}
  var words=/\S+/g, match, count=0, end=0
  while ((match=words.exec(source))!==null) {
    count++
    if (count>limit) return {text:source.substring(0,end),truncated:true}
    end=words.lastIndex
  }
  return {text:source,truncated:false}
}
function escape(value) {
  return String(value || "").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")
}
function markup(body, limit, url) {
  var result=excerpt(body,limit)
  var output=escape(result.text).replace(/\n/g,"<br>")
  if (result.truncated) {
    output += " ...&lt;"
    output += /^https?:\/\//.test(url || "") ? '<a href="'+escape(url)+'">more</a>' : "more"
    output += "&gt;"
  }
  return output
}
