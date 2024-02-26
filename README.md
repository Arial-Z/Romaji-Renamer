# Plex-Romaji-Renamer

A Bash script to import Anilist and MAL data to your Plex Media Server. This is done with a Plex-Meta-Manager (PMM) metadata file.<br/>

Discord : [![Discord Shield](https://discordapp.com/api/guilds/1209232071902363779/widget.png?style=shield)](https://discord.com/invite/VCEEsp39nh)

Here what will be imported for each of your animes :
```yml
# TVDB_ID for PMM to import
330692:
  # Title : either Romaji title or English title (in settings) (from Anilist)
  title: "Yuru Camp△"
  # Sort Title : either Romaji title or English title (in settings) (from Anilist)
  sort_title: "Yuru Camp△"
  # original_title : English title or Native Title (from Anilist)
  original_title: "ゆるキャン△"
  # Genre ands tags from Anilist (genres, and tag above > 70% can be changed in settings)
  genre.sync: Anime,Slice of Life,CGDCT,Iyashikei
  # Airing status add as a label : Planned, Airing or Ended (from Anilist)
  label: Planned
  label.remove: Airing,Ended
  # Studio from Anilist                               
  studio: C-Station
  # Season import
  seasons:
    # Season 0 import
    0:
      label.remove: score
    # Season 1 import
    1:
      # Title from Anilist (Romaji or English from the title setting)
      title: "Yuru Camp△"
      # Rating from Anilist or MAL (in settings)
      user_rating: 8.3
      # Add label score to use with PMM overlays and also add the season label (optionnal)
      label: Fall 2021, score
    # Season 2 import
    2:
      # Title from Anilist (Romaji or English from the title setting)
      title: "Yuru Camp△ SEASON 2"
      # Rating from Anilist or MAL (in settings)
      user_rating: 8.5
      # Add label score to use PMM overlays and also add the season label (optionnal)
      label: Fall 2022,score
  # Anime rating : average rating of the seasons (Or Anilist / MAL score if no seasons)
  critic_rating: 8.4

```
Anilist Posters for animes and seasons can also be downloaded and imported to plex with the PMM assets folder

The seasonal-animes-download.sh can create a list of the new seasonal animes (New as not a sequel anime) and make a collection yml to add them to sonarr.

Designed for Plex TV agent / Plex Movie Agent, <b>Hama is unsupported</b>
  
 ## How it works:
  - Plex-Romaji-Renamer will export your Animes and TVDB/IMDB IDs from Plex with python plexapi
  - Then it will then retrieve their MAL/Anilist IDs from my mapping list https://github.com/Arial-Z/Animes-ID
  - Use the Anilist API and Jikan API to get metadata from Anilist and MAL
  - Create and update a PMM metadata file to import everything in to your Plex when PMM runs.

### Docker container avalaible here
https://hub.docker.com/r/arialz/plex-romaji-renamer

### Step 1 - Prerequisites
First you need a GNU/Linux OS to run bash script<br/>
  Requirements: Plex Media Server, Plex-Meta-Manager, Python and JQ<br/>
  - Install and configure Plex-Meta-Manager: https://github.com/meisnate12/Plex-Meta-Manager<br/>
  - Install JQ is a json parser see: https://stedolan.github.io/jq/ (Present by default on unRAID 6.10.0 and later.)<br/>
  - install python plexapi
  ```
  pip install plexapi
  ```
  - install python-dotenv
  ```
  pip install python-dotenv
  ```

### Step 2 - Download and extract the script
Git clone the **main** branch or get lastest release : https://github.com/Arial-Z/Plex-Romaji-Renamer/releases/latest

### Step 3 - Configure the script
  - Extract the script on a desired location.<br/>
  - Navigate to its location.<br/>
  - Copy default.env to config/.env<br/>
  - cd into the config folder and edit .env to fill out the variables.<br/>
```env
#Url of the Plex server (Needed)
plex_url=http://127.0.0.1:32400
#Plex token (Needed)
plex_token=zadazdzadazdazdazdazdazd


# Run the animes script (Yes/No)
RUN_ANIMES_SCRIPT=Yes
# Plex animes library name need to be in a double quote (Needed for the animes script)
ANIME_LIBRARY_NAME="Animes"
# Path to the created animes metadata file (Needed for the animes script)
METADATA_ANIMES=$SCRIPT_FOLDER/pmm/metadata-animes.yml


# Run the movies script (Yes/No)
RUN_MOVIES_SCRIPT=No
# Plex movies animes library name need to be in a double quote (Needed for the movies script)
MOVIE_LIBRARY_NAME="Animes Movies"
# Path to the created movies metadata file (Needed for the movies script)
METADATA_MOVIES=$SCRIPT_FOLDER/pmm/metadata-animes-movies.yml

# Run the seasonal download script (Yes/No)
RUN_SEASONAL_SCRIPT=No
# Number of animes added to the sesonal animes auto-download collection (Needed for the seasonal-animes-download.sh script)
DOWNLOAD_LIMIT=20
# Path to the created seasonal-animes-download file (Needed for the seasonal-animes-download.sh script)
DOWNLOAD_ANIMES_COLLECTION=$SCRIPT_FOLDER/pmm/seasonal-animes-download.yml


# PMM Asset Folder to import posters (Needed)
ASSET_FOLDER=$SCRIPT_FOLDER/pmm/assets
# Folder where the logs of script are kept (Default is okay change if you want)
LOG_FOLDER=$SCRIPT_FOLDER/config/logs


# Type of rating used in Plex by Anilist (audience, critic, user / leave empty to disable)
WANTED_RATING=audience
# Source for RATING (MAL / ANILIST)
RATING_SOURCE=ANILIST
# Use the english name as title (and also sort_title) instead of the romaji one, the romaji title will be set as original title (Yes/No)
MAIN_TITLE_ENG=No
# Use the english name as sort_title instead of the romaji one (Yes/No)
SORT_TITLE_ENG=No
# Use the native name as original_title instead of the romaji/english one (Yes/No)
ORIGINAL_TITLE_NATIVE=Yes
#Grab anilist tags higher or equal than percentage (0-100)
ANILIST_TAGS_P=70
# Download poster (Yes/No)
POSTER_DOWNLOAD=Yes
# Download seasons poster (Yes/No)
POSTER_SEASON_DOWNLOAD=Yes
# Source for poster (MAL / ANILIST)
POSTER_SOURCE=ANILIST
# Ignore seasons rating and poster (Yes/No)
IGNORE_SEASONS=No
# Anilist have some full uppercase title, this settings will remove them "86 EIGHTY-SIX" > "86 Eighty-Six" (Yes/No)
REDUCE_TITLE_CAPS=Yes
#Add the anime season to the season label in plex (Fall  2022, Spring 2021, ...)
SEASON_YEAR=No
# Anime metadata cache time (in days min : 1)
DATA_CACHE_TIME=3
```

### Step 4 - Configure PMM 
  - Within your (PMM) config.yml add the following metadata_path, it should look like this with the default filepath:
```yml
  Animes:
    metadata_path:
    - file: config/metadata-animes.yml
```
Configuration finished.
### Running the bash script manually or via CRON.

Run the script with bash:<br/>
```
bash path/to/plex-romaji-renamer.sh
```
You can also add it to CRON and make sure to run it before PMM (be careful it take a little time to run due to API limit rate)

### override-ID
Some animes won't be matched and the metadata will be missing, you can see them error in the log, in PMM metadata files or plex directly<br/>
Cause are missing MAL ID for the TVDB ID / IMDB ID<br/>
#### Animes
to fix animes ID you can create a request at https://github.com/Anime-Lists/anime-lists/<br/>
you can also use the override file, in the config folder copy `override-ID-animes.tsv.example` to `override-ID-animes.tsv` and add new entries, it look like this, be carreful to use **tab** as separator even the empty one (title, studio and ignore_seasons are optional and can be used to force corresponding string)
```tsv
tvdb-id	anilist-id	Title	Studio	ignore_seasons	notes
114801	6702		A-1 Pictures	yes	Fairy Tail
79685	263	Hajime no Ippo		
76013	627	Major			
```
create a new line and manually enter the TVDB-ID and MAL-ID, MAL-TITLE<br/>
#### Movies
to fix movies ID you can create a request at https://github.com/Anime-Lists/anime-lists/<br/>
you can also use the override file, in the config folder copy `override-ID-movies.tsv.example` to `override-ID-movies.tsv` and add new entries, it look like this, be carreful to use **tab** as separator even the empty one (title and studio are optional and can be used to force corresponding string)
```tsv
imdb-id	anilist-id	Title	Studio	notes
tt0110008	1030		Studio Ghibli	Pompoko
```
create a new line and manually enter the IMDB-ID and MAL-ID, MAL-TITLE

### Thanks
  - To Plex for Plex
  - To meisnate12 for Plex-Meta-Manager.
  - To plexapi
  - To https://jikan.moe/ for their MAL API.
  - To MAL for being here.
  - To Anilist for being here too.
  - And to a lot of random people from everywhere for all my copy / paste code.
