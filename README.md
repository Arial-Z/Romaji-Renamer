# Plex-Romaji-Renamer

A Bash script to import Anilist data to your Plex Media Server. This is done with a Plex-Meta-Manager (PMS) metadata file.<br/>

Here what will be imported for each of your animes :
```
330692:                                                 # TVDB_ID for PMM to import
  title: "Yuru Camp△"                                   # Title : Either Anilist title or English title (in settings)
  sort_title: "Yuru Camp△"                              # Sort Title : Either Anilist title or English title (in settings)
  original_title: "Laid-Back Camp"                      # English title from Anilist
  genre.sync: Anime,Slice of Life,CGDCT,Iyashikei       # Genre ands tags from Anilist (genres, and tag above > 65%)
  label.remove: Ongoing                                 # Airing status from Anilist (add or remove Ongoing label)
  studio: C-Station                                     # Studio from Anilist
  seasons:                                              # Season import
    0:                                                  # Season 0 import                 
      label.remove: score                               
    1:                                                  # Season 1 import
      title: "Yuru Camp△"                               # Title from Anilist                            
      user_rating: 8.3                                  # Rating from Anilist or MAL
      label: Fall 2021, score                           # Add label score to use PMM overlays and also add the season label (optionnal)
    2:                                                  # Season 2 import
      title: "Yuru Camp△ SEASON 2"                      # Title from Anilist
      user_rating: 8.5                                  # Rating from Anilist or MAL
      label: Fall 2022,score                            # Add label score to use PMM overlays and also add the season label (optionnal)
  critic_rating: 8.4                                    # Show rating average rating of the seasons (Or Anilist/ MAL score if no seasons)
```
Anilist Posters for animes and seasons can also be downloaded and imported inside the PMM assets folder

The seasonal-animes-download.sh can create a list of the new seasonal animes (New as not a sequel anime) and make a collection yml to add them to sonarr.

Designed for Plex TV agent / Plex Movie Agent, <b>Hama is unsupported</b>
  
 ## How it works:
  - Plex-Romaji-Renamer will export your Animes and TVDB/IMDB IDs from Plex with python plexapi
  - Then it will then retrieve their MAL/Anilist IDs from my mapping list https://github.com/Arial-Z/Animes-ID
  - Use the Anilist API and Jikan API to get metadata from MAL
  - Use the anilist API to get the Romaji title
  - Create and update a PMM metadata file to import everything in to your Plex when PMM runs.

### Step 1 - Prerequisites
First you need a GNU/Linux OS to run bash script<br/>
  Requirements: PMS, PMM, Python and JQ<br/>
  - Install and configure Plex-Meta-Manager: https://github.com/meisnate12/Plex-Meta-Manager<br/>
  - Install JQ which is a json parser see: https://stedolan.github.io/jq/ (Present by default on unRAID 6.10.0 and later.)<br/>
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
  - Copy default.env to .env<br/>
  - Edit .env and fill out the variables.<br/>
```
#Url of the Plex server (Needed)
plex_url=http://127.0.0.1:32400
#Plex token (Needed)
plex_token=zadazdzadazdazdazdazdazd


# Plex animes library name need to be in a double quote (Needed for the animes script)
ANIME_LIBRARY_NAME="Animes"
# Plex movies animes library name need to be in a double quote (Needed for the movies script)
MOVIE_LIBRARY_NAME="Animes Movies"


# Path to the created animes metadata file (Needed for the animes script)
METADATA_ANIMES=/path/to/PMM/config/animes-mal.yml
# Path to the created movies metadata file (Needed for the movies script)
METADATA_MOVIES=/path/to/PMM/config/movies-mal.yml
# PMM Asset Folder to import posters (Needed)
ASSET_FOLDER=/path/to/PMM/config/assets
# Folder where the logs of script are kept (Default is okay change if you want)
LOG_FOLDER=$SCRIPT_FOLDER/logs

# Type of rating used in Plex by Anilist (audience, critic, user / leave empty to disable)
WANTED_RATING=audience
# Source for RATING (MAL / ANILIST)
RATING_SOURCE=ANILIST
# Use the english name as title (and also sort_title) instead of the romaji one (Yes/No)
MAIN_TITLE_ENG=No
# Use the english name as sort_title instead of the romaji one (Yes/No)
SORT_TITLE_ENG=No
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
# Mal Data cache time (in days min : 1)
DATA_CACHE_TIME=3


# Number of animes added to the sesonal animes auto-download collection (Needed for the seasonal-animes-download.sh script)
DOWNLOAD_LIMIT=20
# Path to the created seasonal-animes-download file (Needed for the seasonal-animes-download.sh script)
DOWNLOAD_ANIMES_COLLECTION=/path/to/PMM/config/seasonal-animes-download.yml
```

### Step 4 - Configure PMM 
  - Within your (PMM) config.yml add the following metadata_path, it should look like this with the default filepath:
```
  Animes:
    metadata_path:
    - file: config/animes-mal.yml
```
Configuration finished.
### Running the bash script manually or via CRON.

Run the script with bash:<br/>
```
bash path/to/animes-renamer.sh
bash path/to/movies-renamer.sh
```
You can also add it to CRON and make sure to run it before PMM (be careful it take a little time to run due to API limit rate)

### override-ID
Some animes won't be matched and the metadata will be missing, you can see them error in the log, in PMM metadata files or plex directly<br/>
Cause are missing MAL ID for the TVDB ID / IMDB ID<br/>
#### Animes
to fix animes ID you can create a request at https://github.com/Anime-Lists/anime-lists/<br/>
you can also use the override file, copy `override-ID-animes.tsv.example` to `override-ID-animes.tsv` and add new entries, it look like this, be carreful to use **tab** as separator even the empty one (title, studio and ignore_seasons are optional and can be used to force corresponding string)
```
tvdb-id	anilist-id	Title	Studio	ignore_seasons	notes
114801	6702		A-1 Pictures	yes	Fairy Tail
79685	263	Hajime no Ippo		
76013	627	Major			
```
create a new line and manually enter the TVDB-ID and MAL-ID, MAL-TITLE<br/>
#### Movies
to fix movies ID you can create a request at https://github.com/Anime-Lists/anime-lists/<br/>
you can also use the override file, copy `override-ID-movies.tsv.example` to `override-ID-movies.tsv` and add new entries, it look like this, be carreful to use **tab** as separator even the empty one (title and studio are optional and can be used to force corresponding string)
```
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
