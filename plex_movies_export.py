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
MOVIE_LIBRARY_NAME=environ.get('MOVIE_LIBRARY_NAME')

plex = PlexServer(url, token)
movies = plex.library.section(MOVIE_LIBRARY_NAME)
with open(path.join(basedir, "tmp/plex_movies_export.tsv"), "w") as export_plex:
        for video in movies.search():
                title = str(video.title)
                ids = str(video.guids)
                imdb = re.search("(?<=imdb://)(tt\d+)", ids).group()
                location = str(video.locations)[2:-2]
                path = pathlib.PurePath(location)
                folder = str(path.parent.name)
                export=(imdb + "\t" + title + "\t" + folder + "\n")
                export_plex.write(export)
