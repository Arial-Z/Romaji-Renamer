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
	find "$SCRIPT_FOLDER/data/*" -mtime +"$DATA_CACHE_TIME" -exec rm {} \;        #delete json data if older than 2 days
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

# Download anime mapping json data
download-anime-id-mapping


# export movies list from plex
python3 "$SCRIPT_FOLDER/plex_movies_export.py"

# create ID/movies.tsv ( imdb_id | mal_id | anime_title | plex_title )
create-override
while IFS=$'\t' read -r imdb_id anilist_id title_override studio                                                                       # First add the override animes to the ID file
do
	if ! awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/ID/movies.tsv" | grep -w  "$imdb_id"
	then
		if awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/tmp/plex_movies_export.tsv" | grep -w  "$imdb_id"
		then
			line=$(awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/tmp/plex_movies_export.tsv" | grep -w -n "$imdb_id" | cut -d : -f 1)
			plex_title=$(sed -n "${line}p" "$SCRIPT_FOLDER/tmp/plex_movies_export.tsv" | awk -F"\t" '{print $2}')
			asset_name=$(sed -n "${line}p" "$SCRIPT_FOLDER/tmp/plex_movies_export.tsv" | awk -F"\t" '{print $3}')
			printf "%s\t%s\t%s\t%s\t%s\n" "$imdb_id" "$mal_id" "$anilist_id" "$plex_title" "$asset_name" >> "$SCRIPT_FOLDER/ID/movies.tsv"
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - override found for : $anime_title / $plex_title" >> "$LOG"
		fi
	fi
done < "$SCRIPT_FOLDER/override-ID-movies.tsv"
while IFS=$'\t' read -r imdb_id plex_title asset_name                                                                                      # then get the other ID from the ID mapping and download json data
do
	if ! awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/ID/movies.tsv" | grep -w  "$imdb_id"
		then
		anilist_id=$(get-anilist-id)
		if [[ "$anilist_id" == 'null' ]] || [[ "${#anilist_id}" == '0' ]]                               # Ignore anime with no tvdb to mal id conversion show in the error log you need to add them by hand in override
		then
			echo "invalid Anilist ID for imdb : $imdb_id / $plex_title" >> "$MATCH_LOG"
			continue
		fi
		get-anilist-infos
		anime_title=$(get-romaji-title)
		printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$imdb_id" "$mal_id" "$anilist_id" "$anime_title" "$plex_title" "$asset_name" >> "$SCRIPT_FOLDER/ID/movies.tsv"
		echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $anime_title / $plex_title added to ID/movies.tsv" >> "$LOG"
	fi
done < "$SCRIPT_FOLDER/tmp/plex_movies_export.tsv"

# write PMM metadata file from ID/movies.tsv and jikan API
printf "metadata:\n" > "$METADATA"
while IFS=$'\t' read -r imdb_id anilist_id plex_title asset_name
do
	write-metadata
done < "$SCRIPT_FOLDER/ID/movies.tsv"
exit 0