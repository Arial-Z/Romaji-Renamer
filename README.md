# Plex-Romaji-Renamer

A Bash script to import MAL data to your Plex Media Server. This is done with a Plex-Meta-Manager (PMS) metadata file.<br/>
The following are imported in your PMS:

Here what will be imported for each of your animes :
```
330692:                                                 # TVDB_ID for PMM to import
  title: "Yuru Camp△"                                   # Title from Anilist
  sort_title: "Yuru Camp△"                              # Sort Title : Either Anilist title or English title (in settings)
  original_title: "Laid-Back Camp"                      # English title from MAL
  genre.sync: Anime,Slice of Life,CGDCT,Iyashikei       # All genre from MAL (genres, themes and demographics)
  label.remove: Ongoing                                 # Airing status from MAL (add or remove Ongoing label)
  studio: C-Station                                     # Studio from MAL
  seasons:                                              # Season import
    0:                                                  # Season 0 import                 
      label.remove: score                               
    1:                                                  # Season 1 import
      title: "Yuru Camp△"                               # Title from Anilist                            
      user_rating: 8.3                                  # Rating from MAL
      label: score                                      # Add label score to use PMM overlays
    2:                                                  # Season 1 import
      title: "Yuru Camp△ SEASON 2"                      # Title from Anilist
      user_rating: 8.5                                  # Rating from MAL
      label: score                                      # Add label score to use PMM overlays
  critic_rating: 8.4                                    # Show rating average rating of the seasons (Or MAL score if no seasons)
```
  
Designed for Plex TV agent / Plex Movie Agent, <b>Hama is untested</b>
  
 ## How it works:
  - Plex-Romaji-Renamer will export Anime and TVDBids from python plexapi
  - Then it will then retrieve the tvdb / imdb / MAL / Anilist IDs from my json list
  - Use the Jikan API to get metadata from MAL;
  - Use the anilist API to get the Romaji title;
  - Create and update a PMM metadata file to import everything in to your PMS when PMM runs.

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
  - Rename default.env to .env<br/>
  - Edit config.conf and fill out the variables.<br/>
```
#Url of the Plex server (Needed)
plex_url=http://127.0.0.1:32400

#Plex token (Needed)
plex_token=zadazdzadazdazdazdazdazd

# PMM Asset Folder to import posters (Needed)
ASSET_FOLDER=/path/to/PMM/config/assets

# Plex animes library name need to be in a double quote (Needed for the animes script)
ANIME_LIBRARY_NAME="Animes"

# Plex movies animes library name need to be in a double quote (Needed for the movies script)
MOVIE_LIBRARY_NAME="Animes Movies"

# Path to the created animes metadata file (Needed for the animes script)
METADATA_ANIMES=/path/to/PMM/config/animes-mal.yml

# Path to the created movies metadata file (Needed for the movies script)
METADATA_MOVIES=/path/to/PMM/config/movies-mal.yml

# Folder where the logs of script are kept (Default is okay change if you want)
LOG_FOLDER=$SCRIPT_FOLDER/logs/$(date +%Y.%m.%d).log

# Use the english name as title (and also sort_title) instead of the romaji one (Yes/No)
MAIN_TITLE_ENG=No

# Use the english name as sort_title instead of the romaji one (Yes/No)
SORT_TITLE_ENG=No
```

### Step 4 - Configure PMM 
  - Within your (PMM) config.yml add the following metadata_path, it should look like this with the default filepath:
```
  Animes:
    metadata_path:
    - file: config/animes/animes-mal.yml
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
Cause are missing MAL ID for the TVDB ID / IMDB ID or the first corresponding MAL ID is not the "main" anime<br/>
#### Animes
to fix animes ID you can create a request at https://github.com/Anime-Lists/anime-lists/ you can also directly edit this file : override-ID-animes.tsv<br/>
it look like this, be carreful to use **tab** as separator (studio is optional)
```
tvdb-id	mal-id	Name	Studio
76013	627	Major	
114801	6702	Fairy Tail	A-1 Pictures
```
create a new line and manually enter the TVDB-ID and MAL-ID, MAL-TITLE<br/>
#### Movies
to fix movies ID you can create a request at https://github.com/Anime-Lists/anime-lists/ you can also directly edit this file : override-ID-movies.tsv<br/>
it look like this, be carreful to use **tab** as separator (studio is optional)
```
imdb-id	mal-id	Name	Studio
tt16360006	50549	Bubble
tt9598270	34439	Code Geass: Hangyaku no Lelouch II - Handou
tt9844256	34440	Code Geass: Hangyaku no Lelouch III - Oudou
tt8100900	34438	Code Geass: Hangyaku no Lelouch I - Koudou
tt9277666	6624	Kara no Kyoukai Remix: Gate of Seventh Heaven
tt1155650	2593	Kara no Kyoukai Movie 1: Fukan Fuukei
tt1155651	3782	Kara no Kyoukai Movie 2: Satsujin Kousatsu (Zen)
tt1155652	3783	Kara no Kyoukai Movie 3: Tsuukaku Zanryuu
tt1233474	4280	Kara no Kyoukai Movie 4: Garan no Dou
tt1278060	4282	Kara no Kyoukai Movie 5: Mujun Rasen
```
create a new line and manually enter the IMDB-ID and MAL-ID, MAL-TITLE

### Thanks
  - To Plex for Plex
  - To meisnate12 for Plex-Meta-Manager and Plex-Meta-Manager-Anime-IDs.
  - To plexapi
  - To https://jikan.moe/ for their MAL API.
  - To MAL for being here.
  - To Anilist for being here too.
  - And to a lot of random people from everywhere for all my copy / paste code.
