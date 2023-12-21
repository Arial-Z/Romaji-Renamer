#!/bin/bash

# SCRIPT VARIABLES
export LC_ALL=C.UTF-8
SCRIPT_FOLDER=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
media_type=seasonal
source "$SCRIPT_FOLDER/config/.env"
source "$SCRIPT_FOLDER/functions.sh"

# check if files and folder exist
if [ ! -d "$SCRIPT_FOLDER/config/data" ]										#check if exist and create folder for json data
then
	mkdir "$SCRIPT_FOLDER/config/data"
fi
if [ ! -d "$SCRIPT_FOLDER/config/tmp" ]										#check if exist and create folder for json data
then
	mkdir "$SCRIPT_FOLDER/config/tmp"
fi
:> "$SCRIPT_FOLDER/config/data/seasonal.tsv"

#SCRIPT
printf "%s - Starting script\n\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
download-anime-id-mapping
printf "%s - checking current season\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
curl -s -L -A "Mozilla/5.0 (X11; Linux x86_64)" "https://livechart.me/" -o "$SCRIPT_FOLDER/config/tmp/this-season.html"
season=$(awk -v IGNORECASE=1 -v RS='</title' 'RT{gsub(/.*<title[^>]*>/,"");print;exit}' "$SCRIPT_FOLDER/config/tmp/this-season.html" | awk '{print $1}'| tr '[:lower:]' '[:upper:]')
year=$(awk -v IGNORECASE=1 -v RS='</title' 'RT{gsub(/.*<title[^>]*>/,"");print;exit}' "$SCRIPT_FOLDER/config/tmp/this-season.html" | awk '{print $2}')
printf "%s - Current season : %s %s\n\n" "$(date +%H:%M:%S)" "$season" "$year" | tee -a "$LOG"
printf "%s - Creating seasonal list\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
printf "%s\t - Downloading anilist season list\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
curl -s 'https://graphql.anilist.co/' \
-X POST \
-H 'content-type: application/json' \
--data '{ "query": "{ Page(page: 1, perPage: '"$DOWNLOAD_LIMIT"') { pageInfo { hasNextPage } media(type: ANIME, seasonYear: '"$year"' season: '"$season"', format: TV, sort: POPULARITY_DESC) { id } } }" }' | jq '.data.Page.media[] | .id' > "$SCRIPT_FOLDER/config/tmp/seasonal-anilist.tsv"
printf "%s\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
printf "%s\t - Sorting seasonal list\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
while read -r anilist_id
do
	tvdb_id=a
	tvdb_season=-a
	tvdb_epoffset=a
	tvdb_id=$(get-tvdb-id)
	if [[ "$tvdb_id" == 'null' ]] || [[ "${#tvdb_id}" == '0' ]]
	then
		printf "%s\t\t - Seasonal invalid TVDB ID for Anilist : %s\n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
		continue
	else
		tvdb_season=$(jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | .tvdb_season' -r "$SCRIPT_FOLDER/config/tmp/list-animes-id.json")
		tvdb_epoffset=$(jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | .tvdb_epoffset' -r "$SCRIPT_FOLDER/config/tmp/list-animes-id.json")
		if [[ "$tvdb_season" -eq 1 ]] && [[ "$tvdb_epoffset" -eq 0 ]]
		then
			printf "%s\n" "$tvdb_id" >> "$SCRIPT_FOLDER/config/data/seasonal.tsv"
			printf "%s\t\t - New seasonal anime adding to list : Anilist id : %s / tvdb id : %s\n" "$(date +%H:%M:%S)" "$anilist_id" "$tvdb_id" | tee -a "$LOG"
		else
			printf "%s\t\t - Sequel seasonal anime not adding to list : Anilist id : %s / tvdb id : %s\n" "$(date +%H:%M:%S)" "$anilist_id" "$tvdb_id" | tee -a "$LOG"
		fi
	fi
done < "$SCRIPT_FOLDER/config/tmp/seasonal-anilist.tsv"
printf "%s - Done\n\n" "$(date +%H:%M:%S)" | tee -a "$LOG"


tvdb_list=$(awk '{printf("%s,",$0)}' "$SCRIPT_FOLDER/config/data/seasonal.tsv" | sed 's/,\s*$//')
printf "%s - Wrinting seasonal collection\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
printf "%s - Seasonal list : tvdb id added : %s\n" "$(date +%H:%M:%S)" "$tvdb_list"| tee -a "$LOG"
printf "collections:\n  seasonal animes download:\n    tvdb_show: %s\n    sync_mode: append\n    sonarr_add_missing: true\n    build_collection: false\n" "$tvdb_list" > "$DOWNLOAD_ANIMES_COLLECTION"
printf "%s - Done\n\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
printf "%s - Run finished\n\n\n" "$(date +%H:%M:%S)" | tee -a "$LOG"