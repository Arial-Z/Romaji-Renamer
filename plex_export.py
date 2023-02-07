from plexapi.server import PlexServer
import re
import pathlib

baseurl = 'http://127.0.0.1:32400'
token = 'wYbxVFWMTW_Lm-u6pB3R'
plex = PlexServer(baseurl, token)
movies = plex.library.section('Animes Films')
animes = plex.library.section('Animes')
with open("export_plex.tsv", "w") as export_plex:
        export_plex.write("tvdb_id\tplex_title\tfolder\tseason\n")
        for video in animes.search():
                title = str(video.title)
                ids = str(video.guids)
                tvdb = re.search("(?<=tvdb://)(\d+)", ids).group()
                location = str(video.locations)[2:-2]
                path = pathlib.PurePath(location)
                folder = str(path.name)
                season = str(video.childCount)
                export=(tvdb + "\t" + title + "\t" + folder + "\t"+ season + "\n")
                export_plex.write(export)