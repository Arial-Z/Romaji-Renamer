#!/bin/bash

#General variables
LOG=$LOG_FOLDER/${media_type}_$(date +%Y.%m.%d).log
MATCH_LOG=$LOG_FOLDER/missing-id.log

# functions
function get-mal-id-from-tvdb-id () {
	jq --arg tvdb_id "$tvdb_id" '.[] | select( .tvdb_id == $tvdb_id ) | select( .tvdb_season == "1"  or .tvdb_season == "-1" ) | select( .tvdb_epoffset == "0" ) | .mal_id' -r $SCRIPT_FOLDER/tmp/list-animes-id.json
}
function get-mal-id-from-imdb-id () {
	jq --arg imdb_id "$imdb_id" '.[] | select( .imdb_id == $imdb_id ) | .mal_id' -r $SCRIPT_FOLDER/tmp/list-movies-id.json
}
function get-anilist-id () {
	if [[ $media_type == "animes" ]]
	then
		jq --arg tvdb_id "$tvdb_id" '.[] | select( .tvdb_id == $tvdb_id ) | select( .tvdb_season == "1"  or .tvdb_season == "-1" ) | select( .tvdb_epoffset == "0" ) | .anilist_id' -r $SCRIPT_FOLDER/tmp/list-animes-id.json
	else
		jq --arg imdb_id "$imdb_id" '.[] | select( .imdb_id == $imdb_id ) | .anilist_id' -r $SCRIPT_FOLDER/tmp/list-movies-id.json
	fi
}
function get-tvdb-id () {
	jq --arg mal_id "$mal_id" '.[] | select( .mal_id == $mal_id ) | .tvdb_id' -r $SCRIPT_FOLDER/tmp/list-animes-id.json
}
function get-mal-infos () {
	if [ ! -f $SCRIPT_FOLDER/data/$mal_id.json ]
	then
		sleep 0.5
		curl "https://api.jikan.moe/v4/anime/$mal_id" > $SCRIPT_FOLDER/data/$mal_id.json
		sleep 1.5
	fi
}
function get-anilist-infos () {
	if [ ! -f $SCRIPT_FOLDER/data/title-$mal_id.json ]
	then
		sleep 0.5
		curl 'https://graphql.anilist.co/' \
		-X POST \
		-H 'content-type: application/json' \
		--data '{ "query": "{ Media(id: '"$anilist_id"') { title { romaji } } }" }' > $SCRIPT_FOLDER/data/title-$mal_id.json
		sleep 1.5
	fi
}
function get-anilist-title () {
	jq '.data.Media.title.romaji' -r $SCRIPT_FOLDER/data/title-$mal_id.json
}
function get-mal-eng-title () {
	jq '.data.title_english' -r $SCRIPT_FOLDER/data/$mal_id.json
}
function get-mal-rating () {
	jq '.data.score' -r $SCRIPT_FOLDER/data/$mal_id.json
}
function get-mal-poster () {
	if [ ! -f "$ASSET_FOLDER/$asset_name/poster.jpg" ]
	then
		sleep 0.5
		mal_poster_url=$(jq '.data.images.jpg.large_image_url' -r $SCRIPT_FOLDER/data/$mal_id.json)
		mkdir "$ASSET_FOLDER/$asset_name"
		wget --no-use-server-timestamps -O "$ASSET_FOLDER/$asset_name/poster.jpg" "$mal_poster_url"
		sleep 1.5
	else
		postersize=$(du -b "$ASSET_FOLDER/$asset_name/poster.jpg" | awk '{ print $1 }')
		if [[ $postersize -lt 10000 ]]
		then
			rm "$ASSET_FOLDER/$asset_name/poster.jpg"
			sleep 0.5
			mkdir "$ASSET_FOLDER/$asset_name"
			mal_poster_url=$(jq '.data.images.jpg.large_image_url' -r $SCRIPT_FOLDER/data/$mal_id.json)
			wget --no-use-server-timestamps -O "$ASSET_FOLDER/$asset_name/poster.jpg" "$mal_poster_url"
			sleep 1.5
		fi
	fi
}
function get-mal-season-poster () {
	if [[ $season_number -lt 10 ]]
	then
		assets_filepath=$(echo "$ASSET_FOLDER/$asset_name/Season0$season_number.jpg")
	else
		assets_filepath=$(echo "$ASSET_FOLDER/$asset_name/Season$season_number.jpg")
	fi
	if [ ! -f "$assets_filepath" ]
	then
		sleep 0.5
		mal_poster_url=$(jq '.data.images.jpg.large_image_url' -r $SCRIPT_FOLDER/data/$mal_id.json)
		mkdir "$ASSET_FOLDER/$asset_name"
			wget --no-use-server-timestamps -O "$assets_filepath" "$mal_poster_url"
		sleep 1.5
	else
		postersize=$(du -b "$assets_filepath" | awk '{ print $1 }')
		if [[ $postersize -lt 10000 ]]
		then
			rm "$assets_filepath"
			sleep 0.5
			mkdir "$ASSET_FOLDER/$asset_name"
			mal_poster_url=$(jq '.data.images.jpg.large_image_url' -r $SCRIPT_FOLDER/data/$mal_id.json)
			wget --no-use-server-timestamps -O "$file" "$mal_poster_url"
			sleep 1.5
		fi
	fi
}
function get-season-infos () {
	mal_backup_id=$mal_id
	if [[ $season_count -gt 1 ]]
	then
		season_check=$(jq --arg mal_id "$mal_id" '.[] | select( .mal_id == $mal_id ) | .tvdb_season' -r $SCRIPT_FOLDER/tmp/list-animes-id.json)
		if [[ $season_check != -1 ]]
		then
			printf "    seasons:\n" >> $METADATA
			printf "      0:\n" >> $METADATA
			printf "        user_rating: 0\n" >> $METADATA
			season_number=1
			total_score=0
			while [ $season_number -le $season_count ];
			do
				mal_id=$(jq --arg tvdb_id "$tvdb_id" --arg season_number "$season_number" '.[] | select( .tvdb_id == $tvdb_id ) | select( .tvdb_season == $season_number ) | select( .tvdb_epoffset == "0" ) | .mal_id' -r $SCRIPT_FOLDER/tmp/list-animes-id.json)
				Anilist_id=$(jq --arg tvdb_id "$tvdb_id" --arg season_number "$season_number" '.[] | select( .tvdb_id == $tvdb_id ) | select( .tvdb_season == $season_number ) | select( .tvdb_epoffset == "0" ) | .anilist_id' -r $SCRIPT_FOLDER/tmp/list-animes-id.json)
				if [[ -n "$mal_id" ]]
				then
					get-mal-infos
					get-anilist-infos
					title=$(get-anilist-title)
					score_mal=$(get-mal-rating)
					printf "      $season_number:\n" >> $METADATA
					printf "        title: \"$title\"" >> $METADATA
					printf "        user_rating: $score_mal\n" >> $METADATA
					total_score=`bc <<<"scale=2; $score_mal + $total_score"`
					get-mal-season-poster
				fi
				((season_number++))
			done
			average_score=`bc <<<"scale=2; $total_score/$season_count"`
		fi
	else
		printf "    seasons:\n" >> $METADATA
		printf "      0:\n" >> $METADATA
		printf "        user_rating: 0\n" >> $METADATA
		printf "      1:\n" >> $METADATA
		printf "        user_rating: 0\n" >> $METADATA
	fi
	mal_id=$mal_backup_id
}
function get-mal-tags () {
	(jq '.data.genres  | .[] | .name' -r $SCRIPT_FOLDER/data/$mal_id.json && jq '.data.demographics  | .[] | .name' -r $SCRIPT_FOLDER/data/$mal_id.json && jq '.data.themes  | .[] | .name' -r $SCRIPT_FOLDER/data/$mal_id.json) | awk '{print $0}' | paste -s -d, -
	}
	function get-mal-studios() {
	if awk -F"\t" '{print $2}' $SCRIPT_FOLDER/$OVERRIDE | grep -w  $mal_id
	then
		line=$(grep -w -n $mal_id $SCRIPT_FOLDER/$OVERRIDE | cut -d : -f 1)
		studio=$(sed -n "${line}p" $SCRIPT_FOLDER/$OVERRIDE | awk -F"\t" '{print $4}')
		if [[ -z "$studio" ]]
		then
			mal_studios=$(jq '.data.studios[0] | [.name]| @tsv' -r $SCRIPT_FOLDER/data/$mal_id.json)
		else
			mal_studios=$(echo "$studio")
		fi
	else
		mal_studios=$(jq '.data.studios[0] | [.name]| @tsv' -r $SCRIPT_FOLDER/data/$mal_id.json)
	fi
}
function download-anime-id-mapping () {
	wait_time=0
	while [ $wait_time -lt 4 ];
	do
		if [[ $media_type == "animes" ]]
		then
			wget -O $SCRIPT_FOLDER/tmp/list-animes-id.json "https://raw.githubusercontent.com/Arial-Z/Animes-ID/main/list-animes-id.json"
			size=$(du -b $SCRIPT_FOLDER/tmp/list-animes-id.json | awk '{ print $1 }')
		else
			wget -O $SCRIPT_FOLDER/tmp/list-movies-id.json "https://raw.githubusercontent.com/Arial-Z/Animes-ID/main/list-movies-id.json"
			size=$(du -b $SCRIPT_FOLDER/tmp/list-movies-id.json | awk '{ print $1 }')
		fi
			((wait_time++))
		if [[ $size -gt 1000 ]]
		then
			break
		fi
		if [[ $wait_time == 4 ]]
		then
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - error can't download anime ID mapping file, exiting" >> $LOG
			echo "error can't download anime ID mapping file, exiting"
			exit 1
		fi
		sleep 30
	done
}
function write-metadata () {
	get-mal-infos
	if [[ $media_type == "animes" ]]
	then
		echo "  $tvdb_id:" >> $METADATA
	else
		echo "  $imdb_id:" >> $METADATA
	fi
	echo "    title: \"$title_anime\"" >> $METADATA	
	echo "    sort_title: \"$title_anime\"" >> $METADATA
	title_eng=$(get-mal-eng-title)
	if [ "$title_eng" == "null" ]
	then
		echo "    original_title: \"$title_anime\"" >> $METADATA
	else 
		echo "    original_title: \"$title_eng\"" >> $METADATA
	fi
	printf "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_anime:\n" >> $LOG
	printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tscore : $score_mal\n" >> $LOG
	mal_tags=$(get-mal-tags)
	echo "    genre.sync: Anime,${mal_tags}"  >> $METADATA
	printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\ttags : $mal_tags\n" >> $LOG
	if [[ $media_type == "animes" ]]
	then
		if awk -F"\t" '{print "\""$1"\":"}' $SCRIPT_FOLDER/data/ongoing.tsv | grep -w "$mal_id"
		then
			echo "    label: Ongoing" >> $METADATA
			printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tLabel add Ongoing\n" >> $LOG
		else
			echo "    label.remove: Ongoing" >> $METADATA
			printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tLabel remove Ongoing\n" >> $LOG
		fi
	fi
	get-mal-studios
	echo "    studio: ${mal_studios}"  >> $METADATA
	printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tstudio : $mal_studios\n" >> $LOG
	get-mal-poster
	get-season-infos
	if [[ total_score != 0 ]]
	then
		echo "    user_rating: $average_score" >> $METADATA
	else
		score_mal=$(get-mal-rating)
		echo "    user_rating: $score_mal" >> $METADATA
	fi
}