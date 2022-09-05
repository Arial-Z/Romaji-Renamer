# Plex-Romaji-Renamer

Bash script to import MAL metadata to plex with a PMM metadata file<br/>
what is imported :
  - Romaji title
  - Mal Score
  - Mal tags
  - Airing status (As Label)
  - Top 100 & Top 250 animes (TV, OVA & ONA) (as Label)
  - Top 100 movies (As Label)
  - Mal Poster
  
  Designed for Plex TV agent / Plex Movie Agent, Hama is untested
  
 ## How it work
  - it export your library animes title and tvdbid from PMM
  - retrieve the MAL ID from PMM animes ID https://github.com/meisnate12/Plex-Meta-Manager-Anime-IDs
  - Use the Jikan API to get MAL metadata
  - Create and update a PMM metadata file to import everything in plex when PMM run


### Step 1 - Plex, Plex-Meta-Manager and JQ
First you need plex, Plex-Meta-Manager and JQ<br/>
to install and use Plex-Meta-Manager see : https://github.com/meisnate12/Plex-Meta-Manager<br/>
you also need to install jq which is a json parser see : https://stedolan.github.io/jq/

### Step 2 - Download and extract the script
Git clone the release branch or download zip her : https://github.com/Arial-Z/Plex-Romaji-Renamer/archive/refs/heads/release.zip

### Step 3 - Configure the script
Go to the script folder<br/>
and rename config.delfaut to config.conf<br/>
edit the path folder and file<br/>
```
SCRIPT_FOLDER=/path/to/the/script/folder  
PMM_FOLDER=/path/to/plexmetamanager
LOG_PATH=$SCRIPT_FOLDER/logs/$(date +%Y.%m.%d).log # Default log in the script folder (you can change it)
animes_titles=$PMM_FOLDER/config/animes/animes-titles.yml # Default path to the animes metadata files for PMM (you can change it)
movies_titles=$PMM_FOLDER/config/animes/movies-titles.yml # Default path to the movies metadata files for PMM (you can change it)
```

### Step 4 - Configure PMM
Then you need to create a PMM config for exporting anime name and the corresponding tvdb-id<br/>
copy your "config.yml" to "temp-animes.yml"<br/>
and modify the library to only leave your Animes library name<br/>
```
libraries:
  Animes:

settings:
...
```
You only need plex and tmdb to be configured<br/>
<br/>
Then you need to add the metadata file to your Animes Library in the PMM config file should look like this with the default path and filename :
```
  Animes:
    metadata_path:
    - repo: /metadata/animes-airing
    - file: config/animes/animes-mal.yml
```
### and you're done
Run the script with bash :<br/>
```
bash path/to/animes-renamer.sh
bash path/to/movies-renamer.sh
```
You can also add it to cron and make it run before PMM (be carreful it take a little time to run due to Jikan API limit)

### override-ID
some animes won't be matched and the metadata will be missing, you can see them error in the log, in PMM metadata files or plex directly<br/>
Cause are missing MAL ID for the TVDB ID / IMDB ID or the first corresponding MAL ID is not the "main" anime<br/>
#### Animes
to fix animes you need to edit this file : override-ID-animes.tsv<br/>
it look like this, be carreful to use **tab** as separator
```
TVDB-ID	MAL-ID	MAL-TITLE
219771	9513	Beelzebub
331753	34572	Black Clover
305074	31964	Boku no Hero Academia
413555	37914	Chikyuugai Shounen Shoujo
79525	1575	Code Geass: Hangyaku no Lelouch
79895	918	Gintama
```
create a new line and manually enter the TVDB-ID and MAL-ID, MAL-TITLE<br/>
#### Movies
to fix movies you need to edit this file : override-ID-movies.tsv<br/>
it look like this, be carreful to use **tab** as separator
```
IMDB-ID	MAL-ID	MAL-TITLE
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
  - And to a lot of random people from everywhere for all my copy / paste code
