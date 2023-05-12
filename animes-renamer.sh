#!/bin/bash

SCRIPT_FOLDER=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
echo "$SCRIPT_FOLDER"
media_type=animes
source $SCRIPT_FOLDER/.env
source $SCRIPT_FOLDER/functions.sh
METADATA=$METADATA_ANIMES
OVERRIDE=override-ID-$media_type.tsv

# check if files and folder exist
if [ ! -d $SCRIPT_FOLDER/data ]										#check if exist and create folder for json data
then
	mkdir $SCRIPT_FOLDER/data
else
	find $SCRIPT_FOLDER/data/* -mtime +$DATA_CACHE_TIME -exec rm {} \;					#delete json data if older than 2 days
fi
if [ ! -d $SCRIPT_FOLDER/tmp ]										#check if exist and create folder for json data
then
	mkdir $SCRIPT_FOLDER/tmp
fi
if [ ! -d $SCRIPT_FOLDER/ID ]											#check if exist and create folder and file for ID
then
	mkdir $SCRIPT_FOLDER/ID
	:> $SCRIPT_FOLDER/ID/animes.tsv
else
	:> $SCRIPT_FOLDER/ID/animes.tsv
fi
if [ ! -d $LOG_FOLDER ]
then
	mkdir $LOG_FOLDER
fi
:> $MATCH_LOG
create-override

# Download anime mapping json data
download-anime-id-mapping

# export animes list from plex
python3 $SCRIPT_FOLDER/plex_animes_export.py

# create ID/animes.tsv from the clean list ( tvdb_id	mal_id	anime_title	plex_title )
while IFS=$'\t' read -r tvdb_id anilist_id anime_title studio ignore_seasons					# First add the override animes to the ID file
do
	if ! awk -F"\t" '{print $1}' $SCRIPT_FOLDER/ID/animes.tsv | grep -w $tvdb_id
	then
		if awk -F"\t" '{print $1}' $SCRIPT_FOLDER/tmp/plex_animes_export.tsv | grep -w $tvdb_id
		then
			line=$(awk -F"\t" '{print $1}' $SCRIPT_FOLDER/tmp/plex_animes_export.tsv | grep -w -n $tvdb_id | cut -d : -f 1)
			plex_title=$(sed -n "${line}p" $SCRIPT_FOLDER/tmp/plex_animes_export.tsv | awk -F"\t" '{print $2}')
			asset_name=$(sed -n "${line}p" $SCRIPT_FOLDER/tmp/plex_animes_export.tsv | awk -F"\t" '{print $3}')
			last_season=$(sed -n "${line}p" $SCRIPT_FOLDER/tmp/plex_animes_export.tsv | awk -F"\t" '{print $4}')
			total_seasons=$(sed -n "${line}p" $SCRIPT_FOLDER/tmp/plex_animes_export.tsv | awk -F"\t" '{print $5}')
			if [[ -z "$anime_title" ]]
			then
				get-anilist-infos
				anime_title=$(get-romaji-title)
			fi
			printf "$tvdb_id\t$anilist_id\t$anime_title\t$plex_title\t$asset_name\t$last_season\t$total_seasons\n" >> $SCRIPT_FOLDER/ID/animes.tsv
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - override found for : $anime_title / $plex_title" >> $LOG
		fi
	fi
done < $SCRIPT_FOLDER/override-ID-animes.tsv

while IFS=$'\t' read -r tvdb_id plex_title asset_name last_season total_seasons 		# then get the other ID from the ID mapping and download json data
do
	if ! awk -F"\t" '{print $1}' $SCRIPT_FOLDER/ID/animes.tsv | grep -w $tvdb_id
	then
		anilist_id=$(get-anilist-id)
		if [[ "$anilist_id" == 'null' ]] || [[ "${#anilist_id}" == '0' ]]				# Ignore anime with no anilist id
		then
			echo "invalid Anilist ID for tvdb : $tvdb_id / $plex_title" >> $MATCH_LOG
		else
			get-anilist-infos
			anime_title=$(get-romaji-title)
			printf "$tvdb_id\t$anilist_id\t$anime_title\t$plex_title\t$asset_name\t$last_season\t$total_seasons\n" >> $SCRIPT_FOLDER/ID/animes.tsv
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $anime_title / $plex_title added to ID/animes.tsv" >> $LOG
		fi
	fi
done < $SCRIPT_FOLDER/tmp/plex_animes_export.tsv

# Create an ongoing list at $SCRIPT_FOLDER/data/ongoing.csv
:> $SCRIPT_FOLDER/data/ongoing.tsv
:> $SCRIPT_FOLDER/tmp/ongoing-tmp.tsv
ongoingpage=1
while [ $ongoingpage -lt 9 ];													# get the airing list from jikan API max 9 pages (225 animes)
do
	curl 'https://graphql.anilist.co/' \
	-X POST \
	-H 'content-type: application/json' \
	--data '{ "query": "{ Page(page: '"$ongoingpage"', perPage: 50) { pageInfo { hasNextPage } media(type: ANIME, status_in: RELEASING, sort: POPULARITY_DESC) { id } } }" }' > $SCRIPT_FOLDER/tmp/ongoing-anilist.json -D $SCRIPT_FOLDER/tmp/anilist-limit-rate.txt
	rate_limit=0
	rate_limit=$(grep -oP '(?<=x-ratelimit-remaining: )[0-9]+' $SCRIPT_FOLDER/tmp/anilist-limit-rate.txt)
	if [[ rate_limit -lt 3 ]]
	then
		echo "Anilist API limit reached watiting"
		sleep 30
	else
		sleep 0.7
	fi
	jq '.data.Page.media[].id' -r $SCRIPT_FOLDER/tmp/ongoing-anilist.json >> $SCRIPT_FOLDER/tmp/ongoing-tmp.tsv	# store the mal ID of the ongoing show
	if grep -w ":false}" $SCRIPT_FOLDER/tmp/ongoing-anilist.json								# stop if page is empty
	then
		break
	fi
	((ongoingpage++))
done
sort -n $SCRIPT_FOLDER/tmp/ongoing-tmp.tsv | uniq > $SCRIPT_FOLDER/tmp/ongoing.tsv
while read -r anilist_id
do
	if awk -F"\t" '{print $2}' $SCRIPT_FOLDER/ID/animes.tsv | grep -w  $anilist_id
	then
		line=$(awk -F"\t" '{print $2}' $SCRIPT_FOLDER/ID/animes.tsv | grep -w -n $anilist_id | cut -d : -f 1)
		tvdb_id=$(sed -n "${line}p" $SCRIPT_FOLDER/ID/animes.tsv | awk -F"\t" '{print $1}')
		printf "$tvdb_id\n" >> $SCRIPT_FOLDER/data/ongoing.tsv
	else
		tvdb_id=$(get-tvdb-id)																	# convert the mal id to tvdb id (to get the main anime)
		if [[ "$tvdb_id" == 'null' ]] || [[ "${#tvdb_id}" == '0' ]]										# Ignore anime with no mal to tvdb id conversion
		then
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - Ongoing invalid TVDB ID for Anilist : $anilist_id" >> $LOG
			continue
		else
			printf "$tvdb_id\n" >> $SCRIPT_FOLDER/data/ongoing.tsv
		fi
	fi
done < $SCRIPT_FOLDER/tmp/ongoing.tsv

# write PMM metadata file from ID/animes.tsv and jikan API
echo "metadata:" > $METADATA
while IFS=$'\t' read -r tvdb_id anilist_id anime_title plex_title asset_name last_season total_seasons
do
	write-metadata
done < $SCRIPT_FOLDER/ID/animes.tsv
exit 0