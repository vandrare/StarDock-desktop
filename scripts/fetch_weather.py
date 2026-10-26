#!/usr/bin/python3
"""Open-Meteo forecasts/geocoding and cached OSM + NOAA radar map assets."""
import concurrent.futures
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

CACHE = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home()/'.cache'))) / 'starlink-dashboard/weather'
AGENT = 'StarlinkDashboard/0.3 (personal desktop weather app)'
RADAR = 'https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity/MapServer/export'
RADAR_WMS = 'https://opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows'
MAP_WIDTH, MAP_HEIGHT = 768, 512

def download(url, limit=4*1024*1024):
    request = urllib.request.Request(url, headers={'User-Agent':AGENT,'Accept':'application/json,image/png,*/*'})
    with urllib.request.urlopen(request, timeout=12) as response:
        data = response.read(limit+1)
    if len(data)>limit: raise ValueError('Response too large')
    return data

def cached(url, ttl, suffix='.json'):
    CACHE.mkdir(parents=True,exist_ok=True)
    path=CACHE/(hashlib.sha256(url.encode()).hexdigest()+suffix)
    if path.exists() and time.time()-path.stat().st_mtime<ttl:
        return path
    data=download(url)
    if suffix=='.png' and not data.startswith(b'\x89PNG\r\n\x1a\n'): raise ValueError('Map service did not return a PNG')
    if suffix=='.json': json.loads(data)
    if suffix=='.xml': ET.fromstring(data)
    temporary=path.with_suffix(suffix+'.tmp')
    temporary.write_bytes(data)
    temporary.replace(path)
    return path

def get_json(url, ttl=0):
    return json.loads(cached(url,ttl).read_bytes())

def search(query):
    name=str(query).strip().split(',')[0][:120]
    if len(name)<2: return {'locations':[],'error':'Enter a city or postal code with at least two characters.'}
    url='https://geocoding-api.open-meteo.com/v1/search?'+urllib.parse.urlencode({'name':name,'count':8,'language':'en','format':'json'})
    data=get_json(url,86400)
    locations=[]
    for item in data.get('results',[]):
        parts=list(dict.fromkeys(x for x in [item.get('name'),item.get('admin1'),item.get('country')] if x))
        locations.append({'location':', '.join(parts),'latitude':item['latitude'],'longitude':item['longitude'],'countryCode':item.get('country_code','')})
    return {'locations':locations,'error':'' if locations else 'No locations found. Try the city name without the state.'}

def forecast(config):
    params={
        'latitude':config['latitude'],'longitude':config['longitude'],
        'current':'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,precipitation',
        'hourly':'precipitation_probability',
        'daily':'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum',
        'forecast_days':7,'timezone':'auto',
        'temperature_unit':config.get('temperatureUnit','fahrenheit'),
        'wind_speed_unit':'mph' if config.get('units','imperial')=='imperial' else 'kmh',
        'precipitation_unit':'inch' if config.get('units','imperial')=='imperial' else 'mm'}
    data=get_json('https://api.open-meteo.com/v1/forecast?'+urllib.parse.urlencode(params),300)
    if data.get('error'): raise ValueError('Forecast unavailable')
    current=data['current'];daily=data['daily']
    hour=current['time'][:13]+':00'
    hours=data.get('hourly',{}).get('time',[])
    probabilities=data.get('hourly',{}).get('precipitation_probability',[])
    probability=probabilities[hours.index(hour)] if hour in hours else None
    def at(key,i):
        values=daily.get(key,[])
        return values[i] if i<len(values) else None
    return {'location':config.get('location','Selected location'),'latitude':config['latitude'],'longitude':config['longitude'],
        'timezone':data.get('timezone',''),'updated':current['time'],
        'units':{'temperature':'°F' if params['temperature_unit']=='fahrenheit' else '°C','wind':'mph' if params['wind_speed_unit']=='mph' else 'km/h','precipitation':'in' if params['precipitation_unit']=='inch' else 'mm'},
        'current':{'temperature':current.get('temperature_2m'),'feelsLike':current.get('apparent_temperature'),'humidity':current.get('relative_humidity_2m'),'wind':current.get('wind_speed_10m'),'precipitation':current.get('precipitation'),'probability':probability,'code':current.get('weather_code')},
        'daily':[{'date':date,'high':at('temperature_2m_max',i),'low':at('temperature_2m_min',i),'code':at('weather_code',i),'probability':at('precipitation_probability_max',i),'precipitation':at('precipitation_sum',i)} for i,date in enumerate(daily['time'][:7])]}

def mercator_pixels(latitude,longitude,zoom):
    latitude=max(-85.0511,min(85.0511,float(latitude)))
    size=256*2**zoom
    x=(float(longitude)+180)/360*size
    angle=math.radians(latitude)
    y=(1-math.asinh(math.tan(angle))/math.pi)/2*size
    return x,y

def map_geometry(latitude,longitude,zoom):
    x,y=mercator_pixels(latitude,longitude,zoom)
    left,top=x-MAP_WIDTH/2,y-MAP_HEIGHT/2
    size=256*2**zoom
    meters=2*math.pi*6378137
    bounds=[left/size*meters-meters/2,meters/2-(top+MAP_HEIGHT)/size*meters,(left+MAP_WIDTH)/size*meters-meters/2,meters/2-top/size*meters]
    tiles=[]
    for ty in range(math.floor(top/256),math.floor((top+MAP_HEIGHT-1)/256)+1):
        for tx in range(math.floor(left/256),math.floor((left+MAP_WIDTH-1)/256)+1):
            if 0<=ty<2**zoom:
                tiles.append({'x':tx*256-left,'y':ty*256-top,'remote':f'https://tile.openstreetmap.org/{zoom}/{tx%(2**zoom)}/{ty}.png'})
    return tiles,bounds

def radar_frames(bounds):
    url=RADAR_WMS+'?service=WMS&request=GetCapabilities'
    document=ET.fromstring(cached(url,120,'.xml').read_bytes())
    dimension=next(n for n in document.iter() if n.tag.split('}')[-1]=='Dimension' and n.get('name')=='time')
    available=sorted(set(t.strip() for t in (dimension.text or '').split(',') if t.strip()))
    # Roughly one hour at six-minute intervals, always including the newest frame.
    times=available[-31::3]
    if available and (not times or times[-1]!=available[-1]):times.append(available[-1])
    if not times:raise ValueError('No radar times available')
    def frame(timestamp):
        params={'service':'WMS','version':'1.1.1','request':'GetMap','layers':'conus_bref_qcd','styles':'',
                'srs':'EPSG:3857','bbox':','.join(map(str,bounds)),'width':MAP_WIDTH,'height':MAP_HEIGHT,
                'format':'image/png','transparent':'true','time':timestamp}
        try:return {'url':cached(RADAR_WMS+'?'+urllib.parse.urlencode(params),86400,'.png').as_uri(),'time':timestamp}
        except Exception:return None
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        frames=[item for item in pool.map(frame,times) if item]
    if not frames:raise ValueError('Radar frames unavailable')
    return frames

def radar_map(config):
    zoom=max(3,min(10,int(config.get('mapZoom',7))))
    tiles,bounds=map_geometry(config['latitude'],config['longitude'],zoom)
    def tile(item):
        result={'x':item['x'],'y':item['y'],'url':''}
        try: result['url']=cached(item['remote'],7*86400,'.png').as_uri()
        except Exception: pass
        return result
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        assets=list(pool.map(tile,tiles))
    result={'width':MAP_WIDTH,'height':MAP_HEIGHT,'tiles':assets,'zoom':zoom,'overlay':'','frames':[],'updated':datetime.datetime.now(datetime.timezone.utc).isoformat(),'error':''}
    if not any(x['url'] for x in assets):result['error']='Basemap unavailable. Check the connection.'
    # NWS radar/alerts are U.S. products; forecasts and basemaps work worldwide.
    if config.get('countryCode','US')!='US':
        result['error']='NOAA radar coverage is limited to the United States.'
        return result
    params={'bbox':','.join(str(x) for x in bounds),'bboxSR':3857,'imageSR':3857,'size':f'{MAP_WIDTH},{MAP_HEIGHT}','format':'png32','transparent':'true','f':'image'}
    if 24<=config['latitude']<=50 and -125<=config['longitude']<=-66:
        try:
            result['frames']=radar_frames(bounds)
            result['overlay']=result['frames'][-1]['url']
            return result
        except Exception:
            result['error']='Animated radar unavailable; showing the latest static radar.'
    else:
        result['error']='Animated radar covers the contiguous U.S.; showing the latest static radar.'
    try:
        result['overlay']=cached(RADAR+'?'+urllib.parse.urlencode(params),120,'.png').as_uri()
    except Exception:
        result['error']='Radar overlay unavailable. Basemap is still shown.'
    return result

def alerts(config):
    if config.get('countryCode','US')!='US':return {'items':[],'error':'NWS alerts are available for U.S. locations only.'}
    try:
        url='https://api.weather.gov/alerts/active?'+urllib.parse.urlencode({'point':f"{config['latitude']},{config['longitude']}"})
        data=get_json(url,120)
        items=[]
        for item in data.get('features',[])[:10]:
            p=item.get('properties',{})
            items.append({'title':p.get('event','Weather alert'),'headline':p.get('headline',''),'severity':p.get('severity',''),'description':p.get('description',''),'url':item.get('id','')})
        return {'items':items,'error':''}
    except Exception:return {'items':[],'error':'NWS alerts currently unavailable.'}

def weather(config):
    config=dict(config)
    config['latitude']=float(config.get('latitude',33.4484));config['longitude']=float(config.get('longitude',-112.074))
    if not -90<=config['latitude']<=90 or not -180<=config['longitude']<=180:raise ValueError('Invalid coordinates')
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        a=pool.submit(forecast,config);b=pool.submit(radar_map,config);c=pool.submit(alerts,config)
        result=a.result()
        result['map']=b.result();result['alerts']=c.result()
    return {'weather':result,'error':''}

def main():
    try:
        request=json.loads(sys.stdin.readline(65536))
        result=search(request.get('query','')) if request.get('op')=='search' else weather(request.get('config',{}))
    except Exception:
        result={'error':'Weather service unavailable. Check the connection and try Refresh.'}
    print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':main()
