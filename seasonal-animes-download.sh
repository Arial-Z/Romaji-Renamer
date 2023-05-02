#!/bin/bash

#USER VARIABLES
limit_download=20
# Path to the created seasonal-animes-download file
DOWNLOAD_ANIMES_COLLECTION=/path/to/PMM/config/seasonal-animes-download.yml


SCRIPT_FOLDER=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
echo "$SCRIPT_FOLDER"
source $SCRIPT_FOLDER/functions.sh
media_type=animes





download-anime-id-mapping
current_season=$(wget -qO- 'https://anilist.co/search/anime/this-season' | gawk -v IGNORECASE=1 -v RS='</title' 'RT{gsub(/.*<title[^>]*>/,"");print;exit}' | awk '{print toupper($1);}')
echo "Current season : $current_season"
curl 'https://graphql.anilist.co/' \
-X POST \
-H 'content-type: application/json' \
--data '{ "query": "{ Page(page: 1, perPage: 50) { pageInfo { hasNextPage } media(type: ANIME, season: '$current_season', format: TV, status_in: RELEASING, sort: POPULARITY_DESC) { idMal } } }" }' | jq '.data.Page.media[] | select( .idMal != null ) | .idMal' > $SCRIPT_FOLDER/tmp/seasonal-anilist.tsv

while read -r mal_id
do
	tvdb_id=a
	tvdb_season=-a
	tvdb_epoffset=a
	get-tvdb-id
	if [[ "$tvdb_id" == 'null' ]] || [[ "${#tvdb_id}" == '0' ]]
	then
		echo "Seasonal invalid TVDB ID for MAL : $mal_id"
		continue
	else
		tvdb_season=$(jq --arg mal_id "$mal_id" '.[] | select( .mal_id == $mal_id ) | .tvdb_season' -r list-animes-id.json)
		tvdb_epoffset=$(jq --arg mal_id "$mal_id" '.[] | select( .mal_id == $mal_id ) | .tvdb_epoffset' -r list-animes-id.json)
		if [[ "$tvdb_season" -eq 1 ]] && [[ "$tvdb_epoffset" -eq 0 ]]
		then
			printf "$tvdb_id\n" >> $SCRIPT_FOLDER/data/seasonal.tsv
		fi
	fi
done < $SCRIPT_FOLDER/tmp/seasonal-anilist.tsv

tvdb_list=$(head -"$limit_download" $SCRIPT_FOLDER/data/seasonal.tsv | awk '{printf("%s,",$0)}'  | sed 's/,\s*$//')
echo $tvdb_list

echo "collections:" > $DOWNLOAD_ANIMES_COLLECTION
printf "  seasonal animes download:\n" >> $DOWNLOAD_ANIMES_COLLECTION
printf "    tvdb_show: $tvdb_list\n" >> $DOWNLOAD_ANIMES_COLLECTION
printf "    sync_mode: sync\n" >> $DOWNLOAD_ANIMES_COLLECTION
printf "    sonarr_add_missing: true\n" >> $DOWNLOAD_ANIMES_COLLECTION
printf "    build_collection: false\n" >> $DOWNLOAD_ANIMES_COLLECTION