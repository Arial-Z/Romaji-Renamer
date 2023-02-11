from plexapi.server import PlexServer
import re
import pathlib

plex = PlexServer(plex_url, plex_token)
movies = plex.library.section('Animes Films')
animes = plex.library.section('Animes')
with open("export_plex_animes.tsv", "w") as export_plex:
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
with open("export_plex_movies.tsv", "w") as export_plex:
        export_plex.write("imdb_id\tplex_title\tfolder\tseason\n")
        for video in movies.search():
                title = str(video.title)
                ids = str(video.guids)
                imdb = re.search("(?<=imdb://)(\d+)", ids).group()
                location = str(video.locations)[2:-2]
                path = pathlib.PurePath(location)
                folder = str(path.name)
                export=(tvdb + "\t" + title + "\t" + folder + "\n")
                export_plex.write(export)