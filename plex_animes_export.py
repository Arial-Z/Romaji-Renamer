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

plex = PlexServer(url, token, timeout=300)
animes = plex.library.section(ANIME_LIBRARY_NAME)
with open(path.join(basedir, "tmp/plex_animes_export.tsv"), "w") as export_plex, open(path.join(basedir, "tmp/plex_failed_animes.tsv"), "w") as export_fail:
    for video in animes.search():
        title = str(video.title)
        ids = str(video.guids)
        tvdbid = re.search("(?<=tvdb://)(\d+)", ids)
        if ( tvdbid ) :
            tvdb = str(tvdbid.group(1))
            location = str(video.locations)[2:-2]
            path = pathlib.PurePath(location)
            folder = str(path.name)
            seasons = str(video.seasons())
            seasonslist = re.findall("\-(\d*)\>", seasons)
            cleanseasonslist = ',' .join(seasonslist)
            export=(tvdb + "\t" + title + "\t" + folder + "\t" + str(cleanseasonslist) + "\n")
            export_plex.write(export)
        else :
            export=(title + " no id found" + ids + "\n")
            export_fail.write(export)
            print(export)