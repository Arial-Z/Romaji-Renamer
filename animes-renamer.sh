#!/bin/bash

SCRIPT_FOLDER=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
media_type="animes"
source "$SCRIPT_FOLDER/config/.env"
source "$SCRIPT_FOLDER/functions.sh"
METADATA=$METADATA_ANIMES
OVERRIDE=override-ID-$media_type.tsv

# check if files and folder exist
if [ ! -d "$SCRIPT_FOLDER/config/data" ]										#check if exist and create folder for json data
then
	mkdir "$SCRIPT_FOLDER/config/data"
else
	find "$SCRIPT_FOLDER/config/data/" -type f -mtime +"$DATA_CACHE_TIME" -exec rm {} \;					#delete json data if older than 2 days
fi
if [ ! -d "$SCRIPT_FOLDER/config/tmp" ]										#check if exist and create folder for json data
then
	mkdir "$SCRIPT_FOLDER/config/tmp"
fi
if [ ! -d "$SCRIPT_FOLDER/config/ID" ]											#check if exist and create folder and file for ID
then
	mkdir "$SCRIPT_FOLDER/config/ID"
fi
if [ ! -d "$LOG_FOLDER" ]
then
	mkdir "$LOG_FOLDER"
fi
:> "$SCRIPT_FOLDER/config/ID/animes.tsv"
:> "$MATCH_LOG"
printf "%s - Starting animes script\n\n" "$(date +%H:%M:%S)" | tee -a "$LOG"

# Download animes mapping json data & anilist userlist
download-anime-id-mapping
get-anilist-userlist

# export animes list from plex
printf "%s - Creating animes list\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
printf "%s\t - Exporting Plex animes library\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
python3 "$SCRIPT_FOLDER/plex_animes_export.py"
printf "%s\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"

# create ID/animes.tsv
create-override
printf "%s\t - Sorting Plex animes library\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
while IFS= read -r line
do
	tvdb_id=$(printf "%s" "$line" | awk -F"\t" '{print $1}')
	anilist_id=$(printf "%s" "$line" | awk -F"\t" '{print $2}')
	title_override=$(printf "%s" "$line" | awk -F"\t" '{print $3}')
	studio=$(printf "%s" "$line" | awk -F"\t" '{print $4}')
	override_seasons_ignore=$(printf "%s" "$line" | awk -F"\t" '{print $5}')
	if ! awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/config/ID/animes.tsv" | grep -q -w "$tvdb_id"
	then
		if awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/config/tmp/plex_animes_export.tsv" | grep -q -w "$tvdb_id"
		then
			line=$(awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/config/tmp/plex_animes_export.tsv" | grep -w -n "$tvdb_id" | cut -d : -f 1)
			plex_title=$(sed -n "${line}p" "$SCRIPT_FOLDER/config/tmp/plex_animes_export.tsv" | awk -F"\t" '{print $2}')
			asset_name=$(sed -n "${line}p" "$SCRIPT_FOLDER/config/tmp/plex_animes_export.tsv" | awk -F"\t" '{print $3}')
			seasons_list=$(sed -n "${line}p" "$SCRIPT_FOLDER/config/tmp/plex_animes_export.tsv" | awk -F"\t" '{print $4}')
			printf "%s\t\t - Found override for tvdb id : %s / anilist id : %s\n" "$(date +%H:%M:%S)" "$tvdb_id" "$anilist_id" | tee -a "$LOG"
			printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$tvdb_id" "$anilist_id" "$plex_title" "$asset_name" "$seasons_list" "$override_seasons_ignore" >> "$SCRIPT_FOLDER/config/ID/animes.tsv"
		fi
	fi
done < "$SCRIPT_FOLDER/config/override-ID-animes.tsv"
while IFS=$'\t' read -r tvdb_id plex_title asset_name last_season total_seasons 		# then get the other ID from the ID mapping and download json data
do
	if ! awk -F"\t" '{print $1}' "$SCRIPT_FOLDER/config/ID/animes.tsv" | grep -q -w "$tvdb_id"
	then
		anilist_id=$(get-anilist-id)
		if [[ "$anilist_id" == 'null' ]] || [[ "${#anilist_id}" == '0' ]]				# Ignore anime with no anilist id
		then
			printf "%s\t\t - Missing Anilist ID for tvdb : %s / %s\n" "$(date +%H:%M:%S)" "$tvdb_id" "$plex_title" | tee -a "$LOG"
			printf "%s - Missing Anilist ID for tvdb : %s / %s\n" "$(date +%H:%M:%S)" "$tvdb_id" "$plex_title" >> "$MATCH_LOG"
		else
			printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$tvdb_id" "$anilist_id" "$plex_title" "$asset_name" "$last_season" "$total_seasons" >> "$SCRIPT_FOLDER/config/ID/animes.tsv"
		fi
	fi
done < "$SCRIPT_FOLDER/config/tmp/plex_animes_export.tsv"
printf "%s\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
printf "%s - Done\n\n" "$(date +%H:%M:%S)" | tee -a "$LOG"

# Create an ongoing list at $SCRIPT_FOLDER/config/data/ongoing.csv
printf "%s - Creating Anilist airing list\n" "$(date +%H:%M:%S)"
:> "$SCRIPT_FOLDER/config/data/ongoing.tsv"
:> "$SCRIPT_FOLDER/config/tmp/ongoing-tmp.tsv"
ongoingpage=1
while [ $ongoingpage -lt 9 ];													# get the airing list from jikan API max 9 pages (225 animes)
do
	printf "%s\t - Downloading anilist airing list page : %s\n" "$(date +%H:%M:%S)" "$ongoingpage" | tee -a "$LOG"
	wait_time=0
	while [ $wait_time -lt 5 ];
	do
		if [[ $wait_time == 4 ]]
		then
			printf "%s - Error can't download anilist data stopping script\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			exit 1
		fi
		curl -s 'https://graphql.anilist.co/' \
		-X POST \
		-H 'content-type: application/json' \
		--data '{ "query": "{ Page(page: '"$ongoingpage"', perPage: 50) { pageInfo { hasNextPage } media(type: ANIME, status_in: RELEASING, sort: POPULARITY_DESC) { id } } }" }' > "$SCRIPT_FOLDER/config/tmp/ongoing-anilist.json" -D "$SCRIPT_FOLDER/config/tmp/anilist-limit-rate.txt"
		rate_limit=0
		rate_limit=$(grep -oP '(?<=x-ratelimit-remaining: )[0-9]+' "$SCRIPT_FOLDER/config/tmp/anilist-limit-rate.txt")
		((wait_time++))
		if [[ -z $rate_limit ]]
		then
			printf "%s\t - Cloudflare limit rate reached watiting 60s\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			sleep 61
		elif [[ $rate_limit -ge 3 ]]
		then
			sleep 1
			printf "%s\t - done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			break
		elif [[ $rate_limit -lt 3 ]]
		then
			printf "%s\t - Anilist API limit reached watiting 30s" "$(date +%H:%M:%S)" | tee -a "$LOG"
			sleep 30
			break
		fi
		((wait_time++))
	done
	jq '.data.Page.media[].id' -r "$SCRIPT_FOLDER/config/tmp/ongoing-anilist.json" >> "$SCRIPT_FOLDER/config/tmp/ongoing-tmp.tsv"		# store the mal ID of the ongoing show
	if grep -q -w ":false}" "$SCRIPT_FOLDER/config/tmp/ongoing-anilist.json"														# stop if page is empty
	then
		break
	fi
	((ongoingpage++))
done
	printf "%s\t - Sorting anilist airing list \n" "$(date +%H:%M:%S)" | tee -a "$LOG"
sort -n "$SCRIPT_FOLDER/config/tmp/ongoing-tmp.tsv" | uniq > "$SCRIPT_FOLDER/config/tmp/ongoing.tsv"
while read -r anilist_id
do
	if awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/config/ID/animes.tsv" | grep -q -w "$anilist_id"
	then
		line=$(awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/config/ID/animes.tsv" | grep -w -n "$anilist_id" | cut -d : -f 1)
		tvdb_id=$(sed -n "${line}p" "$SCRIPT_FOLDER/config/ID/animes.tsv" | awk -F"\t" '{print $1}')
		printf "%s\n" "$tvdb_id" >> "$SCRIPT_FOLDER/config/data/ongoing.tsv"
	else
		tvdb_id=$(get-tvdb-id)																	# convert the mal id to tvdb id (to get the main anime)
		if [[ "$tvdb_id" == 'null' ]] || [[ "${#tvdb_id}" == '0' ]]										# Ignore anime with no mal to tvdb id conversion
		then
			printf "%s\t\t - Ongoing list missing TVDB ID for Anilist : %s\n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
			continue
		else
			printf "%s\n" "$tvdb_id" >> "$SCRIPT_FOLDER/config/data/ongoing.tsv"
		fi
	fi
done < "$SCRIPT_FOLDER/config/tmp/ongoing.tsv"
printf "%s\t - Done\n" "$(date +%H:%M:%S)"
printf "%s - Done\n\n" "$(date +%H:%M:%S)"

# write PMM metadata file from ID/animes.tsv and jikan API
printf "%s - Start writing the metadata file \n" "$(date +%H:%M:%S)" | tee -a "$LOG"
printf "metadata:\n" > "$METADATA"
tvdb_id=""
anilist_id=""
mal_id=""
while IFS=$'\t' read -r tvdb_id anilist_id plex_title asset_name seasons_list override_seasons_ignore
do
	printf "%s\t - Writing metadata for %s / tvdb : %s / Anilist : %s \n" "$(date +%H:%M:%S)" "$plex_title" "$tvdb_id" "$anilist_id" | tee -a "$LOG"
	write-metadata
	printf "%s\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
done < "$SCRIPT_FOLDER/config/ID/animes.tsv"
printf "%s - Run finished\n\n\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
exit 0