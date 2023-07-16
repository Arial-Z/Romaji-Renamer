#!/bin/bash

export LC_ALL=en_US.UTF-8
SCRIPT_FOLDER=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
echo "$SCRIPT_FOLDER"
media_type="movies"
source "$SCRIPT_FOLDER/.env"
source "$SCRIPT_FOLDER/functions.sh"
METADATA=$METADATA_MOVIES
OVERRIDE=override-ID-$media_type.tsv

# check if files and folder exist
if [ ! -d "$SCRIPT_FOLDER/data" ]                                                                                 #check if exist and create folder for json data
then
	mkdir "$SCRIPT_FOLDER/data"
else
	find "$SCRIPT_FOLDER/data/" -type f -mtime +"$DATA_CACHE_TIME" -exec rm {} \;        #delete json data if older than 2 days
fi
if [ ! -d "$SCRIPT_FOLDER/tmp" ]										#check if exist and create folder for json data
then
	mkdir "$SCRIPT_FOLDER/tmp"
fi
if [ ! -d "$SCRIPT_FOLDER/ID" ]											#check if exist and create folder and file for ID
then
	mkdir "$SCRIPT_FOLDER/ID"
fi
if [ ! -d "$LOG_FOLDER" ]
then
	mkdir "$LOG_FOLDER"
fi
:> "$SCRIPT_FOLDER/ID/movies.tsv"
:> "$MATCH_LOG"
printf "%s - Starting script\n\n" "$(date +%H:%M:%S)" | tee -a "$LOG"

# Download anime mapping json data
download-anime-id-mapping


# export movies list from plex
printf "%s - Creating anime list\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
printf "%s\t - Exporting Plex anime library\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
python3 "$SCRIPT_FOLDER/plex_movies_export.py"
printf "%s\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"

# create ID/movies.tsv ( imdb_id | mal_id | anime_title | plex_title )
create-override
printf "%s\t - Sorting Plex anime library\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
while IFS=$'\t' read -r imdb_id anilist_id title_override studio notes
do
	if ! awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/ID/movies.tsv" | grep -q -w  "$imdb_id"
	then
		if awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/tmp/plex_movies_export.tsv" | grep -q -w  "$imdb_id"
		then
			line=$(awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/tmp/plex_movies_export.tsv" | grep -w -n "$imdb_id" | cut -d : -f 1)
			plex_title=$(sed -n "${line}p" "$SCRIPT_FOLDER/tmp/plex_movies_export.tsv" | awk -F"\t" '{print $2}')
			asset_name=$(sed -n "${line}p" "$SCRIPT_FOLDER/tmp/plex_movies_export.tsv" | awk -F"\t" '{print $3}')
			printf "%s\t\t - Found override for imdb id : %s / anilist id : %s\n" "$(date +%H:%M:%S)" "$imdb_id" "$anilist_id" | tee -a "$LOG"
			printf "%s\t%s\t%s\t%s\t%s\n" "$imdb_id" "$mal_id" "$anilist_id" "$plex_title" "$asset_name" >> "$SCRIPT_FOLDER/ID/movies.tsv"
		fi
	fi
done < "$SCRIPT_FOLDER/override-ID-movies.tsv"
while IFS=$'\t' read -r imdb_id plex_title asset_name                                                                                      # then get the other ID from the ID mapping and download json data
do
	if ! awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/ID/movies.tsv" | grep -q -w  "$imdb_id"
		then
		anilist_id=$(get-anilist-id)
		if [[ "$anilist_id" == 'null' ]] || [[ "${#anilist_id}" == '0' ]]                               # Ignore anime with no tvdb to mal id conversion show in the error log you need to add them by hand in override
		then
			printf "%s\t\t - Missing Anilist ID for imdb : %s / %s\n" "$(date +%H:%M:%S)" "$imdb_id" "$plex_title" | tee -a "$LOG"
			printf "%s - Missing Anilist ID for imdb : %s / %s\n" "$(date +%H:%M:%S)" "$imdb_id" "$plex_title" >> "$MATCH_LOG"
			continue
		fi
		printf "%s\t%s\t%s\t%s\t%s\n" "$imdb_id" "$mal_id" "$anilist_id" "$plex_title" "$asset_name" >> "$SCRIPT_FOLDER/ID/movies.tsv"
	fi
done < "$SCRIPT_FOLDER/tmp/plex_movies_export.tsv"
printf "%s - Done\n\n" "$(date +%H:%M:%S)" | tee -a "$LOG"

# write PMM metadata file from ID/movies.tsv and jikan API
printf "%s - Start wrinting the metadata file \n" "$(date +%H:%M:%S)" | tee -a "$LOG"
printf "metadata:\n" > "$METADATA"
while IFS=$'\t' read -r imdb_id anilist_id plex_title asset_name
do
	printf "%s\t - Writing metadata for imdb id : %s / Anilist id : %s \n" "$(date +%H:%M:%S)" "$imdb_id" "$anilist_id" | tee -a "$LOG"
	write-metadata
	printf "%s\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
done < "$SCRIPT_FOLDER/ID/movies.tsv"
printf "%s - Run finished\n\n\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
exit 0