# Plex-Romaji-Renamer

Bash script to import MAL metadata to plex with a PMM metadata file<br/>
what is imported :
  - Romaji title (from Anilist) to title
  - English title  to original title
  - Mal Score to critic rating
  - Mal tags
  - Studios
  - Mal Poster
  - Airing status (As Label)
  
  Designed for Plex TV agent / Plex Movie Agent, <b>Hama is untested</b>
  
 ## How it work
  - it export your library animes title and tvdbid from PMM
  - retrieve the MAL ID from a modified PMM animes ID https://github.com/meisnate12/Plex-Meta-Manager-Anime-IDs
  - Use the Jikan API to get MAL metadata
  - Use the anilist API to get romaji title
  - Create and update a PMM metadata file to import everything in plex when PMM run


### Step 1 - Bash, Plex, Plex-Meta-Manager and JQ
First you need a GNU/Linux OS tu run bash script<br/>
Then plex, Plex-Meta-Manager and JQ<br/>
to install and use Plex-Meta-Manager see : https://github.com/meisnate12/Plex-Meta-Manager<br/>
to install jq which is a json parser see : https://stedolan.github.io/jq/

### Step 2 - Download and extract the script
Git clone the **main** branch or get lastest release : https://github.com/Arial-Z/Plex-Romaji-Renamer/releases/latest

### Step 3 - Configure the script
extract script somewhere<br/>
Go to the script folder<br/>
and rename config.delfaut to config.conf<br/>
edit config.conf to add your config and path<br/>
```
# PMM_INSTALL_TYPE either "python_venv", "docker" or"python"
PMM_INSTALL_TYPE=docker
# DOCKER_CONTAINER_NAME Only for docker
DOCKER_CONTAINER_NAME=plex-meta-manager
# PMM_FOLDER PMM base folder for Python install skip if docker install
PMM_FOLDER=/path/to/plexmetamanager
# PMM_FOLDER_CONFIG for all install type
PMM_FOLDER_CONFIG=/path/to/plexmetamanager-config-folder
LOG_FOLDER=$SCRIPT_FOLDER/logs/$(date +%Y.%m.%d).log
animes_titles=$PMM_FOLDER/config/animes/animes-mal.yml
movies_titles=$PMM_FOLDER/config/animes/movies-mal.yml
```

### Step 4 - Configure PMM
Then you need to create a PMM config for exporting anime name and the corresponding tvdb-id<br/>
copy your "config.yml" in your config folder in PMM to "temp-animes.yml"<br/>
Path need to be : plexmetamanager_folder/config/temp-animes.yml<br/>
and modify the library to only leave your Animes library name<br/>
```
libraries:
  Animes:

settings:
...
```
You only need plex and tmdb to be configured<br/>
If you also want to run the movies animes script you need to create another PMM config exactly like the anime one but with your Animes Movies library name<br/>
<br/>
Path need to be : plexmetamanager_folder/config/temp-movies.yml<br/>
Then you need to add the metadata file to your Animes Library in the PMM config file should look like this with the default path and filename :
```
  Animes:
    metadata_path:
    - file: config/animes/animes-mal.yml
```
### and you're done
Run the script with bash :<br/>
```
bash path/to/animes-renamer.sh
bash path/to/movies-renamer.sh
```
You can also add it to cron and make it run before PMM (be carreful it take a little time to run due to API limit rate)

### override-ID
some animes won't be matched and the metadata will be missing, you can see them error in the log, in PMM metadata files or plex directly<br/>
Cause are missing MAL ID for the TVDB ID / IMDB ID or the first corresponding MAL ID is not the "main" anime<br/>
#### Animes
to fix animes ID you can create at https://github.com/Anime-Lists/anime-lists/ you can also directly edit this file : override-ID-animes.tsv<br/>
it look like this, be carreful to use **tab** as separator (studio is optional)
```
tvdb-id	mal-id	Name	Studio
76013	627	Major	
114801	6702	Fairy Tail	A-1 Pictures
```
create a new line and manually enter the TVDB-ID and MAL-ID, MAL-TITLE<br/>
#### Movies
to fix movies ID you can create at https://github.com/Anime-Lists/anime-lists/ you can also directly edit this file : override-ID-movies.tsv<br/>
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
  - to Plex for Plex
  - To meisnate12 for Plex-Meta-Manager and Plex-Meta-Manager-Anime-IDs
  - To https://jikan.moe/ for their MAL API
  - To MAL for being here
  - To Anilist for being here too
  - And to a lot of random people from everywhere for all my copy / paste code
