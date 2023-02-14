from plexapi.server import PlexServer
from dotenv import load_dotenv
from os import environ, path
import re
import pathlib

# Find .env file
basedir = path.abspath(path.dirname(__file__))
load_dotenv(path.join(basedir, '.env'))

# General Config
url = environ.get('plex_url')
token = environ.get('plex_token')
ANIME_LIBRARY_NAME=environ.get('ANIME_LIBRARY_NAME')

plex = PlexServer(url, token)
animes = plex.library.section(ANIME_LIBRARY_NAME)
with open("tmp/plex_animes_export.tsv", "w") as export_plex:
        for video in animes.search():
                title = str(video.title)
                ids = str(video.guids)
                tvdb = re.search("(?<=tvdb://)(\d+)", ids).group()
                location = str(video.locations)[2:-2]
                path = pathlib.PurePath(location)
                folder = str(path.name)
                seasons = video.str(video.seasons())
                last_season = re.search("(\d+)(?!.*\d)", seasons).group()
                export=(tvdb + "\t" + title + "\t" + folder + "\t"+ last_season + "\n")
                export_plex.write(export)
