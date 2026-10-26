import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import tempfile
from urllib.parse import parse_qs, urlparse

spec = importlib.util.spec_from_file_location('weather', Path(__file__).parents[1] / 'scripts/fetch_weather.py')
weather = importlib.util.module_from_spec(spec)
spec.loader.exec_module(weather)


class WeatherTests(unittest.TestCase):
    def test_radar_frames_use_published_times_and_keep_newest(self):
        times=[f'2026-10-25T16:{minute:02}:00Z' for minute in range(0,60,2)]
        xml='<WMS_Capabilities><Dimension name="time">'+','.join(times)+'</Dimension></WMS_Capabilities>'
        with tempfile.TemporaryDirectory() as directory:
            capabilities=Path(directory)/'capabilities.xml'
            capabilities.write_text(xml)
            def asset(url, ttl, suffix):
                return capabilities if suffix=='.xml' else Path(directory)/'radar.png'
            with patch.object(weather,'cached',side_effect=asset) as fetch:
                frames=weather.radar_frames([-10,-20,10,20])
            self.assertEqual(frames[-1]['time'],times[-1])
            self.assertGreater(len(frames),1)
            requests=[parse_qs(urlparse(call.args[0]).query) for call in fetch.call_args_list if call.args[2]=='.png']
            self.assertTrue(all(p['time'][0] in times for p in requests))
            self.assertTrue(all(p['srs']==['EPSG:3857'] for p in requests))

    def test_forecast_units_days_and_current_rain_probability(self):
        dates = [f'2026-10-{day}' for day in range(24, 31)]
        fixture = {'current': {'time': '2026-10-24T13:15', 'temperature_2m': 21},
                   'daily': {'time': dates, 'temperature_2m_max': [25]*7},
                   'hourly': {'time': ['2026-10-24T12:00', '2026-10-24T13:00'], 'precipitation_probability': [10, 40]}}
        with patch.object(weather, 'get_json', return_value=fixture) as fetch:
            result = weather.forecast({'latitude': 33, 'longitude': -112, 'temperatureUnit': 'celsius', 'units': 'imperial'})
        params = parse_qs(urlparse(fetch.call_args.args[0]).query)
        self.assertEqual(params['temperature_unit'], ['celsius'])
        self.assertEqual(params['wind_speed_unit'], ['mph'])
        self.assertEqual(params['precipitation_unit'], ['inch'])
        self.assertEqual(result['units']['temperature'], '°C')
        self.assertEqual(len(result['daily']), 7)
        self.assertEqual(result['current']['probability'], 40)
        self.assertIsNone(result['daily'][0]['low'])

    def test_location_search_keeps_coordinates_and_country(self):
        with patch.object(weather, 'get_json', return_value={'results': [dict(name='Paris', admin1='Ile-de-France', country='France', country_code='FR', latitude=48.85, longitude=2.35)]}):
            result = weather.search('Paris')
        self.assertEqual(result['locations'][0]['countryCode'], 'FR')
        self.assertEqual(result['locations'][0]['latitude'], 48.85)
        self.assertEqual(result['error'], '')

    def test_map_projection_centers_location_and_wraps_tiles(self):
        tiles, bounds = weather.map_geometry(0, 0, 7)
        self.assertAlmostEqual(bounds[0], -bounds[2])
        self.assertAlmostEqual(bounds[1], -bounds[3])
        self.assertGreaterEqual(len(tiles), 6)
        tiles, _ = weather.map_geometry(0, 179.99, 3)
        for tile in tiles:
            self.assertIn(int(tile['remote'].split('/')[-2]), range(8))

    def test_non_us_alerts_do_not_request_nws(self):
        with patch.object(weather, 'get_json') as fetch:
            result = weather.alerts({'countryCode': 'FR'})
        fetch.assert_not_called()
        self.assertEqual(result['items'], [])
        self.assertIn('U.S.', result['error'])

    def test_invalid_coordinates_rejected_before_network(self):
        with self.assertRaises(ValueError):
            weather.weather({'latitude': 91, 'longitude': 0})


if __name__ == '__main__':
    unittest.main()
