#!/bin/bash

#General variables
LOG=$LOG_FOLDER/${media_type}_$(date +%Y.%m.%d).log
MATCH_LOG=$LOG_FOLDER/${media_type}_missing-id.log

# functions
function create-override () {
	if [ ! -f $SCRIPT_FOLDER/$OVERRIDE ]
	then
		cp $SCRIPT_FOLDER/$OVERRIDE.exmaple $SCRIPT_FOLDER/$OVERRIDE
	fi
}
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
	if [ ! -f "$SCRIPT_FOLDER/data/$mal_id.json" ]
	then
		sleep 0.5
		curl "https://api.jikan.moe/v4/anime/$mal_id" > "$SCRIPT_FOLDER/data/$mal_id.json"
		sleep 1.5
	fi
}
function get-anilist-infos () {
	if [ ! -f "$SCRIPT_FOLDER/data/title-$mal_id.json" ]
	then
		sleep 0.5
		curl 'https://graphql.anilist.co/' \
		-X POST \
		-H 'content-type: application/json' \
		--data '{ "query": "{ Media(type: ANIME, id: '"$anilist_id"') { title { romaji } } }" }' > "$SCRIPT_FOLDER/data/title-$mal_id.json"
		sleep 1.5
	fi
}
function get-anilist-title () {
	jq '.data.Media.title.romaji' -r "$SCRIPT_FOLDER/data/title-$mal_id.json"
}
function get-mal-eng-title () {
	jq '.data.title_english' -r "$SCRIPT_FOLDER/data/$mal_id.json"
}
function get-mal-rating () {
	mal_score=0
	mal_score=$(jq '.data.score' -r "$SCRIPT_FOLDER/data/$mal_id.json")
	if [[ "$mal_score" == "null" ]]
	then
		rm "$SCRIPT_FOLDER/data/$mal_id.json"
		get-mal-infos
		mal_score=$(jq '.data.score' -r "$SCRIPT_FOLDER/data/$mal_id.json")
		if [[ "$mal_score" == "null" ]]
		then
			echo 0
		fi
	else
		echo $mal_score
	fi
}
function get-mal-poster () {
	if [[ $POSTER_DOWNLOAD == "Yes" ]]
	then
		if [ ! -f "$ASSET_FOLDER/$asset_name/poster.jpg" ]
		then
			sleep 0.5
			mal_poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/data/$mal_id.json")
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
				mal_poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/data/$mal_id.json")
				wget --no-use-server-timestamps -O "$ASSET_FOLDER/$asset_name/poster.jpg" "$mal_poster_url"
				sleep 1.5
			fi
		fi
	fi
}
function get-mal-tags () {
	(jq '.data.genres  | .[] | .name' -r "$SCRIPT_FOLDER/data/$mal_id.json" && jq '.data.demographics  | .[] | .name' -r "$SCRIPT_FOLDER/data/$mal_id.json" && jq '.data.themes  | .[] | .name' -r "$SCRIPT_FOLDER/data/$mal_id.json") | awk '{print $0}' | paste -s -d, -
	}
function get-mal-studios() {
	if awk -F"\t" '{print $2}' $SCRIPT_FOLDER/$OVERRIDE | grep -w  $mal_id
	then
		line=$(grep -w -n $mal_id $SCRIPT_FOLDER/$OVERRIDE | cut -d : -f 1)
		studio=$(sed -n "${line}p" $SCRIPT_FOLDER/$OVERRIDE | awk -F"\t" '{print $4}')
		if [[ -z "$studio" ]]
		then
			jq '.data.studios[0] | [.name]| @tsv' -r $SCRIPT_FOLDER/data/$mal_id.json
		else
			echo "$studio"
		fi
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
			printf "$(date +%Y.%m.%d" - "%H:%M:%S) - error can't download anime ID mapping file, exiting\n" >> $LOG
			printf "error can't download anime ID mapping file, exiting\n"
			exit 1
		fi
		sleep 30
	done
}
function get-mal-season-poster () {
	if [[ $POSTER_DOWNLOAD == "Yes" ]]
	then
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
				mal_poster_url=$(jq '.data.images.jpg.large_image_url' -r $SCRIPT_FOLDER/data/$mal_id.json)
				mkdir "$ASSET_FOLDER/$asset_name"
				wget --no-use-server-timestamps -O "$assets_filepath" "$mal_poster_url"
				sleep 1.5
			fi
		fi
	fi
}
function get-season-infos () {
	mal_backup_id=$mal_id
	season_check=$(jq --arg mal_id "$mal_id" '.[] | select( .mal_id == $mal_id ) | .tvdb_season' -r $SCRIPT_FOLDER/tmp/list-animes-id.json)
	if [[ $season_check != -1 ]] && [[ $total_seasons -ge 2 ]]
	then
		printf "    seasons:\n" >> $METADATA
		if [[ $last_season -eq 1 ]] && [[ $total_seasons -eq 2 ]]
		then
			printf "      0:\n        label.remove: score\n" >> $METADATA
			printf "      1:\n        label.remove: score\n" >> $METADATA
			mal_id=$mal_backup_id
			score=$(get-mal-rating)
			score=$(printf '%.*f\n' 1 $score)
		else
			if [[ $last_season -ne $total_seasons ]]
			then
				printf "      0:\n        label.remove: score\n" >> $METADATA
			fi
			season_number=1
			total_score=0
			while [ $season_number -le $last_season ];
			do
				mal_id=$(jq --arg tvdb_id "$tvdb_id" --arg season_number "$season_number" '.[] | select( .tvdb_id == $tvdb_id ) | select( .tvdb_season == $season_number ) | select( .tvdb_epoffset == "0" ) | .mal_id' -r $SCRIPT_FOLDER/tmp/list-animes-id.json)
				anilist_id=$(jq --arg tvdb_id "$tvdb_id" --arg season_number "$season_number" '.[] | select( .tvdb_id == $tvdb_id ) | select( .tvdb_season == $season_number ) | select( .tvdb_epoffset == "0" ) | .anilist_id' -r $SCRIPT_FOLDER/tmp/list-animes-id.json)
				if [[ -n "$mal_id" ]] && [[ -n "$anilist_id" ]]
				then
					get-mal-infos
					get-anilist-infos
					if [[ $MAIN_TITLE_ENG == "Yes" ]]
					then
						title=$(get-mal-eng-title)
						if [ "$title" == "null" ]
						then
							title=$(get-anilist-title)
						fi
					else
						title=$(get-anilist-title)
					fi
					score_season=$(get-mal-rating)
					score_season=$(printf '%.*f\n' 1 $score_season)
					printf "      $season_number:\n        title: |-\n          $title\n        user_rating: $score_season\n        label: score\n" >> $METADATA
					total_score=$(echo | awk -v v1=$score_season -v v2=$total_score '{print v1 + v2 }')
					get-mal-season-poster
				fi
				((season_number++))
			done
			score=$(echo | awk -v v1=$total_score -v v2=$last_season '{print v1 / v2 }')
			score=$(printf '%.*f\n' 1 $score)
		fi
	else
		mal_id=$mal_backup_id
		score=$(get-mal-rating)
		score=$(printf '%.*f\n' 1 $score)
	fi
	mal_id=$mal_backup_id
}
function write-metadata () {
	get-mal-infos
	if [[ $media_type == "animes" ]]
	then
		printf "  $tvdb_id:\n" >> $METADATA
	else
		printf "  $imdb_id:\n" >> $METADATA
	fi
	title_eng=$(get-mal-eng-title)
		if [ "$title_eng" == "null" ]
	then
		title_eng=$title_anime
	fi
	if [[ $MAIN_TITLE_ENG == "Yes" ]]
	then
		printf "    title: |-\n      $title_eng\n" >> $METADATA
		printf "    sort_title: |-\n      $title_eng\n" >> $METADATA
		printf "    original_title: |-\n      $title_anime\n" >> $METADATA
	else
		printf "    title: |-\n      $title_anime\n" >> $METADATA
		if [[ $SORT_TITLE_ENG == "Yes" ]]
		then
			printf "    sort_title: |-\n      $title_eng\n" >> $METADATA
		else
			printf "    sort_title: |-\n      $title_anime\n" >> $METADATA
		fi
		printf "    original_title: |-\n      $title_eng\n" >> $METADATA
	fi
	printf "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_anime:\n" >> $LOG
	mal_tags=$(get-mal-tags)
	printf "    genre.sync: Anime,${mal_tags}\n"  >> $METADATA
	printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\ttags : $mal_tags\n" >> $LOG
	if [[ $media_type == "animes" ]]
	then
		if awk -F"\t" '{print "\""$1"\":"}' $SCRIPT_FOLDER/data/ongoing.tsv | grep -w "$tvdb_id"
		then
			printf "    label: Ongoing\n" >> $METADATA
			printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tLabel add Ongoing\n" >> $LOG
		else
			printf "    label.remove: Ongoing\n" >> $METADATA
			printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tLabel remove Ongoing\n" >> $LOG
		fi
	fi
	studio=$(get-mal-studios)
	printf "    studio: ${studio}\n"  >> $METADATA
	printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tstudio : $mal_studios\n" >> $LOG
	get-mal-poster
	if [[ $media_type == "animes" ]] && [[ $IGNORE_SEASONS != "Yes" ]]
	then
		if awk -F"\t" '{print $2}' $SCRIPT_FOLDER/$OVERRIDE | grep -w  $mal_id
		then
			line=$(awk -F"\t" '{print $2}' $SCRIPT_FOLDER/$OVERRIDE | grep -w -n $mal_id | cut -d : -f 1)
			if sed -n "${line}p" $SCRIPT_FOLDER/$OVERRIDE | awk -F"\t" '{print $5}' | grep -i -w "Yes"
			then
				score=$(get-mal-rating)
				score=$(printf '%.*f\n' 1 $score)
				printf "    ${WANTED_RATING}_rating: $score\n" >> $METADATA
				printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tseasons ignored\n" >> $LOG
				printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tscore : $score\n" >> $LOG
			else
				get-season-infos
				printf "    ${WANTED_RATING}_rating: $score\n" >> $METADATA
				printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tscore : $score\n" >> $LOG
			fi
		else
			get-season-infos
			printf "    ${WANTED_RATING}_rating: $score\n" >> $METADATA
			printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tscore : $score\n" >> $LOG
		fi
	else
		score=$(get-mal-rating)
		score=$(printf '%.*f\n' 1 $score)
		printf "    ${WANTED_RATING}_rating: $score\n" >> $METADATA
		printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tscore : $score\n" >> $LOG
	fi
	printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tscore : $score\n" >> $LOG
}