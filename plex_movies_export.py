from plexapi.server import PlexServer
from dotenv import load_dotenv
from os import environ
from pathlib import Path, PureWindowsPath, PurePosixPath
import re

# Find .env file
basedir = Path(__file__).parent
load_dotenv(Path(basedir, "config/.env"))

# General Config
url = environ.get('plex_url')
token = environ.get('plex_token')
MOVIE_LIBRARY_NAME=environ.get('MOVIE_LIBRARY_NAME')

plex = PlexServer(url, token, timeout=300)
movies = plex.library.section(MOVIE_LIBRARY_NAME)
with open(Path(basedir, "config/tmp/plex_movies_export.tsv"), "w") as export_plex, open(Path(basedir, "config/tmp/plex_failed_movies.tsv"), "w") as export_fail:
	for video in movies.search():
		title = str(video.title)
		ids = str(video.guids)
		imdbid = re.search("(?<=imdb://)(tt\d+)", ids)
		if ( imdbid ) :
			imdb = str(imdbid.group(1))
			location = str(video.locations)[2:-2]
			if (re.match("^.*(\\\\.*)$", location)) :
				folder = str(PureWindowsPath(location).parent.name)
			else :
				folder = str(PurePosixPath(location).parent.name)
			export=(imdb + "\t" + title + "\t" + folder + "\n")
			export_plex.write(export)
		else :
			export=(title + " no id found" + ids + "\n")
			export_fail.write(export)
			print(export)