.pragma library
function number(value, digits) { return value===null || value===undefined || !isFinite(Number(value)) ? "—" : Number(value).toFixed(digits || 0) }
function condition(code) {
  if(code===null || code===undefined)return "Conditions unavailable"
  code=Number(code)
  if(code===0)return "Clear"
  if(code<=3)return "Partly cloudy"
  if(code<=48)return "Fog"
  if(code<=57)return "Drizzle"
  if(code<=67)return "Rain"
  if(code<=77)return "Snow"
  if(code<=82)return "Rain showers"
  if(code<=86)return "Snow showers"
  if(code>=95)return "Thunderstorms"
  return "Conditions unavailable"
}
function icon(code) { code=Number(code); return code===0?"\uf185":code<=3?"\uf0c2":code>=95?"\uf0e7":code>=71&&code<=86?"\uf2dc":"\uf043" }
