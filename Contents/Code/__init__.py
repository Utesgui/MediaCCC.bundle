import requests
import json
from datetime import datetime

NAME = 'Media CCC'
ICON = 'icon-default.png'
ART = 'art-default.jpg'

BASE_URL = 'http://api.media.ccc.de/public/'

def Start():
    pass

def handler(route, name, allow_sync=False):
    def decorator(func):
        func.route = route
        func.name = name
        func.allow_sync = allow_sync
        return func
    return decorator

def route(route):
    def decorator(func):
        func.route = route
        return func
    return decorator

@handler('/video/mediaccc', NAME, allow_sync=True)
def showDir(subdir=''):
    response = requests.get(BASE_URL + 'conferences')
    data = response.json()

    oc = []

    subdirs = set()
    if subdir == '':
        depth = 0
    else:
        depth = len(subdir.split('/'))
        top, down, children = split_pathname(subdir, depth - 1)
        oc.append({'title': down.title()})

    folders = []
    conferences = []

    for conference in sorted(data['conferences'], key=lambda conference: conference['webgen_location']):
        top, down, children = split_pathname(conference['webgen_location'], depth)

        if top != subdir or down in subdirs:
            continue

        if children:
            folders.append({'key': showDir, 'subdir': build_path(top, down), 'title': down.title(), 'thumb': ICON})
            subdirs.add(down)
        else:
            conferences.append({'key': showConference, 'acronym': conference['acronym'], 'title': conference['title'], 'thumb': conference['logo_url']})

    for folder in folders:
        oc.append(folder)

    for conference in conferences:
        oc.append(conference)

    return oc

@route('/video/mediaccc/conference')
def showConference(acronym):
    response = requests.get(BASE_URL + 'conferences')
    data = response.json()
    conference = [x for x in data['conferences'] if x['acronym'] == acronym][0]

    title = "%s" % (conference['title'])
    oc = [{'title': title}]

    conf_response = requests.get(BASE_URL + 'conferences/' + conference['url'].rsplit('/', 1)[1])
    conf_data = conf_response.json()
    videos = conf_data['events']

    for video in videos:
        event = video['url'].rsplit('/', 1)[1]
        oc.append(CreateVideoClipObject(video=video))

    return oc

@route('/video/mediaccc/event')
def showEvent(event):
    response = requests.get(BASE_URL + 'events/' + event)
    data = response.json()
    want = sorted(filter(is_video, data['recordings']), key=format_priority)

    if len(want) > 0:
        return want[0]['recording_url']

@route('/video/mediaccc/eventcontainer')
def showEventContainer(event):
    response = requests.get(BASE_URL + 'events/' + event)
    data = response.json()
    url = showEvent(event=event)

    videoclip_obj = CreateVideoClipObject(video=data)

    items = []
    for media in sorted(filter(is_video, data['recordings']), key=format_priority):
        if media['mime_type'] != 'video/mp4':
            continue

        items.append({
            'parts': [{'key': url}],
            'container': 'mp4',
            'video_codec': 'h264',
            'video_resolution': media['height'],
            'audio_codec': 'aac',
            'audio_channels': 2,
            'optimized_for_streaming': True
        })

    videoclip_obj['items'] = items

    return [videoclip_obj]

def CreateVideoClipObject(video):
    event = video['url'].rsplit('/', 1)[1]
    url = showEvent(event=event)

    videoclip_obj = {
        'key': showEventContainer(event=event),
        'rating_key': url,
        'title': video['title'],
        'thumb': video['poster_url'],
        'tags': video['tags'],
        'duration': video['length'] * 1000,
        'source_title': "CCC",
        'originally_available_at': datetime.strptime(video['date'], '%Y-%m-%dT%H:%M:%S.%f%z'),
        'year': int(video['release_date'].split('-')[0]),
        'summary': video['description'],
        'items': [{
            'parts': [{'key': url}],
            'container': 'mp4',
            'video_codec': 'h264',
            'video_resolution': '576',
            'audio_codec': 'aac',
            'audio_channels': 2,
            'optimized_for_streaming': True
        }]
    }

    return videoclip_obj

def build_path(top, down):
    if top == '':
        return down
    else:
        return '/'.join((top, down))

def split_pathname(name, depth):
    path = name.split('/')
    top = '/'.join(path[0:depth])
    if depth < len(path):
        down = path[depth]
    else:
        down = None
    children = len(path) - 1 > depth
    return (top, down, children)

def is_video(entry):
    return entry['mime_type'].startswith('video/')

def format_priority(entry):
    enc = entry['mime_type'].split('/')[1]
    if enc == 'mp4':
        return 1
    elif enc == 'webm':
        return 2
    else:
        return 99
