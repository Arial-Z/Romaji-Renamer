#!/bin/bash

# SCRIPT VARIABLES
SCRIPT_FOLDER=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_FOLDER/.env"
source "$SCRIPT_FOLDER/functions.sh"
media_type=animes

#SCRIPT
:> "$SCRIPT_FOLDER/data/seasonal.tsv"
download-anime-id-mapping
current_season=$(wget -qO- 'https://anilist.co/search/anime/this-season' | gawk -v IGNORECASE=1 -v RS='</title' 'RT{gsub(/.*<title[^>]*>/,"");print;exit}' | awk '{print toupper($1);}')
printf "Current season : %s %s\n" "$current_season" "$(date +%Y)"
curl 'https://graphql.anilist.co/' \
-X POST \
-H 'content-type: application/json' \
--data '{ "query": "{ Page(page: 1, perPage: 100) { pageInfo { hasNextPage } media(type: ANIME, seasonYear: '"$(date +%Y)"' season: '"$current_season"', format: TV, sort: POPULARITY_DESC) { id } } }" }' | jq '.data.Page.media[] | .id' > "$SCRIPT_FOLDER/tmp/seasonal-anilist.tsv"

while read -r anilist_id
do
	tvdb_id=a
	tvdb_season=-a
	tvdb_epoffset=a
	tvdb_id=$(get-tvdb-id)
	if [[ "$tvdb_id" == 'null' ]] || [[ "${#tvdb_id}" == '0' ]]
	then
		printf "Seasonal invalid TVDB ID for Anilist : %s\n" "$anilist_id"
		continue
	else
		tvdb_season=$(jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | .tvdb_season' -r "$SCRIPT_FOLDER/tmp/list-animes-id.json")
		tvdb_epoffset=$(jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | .tvdb_epoffset' -r "$SCRIPT_FOLDER/tmp/list-animes-id.json")
		if [[ "$tvdb_season" -eq 1 ]] && [[ "$tvdb_epoffset" -eq 0 ]]
		then
			printf "%s\n" "$tvdb_id" >> "$SCRIPT_FOLDER/data/seasonal.tsv"
		fi
	fi
done < "$SCRIPT_FOLDER/tmp/seasonal-anilist.tsv"

tvdb_list=$(head -"$DOWNLOAD_LIMIT" "$SCRIPT_FOLDER/data/seasonal.tsv" | awk '{printf("%s,",$0)}'  | sed 's/,\s*$//')
printf "list of tvdb id to be added : %s\n" "$tvdb_list"
printf "collections:\n  seasonal animes download:\n    tvdb_show: %s\n    sync_mode: sync\n    sonarr_add_missing: true\n    build_collection: false\n" "$tvdb_list" > "$DOWNLOAD_ANIMES_COLLECTION"