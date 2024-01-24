#!/bin/bash

#General variables
LOG=$LOG_FOLDER/${media_type}_$(date +%Y.%m.%d).log
MATCH_LOG=$LOG_FOLDER/${media_type}-missing-id.log

# functions
function create-override () {
	if [ ! -f "$SCRIPT_FOLDER/config/$OVERRIDE" ]
	then
		cp "$SCRIPT_FOLDER/config/override-ID-${media_type}.example.tsv" "$SCRIPT_FOLDER/config/$OVERRIDE"
	fi
}
function download-anime-id-mapping () {
	wait_time=0
	while [ $wait_time -lt 4 ];
	do
		printf "%s - Downloading anime mapping\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
		if [[ $media_type == "animes" ]]
		then
			curl -s "https://raw.githubusercontent.com/Arial-Z/Animes-ID/main/list-animes-id.json" > "$SCRIPT_FOLDER/config/tmp/list-animes-id.json"
			size=$(du -b "$SCRIPT_FOLDER/config/tmp/list-animes-id.json" | awk '{ print $1 }')
		else
			curl -s "https://raw.githubusercontent.com/Arial-Z/Animes-ID/main/list-movies-id.json" > "$SCRIPT_FOLDER/config/tmp/list-movies-id.json"
			size=$(du -b "$SCRIPT_FOLDER/config/tmp/list-movies-id.json" | awk '{ print $1 }')
		fi
			((wait_time++))
		if [[ $size -gt 1000 ]]
		then
			printf "%s - Done\n\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			break
		fi
		if [[ $wait_time == 4 ]]
		then
			printf "%s - Error can't download anime ID mapping file, exiting\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			exit 1
		fi
		sleep 30
	done
}
function get-anilist-id () {
	if [[ $media_type == "animes" ]]
	then
		jq --arg tvdb_id "$tvdb_id" '.[] | select( .tvdb_id == $tvdb_id ) | select( .tvdb_season == "1" or .tvdb_season == "-1" ) | select( .tvdb_epoffset == "0" ) | .anilist_id' -r "$SCRIPT_FOLDER/config/tmp/list-animes-id.json" | head -n 1
	else
		jq --arg imdb_id "$imdb_id" '.[] | select( .imdb_id == $imdb_id ) | .anilist_id' -r "$SCRIPT_FOLDER/config/tmp/list-movies-id.json" | head -n 1
	fi
}
function get-mal-id () {
	invalid_mal_id=0
	mal_id=$(jq '.data.Media.idMal' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
	if [[ "$mal_id" == 'null' ]] || [[ "$mal_id" == 0 ]]
	then
		printf "%s\t\t - Missing MAL ID for Anilist ID : %s / %s\n" "$(date +%H:%M:%S)" "$anilist_id" "$plex_title" | tee -a "$LOG"
		printf "%s - Missing MAL ID for Anilist ID : %s / %s\n" "$(date +%H:%M:%S)" "$anilist_id" "$plex_title" >> "$MATCH_LOG"
		invalid_mal_id=1
	fi
}
function get-tvdb-id () {
	jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | .tvdb_id' -r "$SCRIPT_FOLDER/config/tmp/list-animes-id.json"
}
function get-anilist-infos () {
	if [ ! -f "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" ]
	then
		printf "%s\t\t - Downloading data for anilist id : %s\n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
		curl -s 'https://graphql.anilist.co/' \
		-X POST \
		-H 'content-type: application/json' \
		--data '{ "query": "{ Media(type: ANIME, id: '"$anilist_id"') { title { romaji(stylised:false), english(stylised:false), native(stylised:false) }, averageScore, genres, tags { name, rank },studios { edges { node { name, isAnimationStudio } } }, season, seasonYear, coverImage { extraLarge }, idMal} }" }' > "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" -D "$SCRIPT_FOLDER/config/tmp/anilist-limit-rate.txt"
		rate_limit=0
		rate_limit=$(grep -oP '(?<=x-ratelimit-remaining: )[0-9]+' "$SCRIPT_FOLDER/config/tmp/anilist-limit-rate.txt")
		if [[ -z $rate_limit ]]
		then
			printf "%s - Cloudflare rate limit reached watiting 60s" "$(date +%H:%M:%S)" | tee -a "$LOG"
			sleep 61
			curl -s 'https://graphql.anilist.co/' \
			-X POST \
			-H 'content-type: application/json' \
			--data '{ "query": "{ Media(type: ANIME, id: '"$anilist_id"') { title { romaji(stylised:false), english(stylised:false), native(stylised:false) }, averageScore, genres, tags { name, rank },studios { edges { node { name, isAnimationStudio } } }, season, seasonYear, coverImage { extraLarge }, idMal} }" }' > "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" -D "$SCRIPT_FOLDER/config/tmp/anilist-limit-rate.txt"
			sleep 0.75
			printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
		else
			if [[ rate_limit -lt 2 ]]
			then
				printf "%s - Anilist API limit reached watiting 30s" "$(date +%H:%M:%S)" | tee -a "$LOG"
				sleep 30
			else
				sleep 0.75
				printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			fi
		fi
	fi
}
function get-mal-infos () {
	if [ ! -f "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json" ]
	then
		printf "%s\t\t - Downloading data for MAL id : %s\n" "$(date +%H:%M:%S)" "$mal_id" | tee -a "$LOG"
		curl -s -o "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json" -w "%{http_code}" "https://api.jikan.moe/v4/anime/$mal_id" > "$SCRIPT_FOLDER/config/tmp/jikan-limit-rate.txt"
		if grep -q -w "429" "$SCRIPT_FOLDER/config/tmp/jikan-limit-rate.txt"
		then
			printf "%s - Jikan API limit reached watiting 15s" "$(date +%H:%M:%S)" | tee -a "$LOG"
			sleep 15
			curl -s -o "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json" -w "%{http_code}" "https://api.jikan.moe/v4/anime/$mal_id" > "$SCRIPT_FOLDER/config/tmp/jikan-limit-rate.txt"
		fi
		sleep 1.1
			printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
	fi
}
function get-romaji-title () {
	title="null"
	title_tmp="null"
	if awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/config/$OVERRIDE" | grep -q -w "$anilist_id"
	then
		line=$(awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/config/$OVERRIDE" | grep -w -n "$anilist_id" | cut -d : -f 1)
		title_tmp=$(sed -n "${line}p" "$SCRIPT_FOLDER/config/$OVERRIDE" | awk -F"\t" '{print $3}')
		if [[ -z "$title_tmp" ]]
		then
			title=$(jq '.data.Media.title.romaji' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
			less-caps-title
			echo "$title"
		else
			title="$title_tmp"
			less-caps-title
			echo "$title"
		fi
	else
		title=$(jq '.data.Media.title.romaji' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
		less-caps-title
		echo "$title"
	fi
}
function get-english-title () {
	title="null"
	title_tmp="null"
	if awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/config/$OVERRIDE" | grep -q -w "$anilist_id"
	then
		line=$(awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/config/$OVERRIDE" | grep -w -n "$anilist_id" | cut -d : -f 1)
		title_tmp=$(sed -n "${line}p" "$SCRIPT_FOLDER/config/$OVERRIDE" | awk -F"\t" '{print $3}')
		if [[ -z "$title_tmp" ]]
		then
			title=$(jq '.data.Media.title.english' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
			less-caps-title
			echo "$title"
		else
			title="$title_tmp"
			less-caps-title
			echo "$title"
		fi
	else
		title=$(jq '.data.Media.title.english' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
		less-caps-title
		echo "$title"
	fi
}
function get-native-title () {
	title=$(jq '.data.Media.title.native' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
	echo "$title"
}
function less-caps-title () {
	if [[ $REDUCE_TITLE_CAPS == "Yes" ]]
	then
		upper_check=$(echo "$title" | sed -e "s/[^ a-zA-Z]//g" -e 's/ //g')
		if [[ "$upper_check" =~ ^[A-Z]+$ ]]
		then
			title=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed "s/\( \|^\)\(.\)/\1\u\2/g")
		fi
	fi
}
function get-score () {
	anime_score=0
	anime_score=$(jq '.data.Media.averageScore' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
	if [[ "$anime_score" == "null" ]] || [[ "$anime_score" == "" ]]
	then
		rm "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json"
		get-anilist-infos
		anime_score=$(jq '.data.Media.averageScore' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
		if [[ "$anime_score" == "null" ]] || [[ "$anime_score" == "" ]]
		then
			anime_score=0
		fi
	else
		anime_score=$(printf %s "$anime_score" | awk '{print $1 / 10}')
	fi
}
function get-mal-score () {
	get-mal-id
	if [[ $invalid_mal_id == 1 ]]
	then
		anime_score=0
	else
		get-mal-infos
		anime_score=0
		anime_score=$(jq '.data.score' -r "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json")
		if [[ "$anime_score" == "null" ]] || [[ "$anime_score" == "" ]]
		then
			rm "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json"
			get-mal-infos
			anime_score=$(jq '.data.score' -r "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json")
			if [[ "$anime_score" == "null" ]] || [[ "$anime_score" == "" ]]
			then
				anime_score=0
			fi
		fi
	fi
}
function get-tags () {
	(jq '.data.Media.genres | .[]' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" && jq --argjson anilist_tags_p "$ANILIST_TAGS_P" '.data.Media.tags | .[] | select( .rank >= $anilist_tags_p ) | .name' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json") | awk '{print $0}' | paste -sd ','
}
function get-studios() {
	if awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/config/$OVERRIDE" | grep -q -w "$anilist_id"
	then
		line=$(awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/config/$OVERRIDE" | grep -w -n "$anilist_id" | cut -d : -f 1)
		studio=$(sed -n "${line}p" "$SCRIPT_FOLDER/config/$OVERRIDE" | awk -F"\t" '{print $4}')
		if [[ -z "$studio" ]]
		then
			studio=$(jq '.data.Media.studios.edges[].node | select( .isAnimationStudio == true ) | .name' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" | head -n 1)
			if [[ -z "$studio" ]]
			then
				studio=$(jq '.data.Media.studios.edges[].node | .name' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" | head -n 1)
			fi
		fi
	else
		studio=$(jq '.data.Media.studios.edges[].node | select( .isAnimationStudio == true ) | .name' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" | head -n 1)
		if [[ -z "$studio" ]]
		then
			studio=$(jq '.data.Media.studios.edges[].node | .name' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" | head -n 1)
		fi
	fi
}
function get-animes-season-year () {
	(jq '.data.Media.season' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" && jq '.data.Media.seasonYear' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json") | paste -sd ' ' | tr '[:upper:]' '[:lower:]' | sed "s/\( \|^\)\(.\)/\1\u\2/g"
}
function download-airing-info () {
	if [ ! -f "$SCRIPT_FOLDER/config/data/relations-$anilist_id.json" ]
	then
		printf "%s\t\t\t - Downloading airing info for Anilist : %s\n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
		curl -s 'https://graphql.anilist.co/' \
		-X POST \
		-H 'content-type: application/json' \
		--data '{ "query": "{ Media(type: ANIME, id: '"$anilist_id"') { relations { edges { relationType node { id type format title { romaji } status } } } } }" }' > "$SCRIPT_FOLDER/config/data/relations-$anilist_id.json" -D "$SCRIPT_FOLDER/config/tmp/anilist-limit-rate.txt"
		rate_limit=0
		rate_limit=$(grep -oP '(?<=x-ratelimit-remaining: )[0-9]+' "$SCRIPT_FOLDER/config/tmp/anilist-limit-rate.txt")
		if [[ -z $rate_limit ]]
		then
			printf "%s - Cloudflare rate limit reached watiting 60s" "$(date +%H:%M:%S)" | tee -a "$LOG"
			sleep 61
			curl -s 'https://graphql.anilist.co/' \
			-X POST \
			-H 'content-type: application/json' \
			--data '{ "query": "{ Media(type: ANIME, id: '"$anilist_id"') { relations { edges { relationType node { id type format title { romaji } status } } } } }" }' > "$SCRIPT_FOLDER/config/data/relations-$anilist_id.json" -D "$SCRIPT_FOLDER/config/tmp/anilist-limit-rate.txt"
			sleep 0.75
			printf "%s\t\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
		else
			if [[ rate_limit -lt 2 ]]
			then
				printf "%s - Anilist API limit rate left %s watiting 30s\n" "$(date +%H:%M:%S)" "$rate_limit" | tee -a "$LOG"
				sleep 30
			else
				sleep 0.75
				printf "%s\t\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			fi
		fi
	fi
}
function get-airing-status () {
	anilist_backup_id=$anilist_id
	airing_status="Ended"
	last_sequel_found=0
	sequel_multi_check=0
	while [ $last_sequel_found -lt 50 ];
	do
		if [[ $sequel_multi_check -gt 0 ]]
		then
			anilist_multi_id_backup=$anilist_id
			:> "$SCRIPT_FOLDER/config/tmp/airing_sequel_tmp.json"
			while IFS=$'\n' read -r anilist_id
			do
				download-airing-info
				cat "$SCRIPT_FOLDER/config/data/relations-$anilist_id.json" >> "$SCRIPT_FOLDER/config/tmp/airing_sequel_tmp.json"
			done < "$SCRIPT_FOLDER/config/tmp/airing_sequel_tmp.txt"
			anilist_id=$anilist_multi_id_backup
			sequel_data=$(jq '.data.Media.relations.edges[] | select ( .relationType == "SEQUEL" ) | .node | select ( .format == "TV" or .format == "ONA" or .format == "MOVIE" or .format == "OVA" )' -r "$SCRIPT_FOLDER/config/tmp/airing_sequel_tmp.json")
			if [ -z "$sequel_data" ]
			then
				airing_status="Ended"
				anilist_id=$anilist_backup_id
				break
			else
				sequel_check=$(printf "%s" "$sequel_data" | jq 'select ( .format == "TV" or .format == "ONA" or .format == "MOVIE" )')
				if echo "$sequel_check" | grep -q -w "NOT_YET_RELEASED"
				then
					airing_status="Planned"
					anilist_id=$anilist_backup_id
					break
				else
					anilist_id=$(printf "%s" "$sequel_data" | jq '.id')
					sequel_multi_check=$(printf %s "$anilist_id" | wc -l)
					if [[ $sequel_multi_check -gt 0 ]]
					then
						printf "%s" "$anilist_id" > "$SCRIPT_FOLDER/config/tmp/airing_sequel_tmp.txt"
						anilist_id=$( printf "%s" "$anilist_id" | head -n 1)
						((last_sequel_found++))
					else
						((last_sequel_found++))
					fi
				fi
			fi
		else
			download-airing-info
			sequel_data=$(jq '.data.Media.relations.edges[] | select ( .relationType == "SEQUEL" ) | .node | select ( .format == "TV" or .format == "ONA" or .format == "MOVIE" or .format == "OVA" )' -r "$SCRIPT_FOLDER/config/data/relations-$anilist_id.json")
			if [ -z "$sequel_data" ]
			then
				airing_status="Ended"
				anilist_id=$anilist_backup_id
				break
			else
				sequel_check=$(printf "%s" "$sequel_data" | jq 'select ( .format == "TV" or .format == "ONA" or .format == "MOVIE" )')
				if echo "$sequel_check" | grep -q -w "NOT_YET_RELEASED"
				then
					airing_status="Planned"
					anilist_id=$anilist_backup_id
					break
				else
					anilist_id=$(printf "%s" "$sequel_data" | jq '.id')
					sequel_multi_check=$(printf %s "$anilist_id" | wc -l)
					if [[ $sequel_multi_check -gt 0 ]]
					then
						printf "%s\n" "$anilist_id" > "$SCRIPT_FOLDER/config/tmp/airing_sequel_tmp.txt"
						anilist_id=$( printf "%s" "$anilist_id" | head -n 1)
						((last_sequel_found++))
					else
						((last_sequel_found++))
					fi
				fi
			fi
		fi
	done
	anilist_id=$anilist_backup_id
	if [[ $last_sequel_found -ge 50 ]]
	then
		airing_status="Ended"
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
				printf "%s\t\t - Downloading poster for MAL id : %s\n" "$(date +%H:%M:%S)" "$mal_id" | tee -a "$LOG"
				poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json")
				curl -s "$poster_url" -o "$ASSET_FOLDER/$asset_name/poster.jpg"
				sleep 1.5
				printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			else
				printf "%s\t\t - Downloading poster for anilist id : %s\n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
				poster_url=$(jq '.data.Media.coverImage.extraLarge' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
				curl -s "$poster_url" -o "$ASSET_FOLDER/$asset_name/poster.jpg"
				sleep 0.5
				printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
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
					printf "%s\t\t - Downloading poster for MAL id : %s\n" "$(date +%H:%M:%S)" "$mal_id" | tee -a "$LOG"
					poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json")
					curl -s "$poster_url" -o "$ASSET_FOLDER/$asset_name/poster.jpg"
					sleep 1.5
					printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				else
					printf "%s\t\t - Downloading poster for anilist id : %s\n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
					poster_url=$(jq '.data.Media.coverImage.extraLarge' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
					curl -s "$poster_url" -o "$ASSET_FOLDER/$asset_name/poster.jpg"
					sleep 0.5
					printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				fi
			fi
		fi
	fi
}
function get-season-poster () {
	if [[ $POSTER_SEASON_DOWNLOAD == "Yes" ]]
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
				printf "%s\t\t - Downloading poster for MAL id : %s\n" "$(date +%H:%M:%S)" "$mal_id" | tee -a "$LOG"
				poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json")
				curl -s "$poster_url" -o "$assets_filepath"
				sleep 1.5
				printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			else
				printf "%s\t\t - Downloading poster for anilist id : %s\n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
				poster_url=$(jq '.data.Media.coverImage.extraLarge' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
				curl -s "$poster_url" -o "$assets_filepath"
				sleep 0.5
				printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
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
					printf "%s\t\t - Downloading poster for MAL id : %s\n" "$(date +%H:%M:%S)" "$mal_id" | tee -a "$LOG"
					poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json")
					curl -s "$poster_url" -o "$assets_filepath"
					sleep 1.5
					printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				else
					printf "%s\t\t - Downloading poster for anilist id : %s\n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
					poster_url=$(jq '.data.Media.coverImage.extraLarge' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
					curl -s "$poster_url" -o "$assets_filepath"
					sleep 0.5
					printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				fi
			fi
		fi
	fi
}
function get-season-infos () {
	anilist_backup_id=$anilist_id
	season_check=$(jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | .tvdb_season' -r "$SCRIPT_FOLDER/config/tmp/list-animes-id.json")
	first_season=$(echo "$seasons_list" | awk -F "," '{print $1}')
	last_season=$(echo "$seasons_list" | awk -F "," '{print $NF}')
	total_seasons=$(echo "$seasons_list" | awk -F "," '{print NF}')
	if [[ "$first_season" -eq 0 ]]
	then
		total_seasons=$((total_seasons - 1))
	fi
	if [[ $season_check != -1 ]]
	then
		total_score=0
		score_season=0
		no_rating_seasons=0
		printf "    seasons:\n" >> "$METADATA"
		IFS=","
		for season_number in $seasons_list
		do
			if [[ $season_number -eq 0 ]]
			then
				printf "      0:\n        label.remove: score\n" >> "$METADATA"
			else
				if [[ $last_season -eq 1 && $IGNORE_S1 == "Yes" ]]
				then
					anilist_id=$anilist_backup_id
					if [[ $RATING_SOURCE == "ANILIST" ]]
					then
						get-score
						score_season=$anime_score
					else
						get-mal-score
						score_season=$anime_score
					fi
					score_season=$(printf '%.*f\n' 1 "$score_season")
					if [[ $SEASON_YEAR == "Yes" ]]
					then
						anime_season=$(get-animes-season-year)
						printf "      1:\n        label.sync: %s\n" "$anime_season" >> "$METADATA"
					else
						printf "      1:\n        label.remove: score\n" >> "$METADATA"
					fi
					total_score=$(echo | awk -v v1="$score_season" -v v2="$total_score" '{print v1 + v2}')
					get-season-poster
				else
					anilist_id=$(jq --arg tvdb_id "$tvdb_id" --arg season_number "$season_number" '.[] | select( .tvdb_id == $tvdb_id ) | select( .tvdb_season == $season_number ) | select( .tvdb_epoffset == "0" ) | .anilist_id' -r "$SCRIPT_FOLDER/config/tmp/list-animes-id.json" | head -n 1)
					if [[ -n "$anilist_id" ]]
					then
						get-anilist-infos
						romaji_title=$(get-romaji-title)
						english_title=$(get-english-title)
						if [[ $MAIN_TITLE_ENG == "Yes" ]]
						then
							english_title=$romaji_title
						fi
						if [[ $RATING_SOURCE == "ANILIST" ]]
						then
							get-score
							score_season=$anime_score
						else
							get-mal-score
							score_season=$anime_score
						fi
						score_season=$(printf '%.*f\n' 1 "$score_season")
						if [[ "$score_season" == 0.0 ]]
						then
							((no_rating_seasons++))
						fi
						if [[ $SEASON_YEAR == "Yes" ]]
						then
							anime_season=$(get-animes-season-year)
							if [[ $ALLOW_RENAMING == "Yes" && $RENAME_SEASONS == "Yes" ]]
							then
								printf "      %s:\n        title: |-\n          %s\n        user_rating: %s\n        label: %s,score\n" "$season_number" "$romaji_title" "$score_season" "$anime_season" >> "$METADATA"
							else
								printf "      %s:\n        user_rating: %s\n        label: %s,score\n" "$season_number" "$score_season" "$anime_season" >> "$METADATA"
							fi
						else
							if [[ $ALLOW_RENAMING == "Yes" && $RENAME_SEASONS == "Yes" ]]
							then
								printf "      %s:\n        title: |-\n          %s\n        user_rating: %s\n        label: score\n" "$season_number" "$romaji_title" "$score_season" >> "$METADATA"
							else
								printf "      %s:\n        user_rating: %s\n        label: score\n" "$season_number" "$score_season" >> "$METADATA"
							fi
						fi
						total_score=$(echo | awk -v v1="$score_season" -v v2="$total_score" '{print v1 + v2}')
						get-season-poster
					else
						printf "%s\t\t - Missing Anilist ID for tvdb : %s - Season : %s / %s\n" "$(date +%H:%M:%S)" "$tvdb_id" "$season_number" "$plex_title" | tee -a "$LOG"
						printf "%s - Missing Anilist ID for tvdb : %s - Season : %s / %s\n" "$(date +%H:%M:%S)" "$tvdb_id" "$season_number" "$plex_title" >> "$MATCH_LOG"
					fi
				fi
			fi
		done
		if [[ "$total_score" != "0" ]]
		then
			total_seasons=$((total_seasons - no_rating_seasons))
			score=$(echo | awk -v v1="$total_score" -v v2="$total_seasons" '{print v1 / v2}')
			score=$(printf '%.*f\n' 1 "$score")
		else
			score=0
		fi
	else
		if [[ $RATING_SOURCE == "ANILIST" ]]
		then
			get-score
			score=$anime_score
		else
			get-mal-score
			score=$anime_score
		fi
		if [[ "$score" != 0 ]]
		then
			score=$(printf '%.*f\n' 1 "$score")
		fi
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
	romaji_title=$(get-romaji-title)
	english_title=$(get-english-title)
	native_title=$(get-native-title)
		if [ "$english_title" == "null" ]
	then
		english_title=$romaji_title
	fi
	if [[ $ALLOW_RENAMING == "Yes" ]]
	then
		if [[ $MAIN_TITLE_ENG == "Yes" ]]
		then
			if [[ $ORIGINAL_TITLE_NATIVE == "Yes" ]]
			then
				printf "    title: |-\n      %s\n    sort_title: |-\n      %s\n    original_title: |-\n      %s\n" "$english_title" "$english_title" "$native_title" >> "$METADATA"
			else
				printf "    title: |-\n      %s\n    sort_title: |-\n      %s\n    original_title: |-\n      %s\n" "$english_title" "$english_title" "$romaji_title" >> "$METADATA"
			fi
		else
			printf "    title: |-\n      %s\n" "$romaji_title" >> "$METADATA"
			if [[ $SORT_TITLE_ENG == "Yes" ]]
			then
				printf "    sort_title: |-\n      %s\n" "$english_title" >> "$METADATA"
			else
				printf "    sort_title: |-\n      %s\n" "$romaji_title" >> "$METADATA"
			fi
			if [[ $ORIGINAL_TITLE_NATIVE == "Yes" ]]
			then
				printf "    original_title: |-\n      %s\n" "$native_title" >> "$METADATA"
			else
				printf "    original_title: |-\n      %s\n" "$english_title" >> "$METADATA"
			fi
		fi
	fi
	anime_tags=$(get-tags)
	printf "    genre.sync: Anime,%s\n" "$anime_tags" >> "$METADATA"
	if [[ $media_type == "animes" ]]
	then
		printf "%s\t\t - Writing airing status for tvdb id : %s / Anilist id : %s \n" "$(date +%H:%M:%S)" "$tvdb_id" "$anilist_id" | tee -a "$LOG"
		if awk -F"\t" '{print "\""$1"\":"}' "$SCRIPT_FOLDER/config/data/ongoing.tsv" | grep -q -w "$tvdb_id"
		then
			printf "    label: Airing\n" >> "$METADATA"
			printf "    label.remove: Planned,Ended\n" >> "$METADATA"
			printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
		else
			get-airing-status
			if [[ $airing_status == Planned ]]
			then
				printf "    label: Planned\n" >> "$METADATA"
				printf "    label.remove: Airing,Ended\n" >> "$METADATA"
				printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			else
				printf "    label: Ended\n" >> "$METADATA"
				printf "    label.remove: Planned,Airing\n" >> "$METADATA"
				printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			fi
		fi
	fi
	get-studios
	printf "    studio: %s\n" "$studio" >> "$METADATA"
	get-poster
	if [[ $media_type == "animes" ]] && [[ $IGNORE_SEASONS != "Yes" ]]
	then
		if awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/config/$OVERRIDE" | grep -q -w "$anilist_id"
		then
			line=$(awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/config/$OVERRIDE" | grep -w -n "$anilist_id" | cut -d : -f 1)
			if sed -n "${line}p" "$SCRIPT_FOLDER/config/$OVERRIDE" | awk -F"\t" '{print $5}' | grep -q -i -w "Yes"
			then
				if [[ $RATING_SOURCE == "ANILIST" ]]
				then
					get-score
					score=$anime_score
				else
					get-mal-score
					score=$anime_score
				fi
				if [[ "$score" == 0 ]]
				then
					printf "%s\t\t - invalid rating for Anilist id : %s skipping \n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
				else
					score=$(printf '%.*f\n' 1 "$score")
					printf "    %s_rating: %s\n" "$WANTED_RATING" "$score" >> "$METADATA"
				fi
			else
				get-season-infos
				if [[ "$score" == 0 ]]
				then
					printf "%s\t\t - invalid rating for Anilist id : %s skipping \n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
				else
					printf "    %s_rating: %s\n" "$WANTED_RATING" "$score" >> "$METADATA"
				fi
			fi
		else
			get-season-infos
			if [[ "$score" == 0 ]]
			then
				printf "%s\t\t - invalid rating for Anilist id : %s skipping \n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
			else
			printf "    %s_rating: %s\n" "$WANTED_RATING" "$score" >> "$METADATA"
			fi
		fi
	else
		if [[ $RATING_SOURCE == "ANILIST" ]]
		then
			get-score
			score=$anime_score
		else
			get-mal-score
			score=$anime_score
		fi
		if [[ "$score" == 0 ]]
		then
			printf "%s\t\t - invalid rating for Anilist id : %s skipping \n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
		else
			score=$(printf '%.*f\n' 1 "$score")
			printf "    %s_rating: %s\n" "$WANTED_RATING" "$score" >> "$METADATA"
		fi
	fi
}