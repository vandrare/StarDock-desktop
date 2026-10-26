import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('rss', Path(__file__).parents[1]/'scripts/fetch_rss.py')
rss = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rss)

class RSS(unittest.TestCase):
    def test_rss_title_date_limit_and_plain_summary(self):
        xml = b'''<rss><channel><title>Publisher</title><item><title>News &amp; updates</title><link>https://example.com/one</link><pubDate>Sat, 24 Oct 2026 21:04:17 GMT</pubDate><description><![CDATA[<img src="https://example.com/tracker"><p>First &amp; second</p><script>bad()</script>]]></description></item><item><title>Two</title><link>https://example.com/two</link></item></channel></rss>'''
        publisher, articles = rss.parse_feed(xml, 'https://example.com/rss', 1)
        self.assertEqual(publisher, 'Publisher')
        self.assertEqual(len(articles), 1)
        self.assertEqual(articles[0]['title'], 'News & updates')
        self.assertEqual(articles[0]['published'], '2026-10-24T21:04:17+00:00')
        self.assertEqual(articles[0]['body'], 'First & second')
    def test_atom_and_duplicate_links(self):
        xml = b'''<feed xmlns="http://www.w3.org/2005/Atom"><title>Atom</title><entry><title>One</title><link href="/one"/><updated>2026-10-24T21:00:00Z</updated><summary>Summary</summary></entry><entry><title>Duplicate</title><link href="/one"/></entry></feed>'''
        _, items = rss.parse_feed(xml, 'https://example.com/rss', 10)
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]['url'], 'https://example.com/one')
        self.assertEqual(items[0]['published'], '2026-10-24T21:00:00+00:00')
    def test_no_invalid_links_or_xml_entities(self):
        for data in [b'<!DOCTYPE rss [<!ENTITY x "secret">]><rss/>', b'<html/>', b'x'*(rss.MAX_BYTES+1)]:
            with self.assertRaises((ValueError, rss.ET.ParseError)):
                rss.parse_feed(data, 'https://example.com/rss', 10)
        data=b'<rss><channel><item><title>Bad link</title><link>file:///etc/passwd</link></item></channel></rss>'
        self.assertEqual(rss.parse_feed(data, 'https://example.com/rss', 10)[1], [])
        self.assertFalse(rss.http_url('https://name:secret@example.com/rss'))
    def test_description_image_and_no_image(self):
        xml=b'''<rss><channel><item><title>Image</title><link>https://example.com/news/story</link><description><![CDATA[<img width="1" src="https://example.com/pixel"><img src="/photos/article.jpg"><p>Summary</p>]]></description></item><item><title>No image</title><link>https://example.com/none</link></item></channel></rss>'''
        _,items=rss.parse_feed(xml,'https://example.com/feed',10)
        self.assertEqual(items[0]['image'],'https://example.com/photos/article.jpg')
        self.assertEqual(items[1]['image'],'')
        self.assertEqual(items[0]['body'],'Summary')
    def test_media_enclosure_and_invalid_image_sources(self):
        xml=b'''<rss xmlns:media="http://search.yahoo.com/mrss/"><channel><item><title>Media</title><link>https://example.com/article</link><media:content medium="image" url="https://cdn.example.com/large.jpg"/><description><![CDATA[<img src="https://example.com/small.jpg">]]></description></item><item><title>Enclosure</title><link>https://example.com/two</link><enclosure type="image/png" url="https://example.com/two.png"/></item><item><title>Invalid</title><link>https://example.com/three</link><description><![CDATA[<img src="file:///private/image.png"><img src="javascript:alert(1)">]]></description></item></channel></rss>'''
        _,items=rss.parse_feed(xml,'https://example.com/feed',10)
        self.assertEqual(items[0]['image'],'https://cdn.example.com/large.jpg')
        self.assertEqual(items[1]['image'],'https://example.com/two.png')
        self.assertEqual(items[2]['image'],'')
    def test_atom_image_enclosure(self):
        xml=b'''<feed xmlns="http://www.w3.org/2005/Atom"><title>Feed</title><entry><title>Story</title><link href="https://example.com/story"/><link rel="enclosure" type="image/jpeg" href="https://example.com/photo.jpg"/></entry></feed>'''
        self.assertEqual(rss.parse_feed(xml,'https://example.com/feed',1)[1][0]['image'],'https://example.com/photo.jpg')
    def test_missing_date_stays_missing(self):
        self.assertEqual(rss.date_iso(''), '')
        self.assertEqual(rss.date_iso('yesterday'), '')
    def test_invalid_feed_url_has_visible_error(self):
        self.assertTrue(rss.fetch({'url':'file:///etc/passwd','count':10})['error'])

if __name__ == '__main__': unittest.main()
