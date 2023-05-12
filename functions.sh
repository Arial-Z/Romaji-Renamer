#!/bin/bash

#General variables
LOG=$LOG_FOLDER/${media_type}_$(date +%Y.%m.%d).log
MATCH_LOG=$LOG_FOLDER/${media_type}-missing-id.log

# functions
function create-override () {
	if [ ! -f "$SCRIPT_FOLDER/$OVERRIDE" ]
	then
		cp "$SCRIPT_FOLDER/override-ID-${media_type}.example.tsv" "$SCRIPT_FOLDER/$OVERRIDE"
	fi
}
function download-anime-id-mapping () {
	wait_time=0
	while [ $wait_time -lt 4 ];
	do
		if [[ $media_type == "animes" ]]
		then
			wget -O "$SCRIPT_FOLDER/tmp/list-animes-id.json" "https://raw.githubusercontent.com/Arial-Z/Animes-ID/main/list-animes-id.json"
			size=$(du -b "$SCRIPT_FOLDER/tmp/list-animes-id.json" | awk '{ print $1 }')
		else
			wget -O "$SCRIPT_FOLDER/tmp/list-movies-id.json" "https://raw.githubusercontent.com/Arial-Z/Animes-ID/main/list-movies-id.json"
			size=$(du -b "$SCRIPT_FOLDER/tmp/list-movies-id.json" | awk '{ print $1 }')
		fi
			((wait_time++))
		if [[ $size -gt 1000 ]]
		then
			break
		fi
		if [[ $wait_time == 4 ]]
		then
			printf "%s - error can't download anime ID mapping file, exiting\n" "$(date +%Y.%m.%d" - "%H:%M:%S)" >> "$LOG"
			printf "error can't download anime ID mapping file, exiting\n"
			exit 1
		fi
		sleep 30
	done
}
function get-anilist-id () {
	if [[ $media_type == "animes" ]]
	then
		jq --arg tvdb_id "$tvdb_id" '.[] | select( .tvdb_id == $tvdb_id ) | select( .tvdb_season == "1"  or .tvdb_season == "-1" ) | select( .tvdb_epoffset == "0" ) | .anilist_id' -r "$SCRIPT_FOLDER/tmp/list-animes-id.json"
	else
		jq --arg imdb_id "$imdb_id" '.[] | select( .imdb_id == $imdb_id ) | .anilist_id' -r "$SCRIPT_FOLDER/tmp/list-movies-id.json"
	fi
}
function get-mal-id () {
	jq '.data.Media.idMal' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json"
	if [[ "$mal_id" == 'null' ]] || [[ "${#mal_id}" == '0' ]]				# Ignore anime with no anilist id
	then
		echo "invalid MAL ID for Anilist ID : $anilist_id / $plex_title" >> "$MATCH_LOG"
	fi
}
function get-tvdb-id () {
	jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | .tvdb_id' -r "$SCRIPT_FOLDER/tmp/list-animes-id.json"
}
function get-anilist-infos () {
	if [ ! -f "$SCRIPT_FOLDER/data/anilist-$anilist_id.json" ]
	then
		curl 'https://graphql.anilist.co/' \
		-X POST \
		-H 'content-type: application/json' \
		--data '{ "query": "{ Media(type: ANIME, id: '"$anilist_id"') { title { romaji, english  }, averageScore, genres, tags { name, rank },studios { edges { node { name, isAnimationStudio } } }, coverImage { extraLarge }, idMal} }" }' > "$SCRIPT_FOLDER/data/anilist-$anilist_id.json" -D "$SCRIPT_FOLDER/tmp/anilist-limit-rate.txt"
		rate_limit=0
		rate_limit=$(grep -oP '(?<=x-ratelimit-remaining: )[0-9]+' "$SCRIPT_FOLDER/tmp/anilist-limit-rate.txt")
		if [[ rate_limit -lt 3 ]]
		then
			echo "Anilist API limit reached watiting"
			sleep 30
		else
			sleep 0.7
		fi
	fi
}
function get-mal-infos () {
	if [ ! -f "$SCRIPT_FOLDER/data/MAL-$mal_id.json" ]
	then
		curl -s -o "$SCRIPT_FOLDER/data/MAL-$mal_id.json" -w "%{http_code}" "https://api.jikan.moe/v4/anime/$mal_id" > "$SCRIPT_FOLDER/tmp/jikan-limit-rate.txt"
		if  grep -w "429" "$SCRIPT_FOLDER/tmp/jikan-limit-rate.txt"
		then
			sleep 10
			curl -s -o "$SCRIPT_FOLDER/data/MAL-$mal_id.json" -w "%{http_code}" "https://api.jikan.moe/v4/anime/$mal_id" > "$SCRIPT_FOLDER/tmp/jikan-limit-rate.txt"
		fi
		sleep 1.1
	fi
}
function get-romaji-title () {
	romaji_title="null"
	if awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/$OVERRIDE" | grep -w "$anilist_id"
	then
		line=$(awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/$OVERRIDE" | grep -w -n "$anilist_id" | cut -d : -f 1)
		title_tmp=$(sed -n "${line}p" "$SCRIPT_FOLDER/$OVERRIDE" | awk -F"\t" '{print $3}')
		if [[ -z "$title_tmp" ]]
		then
			romaji_title=$(jq '.data.Media.title.romaji' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json")
		else
			romaji_title=$title_tmp
		fi
	else
		romaji_title=$(jq '.data.Media.title.romaji' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json")
	fi
}
function get-english-title () {
	title="null"
	if awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/$OVERRIDE" | grep -q -w "$anilist_id"
	then
		line=$(awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/$OVERRIDE" | grep -w -n "$anilist_id" | cut -d : -f 1)
		title=$(sed -n "${line}p" "$SCRIPT_FOLDER/$OVERRIDE" | awk -F"\t" '{print $3}')
		if [[ -z "$title" ]]
		then
			jq '.data.Media.title.english' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json"
		else
			echo "$title"
		fi
	else
		jq '.data.Media.title.english' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json"
	fi
}
function get-score () {
	anime_score=0
	anime_score=$(jq '.data.Media.averageScore' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json" | awk '{print $1 / 10 }')
	if [[ "$anime_score" == "null" ]] || [[ "$anime_score" == '' ]]
	then
		rm "$SCRIPT_FOLDER/data/anilist-$anilist_id.json"
		get-anilist-infos
		anime_score=$(jq '.data.Media.averageScore' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json" | awk '{print $1 / 10 }')
		if [[ "$anime_score" == "null" ]]
		then
			echo 0
		fi
	else
		echo "$anime_score"
	fi
}
function get-mal-score () {
	get-mal-id
	get-mal-infos
	mal_score=0
	mal_score=$(jq '.data.score' -r "$SCRIPT_FOLDER/data/MAL-$mal_id.json")
	if [[ "$mal_score" == "null" ]]
	then
		rm "$SCRIPT_FOLDER/data/anilist-$anilist_id.json"
		get-mal-infos
		mal_score=$(jq '.data.score' -r "$SCRIPT_FOLDER/data/MAL-$mal_id.json")
		if [[ "$mal_score" == "null" ]]
		then
			echo 0
		fi
	else
		echo "$mal_score"
	fi
}
function get-tags () {
	(jq '.data.Media.genres | .[]' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json" && jq '.data.Media.tags | .[] | select( .rank >= 70 ) | .name' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json") | awk '{print $0}' | paste -s -d, -
	}
function get-studios() {
	if awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/$OVERRIDE" | grep -w "$anilist_id"
	then
		line=$(awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/$OVERRIDE" | grep -w -n "$anilist_id" | cut -d : -f 1)
		studio=$(sed -n "${line}p" "$SCRIPT_FOLDER/$OVERRIDE" | awk -F"\t" '{print $4}')
		if [[ -z "$studio" ]]
		then
			studio=$(jq '.data.Media.studios.edges[].node | select( .isAnimationStudio == true ) | .name' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json" | head -n 1)
		fi
	else
	studio=$(jq '.data.Media.studios.edges[].node | select( .isAnimationStudio == true ) | .name' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json" | head -n 1)
	fi
}
function get-poster () {
	if [[ $POSTER_DOWNLOAD == "Yes" ]]
	then
		if [ ! -f "$ASSET_FOLDER/$asset_name/poster.jpg" ]
		then
			if [ ! -d "$ASSET_FOLDER/$asset_name" ]
			then
				mkdir "$ASSET_FOLDER/$asset_name"
			fi
			if [[ $POSTER_SOURCE == "MAL" ]]
			then
				get-mal-id
				get-mal-infos
				poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/data/MAL-$mal_id.json")
				wget --no-use-server-timestamps -O "$ASSET_FOLDER/$asset_name/poster.jpg" "$poster_url"
				sleep 1.5
			else
				poster_url=$(jq '.data.Media.coverImage.extraLarge' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json")
				wget --no-use-server-timestamps -O "$ASSET_FOLDER/$asset_name/poster.jpg" "$poster_url"
				sleep 0.5
			fi
		else
			postersize=$(du -b "$ASSET_FOLDER/$asset_name/poster.jpg" | awk '{ print $1 }')
			if [[ $postersize -lt 10000 ]]
			then
				rm "$ASSET_FOLDER/$asset_name/poster.jpg"
				if [ ! -d "$ASSET_FOLDER/$asset_name" ]
				then
					mkdir "$ASSET_FOLDER/$asset_name"
				fi
				if [[ $POSTER_SOURCE == "MAL" ]]
				then
					get-mal-id
					get-mal-infos
					poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/data/MAL-$mal_id.json")
					wget --no-use-server-timestamps -O "$ASSET_FOLDER/$asset_name/poster.jpg" "$poster_url"
					sleep 1.5
				else
					poster_url=$(jq '.data.Media.coverImage.extraLarge' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json")
					wget --no-use-server-timestamps -O "$ASSET_FOLDER/$asset_name/poster.jpg" "$poster_url"
					sleep 0.5
				fi
			fi
		fi
	fi
}
function get-season-poster () {
	if [[ $POSTER_DOWNLOAD == "Yes" ]]
	then
		if [[ $season_number -lt 10 ]]
		then
			assets_filepath="$ASSET_FOLDER/$asset_name/Season0$season_number.jpg"
		else
			assets_filepath="$ASSET_FOLDER/$asset_name/Season$season_number.jpg"
		fi
		if [ ! -f "$assets_filepath" ]
		then
			if [ ! -d "$ASSET_FOLDER/$asset_name" ]
			then
				mkdir "$ASSET_FOLDER/$asset_name"
			fi
			if [[ $POSTER_SOURCE == "MAL" ]]
			then
				get-mal-id
				get-mal-infos
				poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/data/MAL-$mal_id.json")
				wget --no-use-server-timestamps -O "$assets_filepath" "$poster_url"
				sleep 1.5
			else
				poster_url=$(jq '.data.Media.coverImage.extraLarge' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json")
				wget --no-use-server-timestamps -O "$assets_filepath" "$poster_url"
				sleep 0.5
			fi
		else
			postersize=$(du -b "$assets_filepath" | awk '{ print $1 }')
			if [[ $postersize -lt 10000 ]]
			then
				rm "$assets_filepath"
				if [ ! -d "$ASSET_FOLDER/$asset_name" ]
				then
					mkdir "$ASSET_FOLDER/$asset_name"
				fi
				if [[ $POSTER_SOURCE == "MAL" ]]
				then
					get-mal-id
					get-mal-infos
					poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/data/MAL-$mal_id.json")
					wget --no-use-server-timestamps -O "$assets_filepath" "$poster_url"
					sleep 1.5
				else
					poster_url=$(jq '.data.Media.coverImage.extraLarge' -r "$SCRIPT_FOLDER/data/anilist-$anilist_id.json")
					wget --no-use-server-timestamps -O "$assets_filepath" "$poster_url"
					sleep 0.5
				fi
			fi
		fi
	fi
}
function get-season-infos () {
	anilist_backup_id=$anilist_id
	season_check=$(jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | .tvdb_season' -r "$SCRIPT_FOLDER/tmp/list-animes-id.json")
	if [[ $season_check != -1 ]] && [[ $total_seasons -ge 2 ]]
	then
		printf "    seasons:\n" >> "$METADATA"
		if [[ $last_season -eq 1 ]] && [[ $total_seasons -eq 2 ]]
		then
			printf "      0:\n        label.remove: score\n      1:\n        label.remove: score\n" >> "$METADATA"
			anilist_id=$anilist_backup_id
			if [[ $RATING_SOURCE == "ANILIST" ]]
			then
				score=$(get-score)
			else
				score=$(get-mal-score)
			fi
			score=$(printf '%.*f\n' 1 "$score")
		else
			if [[ $last_season -ne $total_seasons ]]
			then
				printf "      0:\n        label.remove: score\n" >> "$METADATA"
			fi
			season_number=1
			total_score=0
			while [ $season_number -le "$last_season" ];
			do
				anilist_id=$(jq --arg tvdb_id "$tvdb_id" --arg season_number "$season_number" '.[] | select( .tvdb_id == $tvdb_id ) | select( .tvdb_season == $season_number ) | select( .tvdb_epoffset == "0" ) | .anilist_id' -r "$SCRIPT_FOLDER/tmp/list-animes-id.json")
				if [[ -n "$anilist_id" ]]
				then
					get-anilist-infos
					if [[ $MAIN_TITLE_ENG == "Yes" ]]
					then
						title=$(get-english-title)
						if [ "$title" == "null" ]
						then
							title=$(get-romaji-title)
						fi
					else
						title=$(get-romaji-title)
					fi
					if [[ $RATING_SOURCE == "ANILIST" ]]
					then
						score_season=$(get-score)
					else
						score_season=$(get-mal-score)
					fi
					score_season=$(printf '%.*f\n' 1 "$score_season")
					printf "      %s:\n        title: |-\n          %s\n        user_rating: %s\n        label: score\n" "$season_number" "$title" "$score_season" >> "$METADATA"
					total_score=$(echo | awk -v v1="$score_season" -v v2="$total_score" '{print v1 + v2 }')
					get-season-poster
				fi
				((season_number++))
			done
			score=$(echo | awk -v v1="$total_score" -v v2="$last_season" '{print v1 / v2 }')
			score=$(printf '%.*f\n' 1 "$score")
		fi
	else
		anilist_id=$anilist_backup_id
		if [[ $RATING_SOURCE == "ANILIST" ]]
		then
			score=$(get-score)
		else
			score=$(get-mal-score)
		fi
		score=$(printf '%.*f\n' 1 "$score")
	fi
	anilist_id=$anilist_backup_id
}
function write-metadata () {
	get-anilist-infos
		if [[ $media_type == "animes" ]]
	then
		printf "  %s:\n" "$tvdb_id" >> "$METADATA"
	else
		printf "  %s:\n" "$imdb_id" >> "$METADATA"
	fi
	get-romaji-title
	get-english-title
		if [ "$english_title" == "null" ]
	then
		english_title=$romaji_title
	fi
	if [[ $MAIN_TITLE_ENG == "Yes" ]]
	then
		printf "    title: |-\n      %s\n    sort_title: |-\n      %s\n    original_title: |-\n      %s\n" "$english_title" "$english_title" "$romaji_title" >> "$METADATA"
	else
		printf "    title: |-\n      %s\n" "$romaji_title" >> "$METADATA"
		if [[ $SORT_TITLE_ENG == "Yes" ]]
		then
			printf "    sort_title: |-\n      %s\n" "$english_title" >> "$METADATA"
		else
			printf "    sort_title: |-\n      %s\n" "$romaji_title" >> "$METADATA"
		fi
		printf "    original_title: |-\n      %s\n" "$english_title" >> "$METADATA"
	fi
	printf "$(date +%Y.%m.%d" - "%H:%M:%S) - %s:\n" "$romaji_title" >> "$LOG"
	anime_tags=$(get-tags)
	printf "    genre.sync: Anime,%s\n" "$anime_tags"  >> "$METADATA"
	printf "%s\t\ttags : %s\n" "$(date +%Y.%m.%d" - "%H:%M:%S)" "$anime_tags" >> "$LOG"
	if [[ $media_type == "animes" ]]
	then
		if awk -F"\t" '{print "\""$1"\":"}' "$SCRIPT_FOLDER/data/ongoing.tsv" | grep -w "$tvdb_id"
		then
			printf "    label: Ongoing\n" >> "$METADATA"
			printf "%s\t\tLabel add Ongoing\n" "$(date +%Y.%m.%d" - "%H:%M:%S)" >> "$LOG"
		else
			printf "    label.remove: Ongoing\n" >> "$METADATA"
			printf "%s\t\tLabel remove Ongoing\n" "$(date +%Y.%m.%d" - "%H:%M:%S)" >> "$LOG"
		fi
	fi
	get-studios
	printf "    studio: %s\n" "$studio"  >> "$METADATA"
	printf "%s\t\tstudio : $studio\n" "$(date +%Y.%m.%d" - "%H:%M:%S)" >> "$LOG"
	get-poster
	if [[ $media_type == "animes" ]] && [[ $IGNORE_SEASONS != "Yes" ]]
	then
		if awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/$OVERRIDE" | grep -w  "$anilist_id"
		then
			line=$(awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/$OVERRIDE" | grep -w -n "$anilist_id" | cut -d : -f 1)
			if sed -n "${line}p" "$SCRIPT_FOLDER/$OVERRIDE" | awk -F"\t" '{print $5}' | grep -i -w "Yes"
			then
				if [[ $RATING_SOURCE == "ANILIST" ]]
				then
					score=$(get-score)
				else
					score=$(get-mal-score)
				fi
				score=$(printf '%.*f\n' 1 "$score")
				printf "    %s_rating: %s\n" "$WANTED_RATING" "$score" >> "$METADATA"
				printf "%s\t\tseasons ignored\n%s\t\tscore : %s\n" "$(date +%Y.%m.%d" - "%H:%M:%S)" "$(date +%Y.%m.%d" - "%H:%M:%S)" "$score" >> "$LOG"
			else
				get-season-infos
				printf "    %s_rating: %s\n" "$WANTED_RATING" "$score" >> "$METADATA"
				printf "%s\t\tscore : %s\n" "$(date +%Y.%m.%d" - "%H:%M:%S)" "$score" >> "$LOG"
			fi
		else
			get-season-infos
			printf "    %s_rating: %s\n" "$WANTED_RATING" "$score" >> "$METADATA"
			printf "%s\t\tscore : %s\n" "$(date +%Y.%m.%d" - "%H:%M:%S)" "$score" >> "$LOG"
		fi
	else
		if [[ $RATING_SOURCE == "ANILIST" ]]
		then
			score=$(get-score)
		else
			score=$(get-mal-score)
		fi
		score=$(printf '%.*f\n' 1 "$score")
		printf "    %s_rating: %s\n" "$WANTED_RATING" "$score" >> "$METADATA"
		printf "%s\t\tscore : %s\n" "$(date +%Y.%m.%d" - "%H:%M:%S)" "$score" >> "$LOG"
	fi
}