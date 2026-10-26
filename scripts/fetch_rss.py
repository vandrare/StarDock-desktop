#!/usr/bin/python3
"""Bounded RSS/Atom fetcher. Receives configuration over private stdin."""
import concurrent.futures
import datetime
import email.utils
import html
from html.parser import HTMLParser
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

MAX_BYTES = 3 * 1024 * 1024
DEFAULT_URL = 'https://www.jpost.com/rss/rssfeedsfrontpage.aspx'

class PlainText(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.hidden = 0
    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style'): self.hidden += 1
        if tag in ('p', 'div', 'br', 'li'): self.parts.append(' ')
    def handle_endtag(self, tag):
        if tag in ('script', 'style'): self.hidden = max(0, self.hidden - 1)
        if tag in ('p', 'div', 'li'): self.parts.append(' ')
    def handle_data(self, data):
        if not self.hidden: self.parts.append(data)

def plain(value, limit=12000):
    parser = PlainText()
    parser.feed(value or '')
    return ' '.join(''.join(parser.parts).split())[:limit]

def http_url(value):
    try:
        u = urllib.parse.urlsplit(value)
        return u.scheme in ('https', 'http') and bool(u.hostname) and not u.username and not u.password
    except ValueError:
        return False

class ArticleImages(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.urls = []
    def handle_starttag(self, tag, attributes):
        if tag != 'img': return
        attrs = dict(attributes)
        if attrs.get('width') in ('0', '1') or attrs.get('height') in ('0', '1'): return
        source = attrs.get('src') or attrs.get('data-src')
        if source: self.urls.append(source)

def article_image(entry, description, base_url):
    media = '{http://search.yahoo.com/mrss/}'
    candidates = []
    for item in entry.iter(media+'content'):
        if item.get('medium') == 'image' or item.get('type', '').startswith('image/') or not item.get('type'):
            candidates.append(item.get('url', ''))
    candidates += [item.get('url', '') for item in entry.iter(media+'thumbnail')]
    candidates += [item.get('url', '') for item in entry.findall('enclosure') if item.get('type', '').startswith('image/')]
    candidates += [item.get('href', '') for item in entry.findall('{http://www.w3.org/2005/Atom}link') if item.get('rel') == 'enclosure' and item.get('type', '').startswith('image/')]
    parser = ArticleImages()
    parser.feed(description or '')
    for candidate in candidates + parser.urls:
        if not candidate: continue
        url = urllib.parse.urljoin(base_url, html.unescape(candidate.strip()))
        if http_url(url): return url
    return ''


def date_iso(value):
    if not value: return ''
    try:
        try: date = email.utils.parsedate_to_datetime(value)
        except (ValueError, TypeError): date = datetime.datetime.fromisoformat(value.replace('Z', '+00:00'))
        if date.tzinfo is None: date = date.replace(tzinfo=datetime.timezone.utc)
        return date.isoformat()
    except (ValueError, TypeError, OverflowError):
        return ''

def text(element, path):
    child = element.find(path)
    return ''.join(child.itertext()).strip() if child is not None else ''

def parse_feed(payload, feed_url, count):
    if len(payload) > MAX_BYTES: raise ValueError('Feed exceeds the 3 MiB size limit')
    # Feeds do not need DTDs or entities. Reject declarations before parsing.
    normalized = payload.replace(b'\x00', b'').upper()
    if b'<!DOCTYPE' in normalized or b'<!ENTITY' in normalized: raise ValueError('Unsupported XML declarations')
    root = ET.fromstring(payload)
    atom = '{http://www.w3.org/2005/Atom}'
    channel = root.find('channel')
    is_atom = root.tag == atom + 'feed'
    if channel is None and not is_atom: raise ValueError('This URL did not return an RSS or Atom feed')
    publisher = plain(text(root if is_atom else channel, atom+'title' if is_atom else 'title'), 200) or urllib.parse.urlsplit(feed_url).hostname
    entries = root.findall(atom+'entry') if is_atom else channel.findall('item')
    articles, seen = [], set()
    for entry in entries:
        if len(articles) >= count: break
        if is_atom:
            title = plain(text(entry, atom+'title'), 600)
            links = entry.findall(atom+'link')
            link = next((x.get('href', '') for x in links if x.get('rel', 'alternate') == 'alternate'), '')
            description = text(entry, atom+'content') or text(entry, atom+'summary')
            published = text(entry, atom+'published') or text(entry, atom+'updated')
        else:
            title = plain(text(entry, 'title'), 600)
            link = text(entry, 'link')
            description = text(entry, '{http://purl.org/rss/1.0/modules/content/}encoded') or text(entry, 'description')
            published = text(entry, 'pubDate') or text(entry, '{http://purl.org/dc/elements/1.1/}date')
        link = urllib.parse.urljoin(feed_url, link)
        if not title or not http_url(link) or link in seen: continue
        seen.add(link)
        articles.append(dict(title=title, url=link, body=plain(description), published=date_iso(published), publisher=publisher, feedUrl=feed_url, image=article_image(entry, description, link)))
    return publisher, articles

class FeedRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not http_url(newurl): raise ValueError('Unsupported feed redirect')
        return super().redirect_request(req, fp, code, msg, headers, newurl)

def fetch(feed):
    url = str(feed.get('url', '')).strip()
    result = dict(url=url, articles=[], error='')
    try:
        if not http_url(url): raise ValueError('Enter a valid http:// or https:// feed URL')
        count = max(1, min(50, int(feed.get('count', 10))))
        req = urllib.request.Request(url, headers={'User-Agent': 'StarlinkDashboard/0.2 RSS reader', 'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml'})
        with urllib.request.build_opener(FeedRedirect()).open(req, timeout=15) as response:
            payload = response.read(MAX_BYTES + 1)
        result['publisher'], result['articles'] = parse_feed(payload, url, count)
    except urllib.error.HTTPError as exc:
        result['error'] = 'Feed server returned HTTP ' + str(exc.code)
    except (OSError, ValueError, ET.ParseError, urllib.error.URLError):
        result['error'] = 'Could not load this feed. Check the URL and connection.'
    return result

def main():
    request = json.loads(sys.stdin.readline(65536))
    feeds = request.get('feeds', [])[:10]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(fetch, feeds))
    print(json.dumps({'feeds': results}, ensure_ascii=False))

if __name__ == '__main__':
    main()
