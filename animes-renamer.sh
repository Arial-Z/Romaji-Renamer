#!/bin/bash

export LC_ALL=en_US.UTF-8
SCRIPT_FOLDER=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
media_type="animes"
source "$SCRIPT_FOLDER/.env"
source "$SCRIPT_FOLDER/functions.sh"
METADATA=$METADATA_ANIMES
OVERRIDE=override-ID-$media_type.tsv

# check if files and folder exist
if [ ! -d "$SCRIPT_FOLDER/data" ]										#check if exist and create folder for json data
then
	mkdir "$SCRIPT_FOLDER/data"
else
	find "$SCRIPT_FOLDER/data/" -type f -mtime +"$DATA_CACHE_TIME" -exec rm {} \;					#delete json data if older than 2 days
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
:> "$SCRIPT_FOLDER/ID/animes.tsv"
:> "$MATCH_LOG"
printf "%s - Starting script\n\n" "$(date +%H:%M:%S)"

# Download anime mapping json data
download-anime-id-mapping

# export animes list from plex
printf "%s - Exporting Plex animes library\n" "$(date +%H:%M:%S)"
python3 "$SCRIPT_FOLDER/plex_animes_export.py"
printf "%s - Done\n\n" "$(date +%H:%M:%S)"

# create ID/animes.tsv
create-override
printf "%s - Sorting plex anime list\n" "$(date +%H:%M:%S)"
while IFS=$'\t' read -r tvdb_id anilist_id title_override studio ignore_seasons					# First add the override animes to the ID file
do
	if ! awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/ID/animes.tsv" | grep -q -w "$tvdb_id"
	then
		if awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/tmp/plex_animes_export.tsv" | grep -q -w "$tvdb_id"
		then
			line=$(awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/tmp/plex_animes_export.tsv" | grep -w -n "$tvdb_id" | cut -d : -f 1)
			plex_title=$(sed -n "${line}p" "$SCRIPT_FOLDER/tmp/plex_animes_export.tsv" | awk -F"\t" '{print $2}')
			asset_name=$(sed -n "${line}p" "$SCRIPT_FOLDER/tmp/plex_animes_export.tsv" | awk -F"\t" '{print $3}')
			last_season=$(sed -n "${line}p" "$SCRIPT_FOLDER/tmp/plex_animes_export.tsv" | awk -F"\t" '{print $4}')
			total_seasons=$(sed -n "${line}p" "$SCRIPT_FOLDER/tmp/plex_animes_export.tsv" | awk -F"\t" '{print $5}')
			printf "%s - Found override for tvdb id : %s / anilist id : %s\n" "$(date +%H:%M:%S)" "$tvdb_id" "$anilist_id"
			printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$tvdb_id" "$anilist_id" "$plex_title" "$asset_name" "$last_season" "$total_seasons" >> "$SCRIPT_FOLDER/ID/animes.tsv"
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - override found for tvdb : $tvdb_id / $plex_title" >> "$LOG"
		fi
	fi
done < "$SCRIPT_FOLDER/override-ID-animes.tsv"
while IFS=$'\t' read -r tvdb_id plex_title asset_name last_season total_seasons 		# then get the other ID from the ID mapping and download json data
do
	if ! awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/ID/animes.tsv" | grep -q -w "$tvdb_id"
	then
		anilist_id=$(get-anilist-id)
		if [[ "$anilist_id" == 'null' ]] || [[ "${#anilist_id}" == '0' ]]				# Ignore anime with no anilist id
		then
			printf "%s - Invalid Anilist ID for tvdb : %s / %s\n" "$(date +%H:%M:%S)" "$tvdb_id" "$plex_title"
			echo "invalid Anilist ID for tvdb : $tvdb_id / $plex_title" >> "$MATCH_LOG"
		else
			printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$tvdb_id" "$anilist_id" "$plex_title" "$asset_name" "$last_season" "$total_seasons" >> "$SCRIPT_FOLDER/ID/animes.tsv"
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - tvdb : $tvdb_id / $plex_title added to ID/animes.tsv" >> "$LOG"
		fi
	fi
done < "$SCRIPT_FOLDER/tmp/plex_animes_export.tsv"
printf "%s - Done\n\n" "$(date +%H:%M:%S)"

# Create an ongoing list at $SCRIPT_FOLDER/data/ongoing.csv
printf "%s - Creating Anilist airing list\n" "$(date +%H:%M:%S)"
:> "$SCRIPT_FOLDER/data/ongoing.tsv"
:> "$SCRIPT_FOLDER/tmp/ongoing-tmp.tsv"
ongoingpage=1
while [ $ongoingpage -lt 9 ];													# get the airing list from jikan API max 9 pages (225 animes)
do
	printf "%s - Downloading anilist airing list page : %s\n" "$(date +%H:%M:%S)" "$ongoingpage"
	curl -s 'https://graphql.anilist.co/' \
	-X POST \
	-H 'content-type: application/json' \
	--data '{ "query": "{ Page(page: '"$ongoingpage"', perPage: 50) { pageInfo { hasNextPage } media(type: ANIME, status_in: RELEASING, sort: POPULARITY_DESC) { id } } }" }' > "$SCRIPT_FOLDER/tmp/ongoing-anilist.json" -D "$SCRIPT_FOLDER/tmp/anilist-limit-rate.txt"
	rate_limit=0
	rate_limit=$(grep -oP '(?<=x-ratelimit-remaining: )[0-9]+' "$SCRIPT_FOLDER/tmp/anilist-limit-rate.txt")
	if [[ rate_limit -lt 3 ]]
	then
		printf "%s - Anilist API limit reached watiting 30s" "$(date +%H:%M:%S)"
		sleep 30
	else
		sleep 0.7
		printf "%s - done\n" "$(date +%H:%M:%S)"
	fi
	jq '.data.Page.media[].id' -r "$SCRIPT_FOLDER/tmp/ongoing-anilist.json" >> "$SCRIPT_FOLDER/tmp/ongoing-tmp.tsv"		# store the mal ID of the ongoing show
	if grep -q -w ":false}" "$SCRIPT_FOLDER/tmp/ongoing-anilist.json"														# stop if page is empty
	then
		break
	fi
	((ongoingpage++))
done
	printf "%s - Sorting anilist airing list \n" "$(date +%H:%M:%S)"
sort -n "$SCRIPT_FOLDER/tmp/ongoing-tmp.tsv" | uniq > "$SCRIPT_FOLDER/tmp/ongoing.tsv"
while read -r anilist_id
do
	if awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/ID/animes.tsv" | grep -q -w  "$anilist_id"
	then
		line=$(awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/ID/animes.tsv" | grep -w -n "$anilist_id" | cut -d : -f 1)
		tvdb_id=$(sed -n "${line}p" "$SCRIPT_FOLDER/ID/animes.tsv" | awk -F"\t" '{print $1}')
		printf "%s\n" "$tvdb_id" >> "$SCRIPT_FOLDER/data/ongoing.tsv"
	else
		tvdb_id=$(get-tvdb-id)																	# convert the mal id to tvdb id (to get the main anime)
		if [[ "$tvdb_id" == 'null' ]] || [[ "${#tvdb_id}" == '0' ]]										# Ignore anime with no mal to tvdb id conversion
		then
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - Ongoing invalid TVDB ID for Anilist : $anilist_id" >> "$LOG"
			continue
		else
			printf "%s\n" "$tvdb_id" >> "$SCRIPT_FOLDER/data/ongoing.tsv"
		fi
	fi
done < "$SCRIPT_FOLDER/tmp/ongoing.tsv"
printf "%s - Done\n\n" "$(date +%H:%M:%S)"

# write PMM metadata file from ID/animes.tsv and jikan API
printf "%s - Start wrinting the metadata file \n" "$(date +%H:%M:%S)"
printf "metadata:\n" > "$METADATA"
while IFS=$'\t' read -r tvdb_id anilist_id plex_title asset_name last_season total_seasons
do
	printf "%s - Writing metadata for tvdb id : %s / Anilist id : %s \n" "$(date +%H:%M:%S)" "$tvdb_id" "$anilist_id"
	write-metadata
done < "$SCRIPT_FOLDER/ID/animes.tsv"
printf "%s - Run finished\n" "$(date +%H:%M:%S)"
exit 0