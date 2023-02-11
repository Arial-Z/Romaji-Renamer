# Plex-Romaji-Renamer

A Bash script to import MAL metadata to your Plex Media Server. This is done with a Plex-Meta-Manager (PMS) metadata file.<br/>
The following are imported in your PMS:
  - Romanji title from Anilist.
  - English title from Anilist.
  - MAL score to critics rating.
  - All tags over on MyAnimelist.
  - Studios from MyAnimelist
  - Posters from MyAnimelist.
  - Airing status (As Label).
  
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
  pip install python plexapi
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
#Plex url (Needed)
plex_url=http://127.0.0.1:32400
#Plex token (Needed)
plex_token=zadazdzadazdazdazdazdazd

# PMM_FOLDER_CONFIG (Needed)
PMM_FOLDER_CONFIG=

# PMM Asset Folder to import posters (Needed)
ASSET_FOLDER=$PMM_FOLDER_CONFIG/assets

# Plex animes library name need to be in a double quote (Needed for the animes script)
# If used, uncomment
#ANIME_LIBRARY_NAME="Animes"

# Plex movies animes library name need to be in a double quote (Needed for the movies script)
# If used, uncomment
#MOVIE_LIBRARY_NAME="Animes Movies"

# Folder of where animes-mal.yml and movies-mal.yml are saved. (Needed)
METADATA_ANIMES=$PMM_FOLDER/config/animes/animes-mal.yml
METADATA_MOVIES=$PMM_FOLDER/config/animes/movies-mal.yml

# Folder where the logs of script are kept.
LOG_FOLDER=$SCRIPT_FOLDER/logs/$(date +%Y.%m.%d).log
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
