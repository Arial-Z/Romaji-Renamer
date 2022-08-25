# Plex-Romaji-Renamer

Bash script to retrieve MAL metadata (from jikan) and import it to plex with PMM metadata file
  - Romaji title
  - Mal Score
  - Mal tags
  - Mal Poster
  
  Will likely only work with plex TV agent and not Hama

### Step 1 - Plex, Plex-Meta-Manager and JQ
First you need plex, Plex-Meta-Manager and JQ
to install and use Plex-Meta-Manager see : https://github.com/meisnate12/Plex-Meta-Manager
you also need to install jq wich is a json parser see : https://stedolan.github.io/jq/

### Step 2 - Download and extract the script
Git clone or download zip here : https://github.com/Arial-Z/PMM-Arialz/archive/refs/heads/main.zip

### Step 3 - Configure the script
Go to the script folder
and rename conf.delfaut to config.conf
edit the path folder and file
```
SCRIPT_FOLDER=/path/to/the/script/folder  
PMM_FOLDER=/path/to/plexmetamanager
LOG_PATH=$SCRIPT_FOLDER/logs/$(date +%Y.%m.%d).log # Default log in the script folder (you can change it)
animes_titles=$PMM_FOLDER/config/animes/animes-titles.yml # Default path to the metadata files for PMM (you can change it)
```

### Step 4 - Configure PMM
Then you need to create a PMM config for exporting anime name and the corresponding tvdb-id
copy your "config.yml" to "temp-animes.yml"
and modify the library to only leave your Animes library name
```
libraries:
  Animes:

settings:
...
```
Then you need to add the metadata file to your  Animes Library in the PMM config file should look like this with the default path and filename :
```
  Animes:
    metadata_path:
    - repo: /metadata/animes-airing
    - file: config/animes/animes-mal.yml
```
### and you're done

### override-ID-animes.csv
some animes won't be matched and the metadata will be missing, you can see the error in the log
to fix this you need to edit this file : override-ID-animes.csv
it look like this
```
TVDB-ID|MAL-ID|MAL-TITLE
219771|9513|Beelzebub
331753|34572|Black Clover
305074|31964|Boku no Hero Academia
413555|37914|Chikyuugai Shounen Shoujo
```
create a new line and manually enter the TVDB-ID and MAL-ID, MAL-TITLE is for readability and do nothing, you need to use | as separator

### Thanks
  - to Plex for Plex
  - To meisnate12 for Plex-Meta-Manager and Plex-Meta-Manager-Anime-IDs
  - To https://jikan.moe/ for their MAL API
  - To MAL for being here
  - And to a lot of random people from everywhere for all my copy / paste code
