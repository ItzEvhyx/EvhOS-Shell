#!/usr/bin/env python3
"""Read a player's optional MPRIS TrackList without guessing a queue."""
import json, re, sys
import dbus

def main():
    bus_name=sys.argv[1]
    if not re.fullmatch(r'org\.mpris\.MediaPlayer2\.[A-Za-z0-9_.-]+',bus_name):
        raise ValueError('No media player selected')
    bus=dbus.SessionBus()
    obj=bus.get_object(bus_name,'/org/mpris/MediaPlayer2',introspect=False)
    props=dbus.Interface(obj,'org.freedesktop.DBus.Properties')
    try:
        tracks=props.Get('org.mpris.MediaPlayer2.TrackList','Tracks')
    except dbus.DBusException:
        print(json.dumps({'available':False,'tracks':[]})); return
    current=''
    try: current=str(props.Get('org.mpris.MediaPlayer2.Player','Metadata').get('mpris:trackid',''))
    except dbus.DBusException: pass
    if sys.argv[2:3]==['goto']:
        target=sys.argv[3]
        if target not in [str(x) for x in tracks]: raise ValueError('Track is no longer available')
        dbus.Interface(obj,'org.mpris.MediaPlayer2.TrackList').GoTo(dbus.ObjectPath(target)); return
    ids=[str(x) for x in tracks]
    found=current in ids
    if found: ids=ids[ids.index(current)+1:]
    ids=ids[:80]
    if not ids:
        print(json.dumps({'available':True,'currentKnown':found,'tracks':[]})); return
    tracklist=dbus.Interface(obj,'org.mpris.MediaPlayer2.TrackList')
    metadata=tracklist.GetTracksMetadata(dbus.Array([dbus.ObjectPath(x) for x in ids],signature='o'))
    out=[]
    for i,m in enumerate(metadata):
        artist=m.get('xesam:artist',[])
        if isinstance(artist,(list,tuple,dbus.Array)): artist=', '.join(str(a) for a in artist)
        else: artist=str(artist)
        out.append({'id':str(m.get('mpris:trackid',ids[i])),'title':str(m.get('xesam:title','Untitled track')),'artist':artist,'art':str(m.get('mpris:artUrl',''))})
    print(json.dumps({'available':True,'currentKnown':found,'tracks':out},ensure_ascii=False))
if __name__=='__main__':
    try: main()
    except Exception as e:
        print(json.dumps({'available':False,'tracks':[],'error':str(e)})); sys.exit(1)
