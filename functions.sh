#!/bin/bash

#General variables
LOG=$LOG_FOLDER/RR_$(date +%Y.%m.%d).log
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
	while [ $wait_time -lt 5 ];
	do
		printf "%s - Downloading animes mapping\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
		if [[ $media_type == "animes" ]]
		then
			curl -s "https://raw.githubusercontent.com/Arial-Z/Animes-ID/main/list-animes-id.json" > "$SCRIPT_FOLDER/config/tmp/list-animes-id.json"
			size=$(du -b "$SCRIPT_FOLDER/config/tmp/list-animes-id.json" | awk '{ print $1 }')
		else
			curl -s "https://raw.githubusercontent.com/Arial-Z/Animes-ID/main/list-movies-id.json" > "$SCRIPT_FOLDER/config/tmp/list-movies-id.json"
			size=$(du -b "$SCRIPT_FOLDER/config/tmp/list-movies-id.json" | awk '{ print $1 }')
		fi
		((wait_time++))
		if [[ $wait_time == 4 ]]
		then
			printf "%s - Error can't download animes mapping file stopping script\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			exit 1
		elif [[ $size -gt 1000 ]]
		then
			printf "%s - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			break
		fi
		sleep 30
	done
	wait_time=0
	while [ $wait_time -lt 5 ];
	do
		printf "%s - Downloading animes awards data\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
		curl -s "https://raw.githubusercontent.com/Arial-Z/Animes-ID/main/cr-award/cr-award.json" > "$SCRIPT_FOLDER/config/tmp/cr-award.json"
		size=$(du -b "$SCRIPT_FOLDER/config/tmp/cr-award.json" | awk '{ print $1 }')
		((wait_time++))
		if [[ $wait_time == 4 ]]
		then
			printf "%s - Error can't download animes awards file stopping script\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			exit 1
		elif [[ $size -gt 1000 ]]
		then
			printf "%s - Done\n\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			break
		fi
		sleep 30
	done
}
function get-anilist-userlist {
	if [[ $ANILIST_LISTS == "Yes" ]]
	then
		printf "%s - Creating Anilist userlist for : %s\n" "$(date +%H:%M:%S)" "$ANILIST_USERNAME" | tee -a "$LOG"
		wait_time=0
		anilist_api_retry=0
		while [ $wait_time -lt 5 ] || [ $anilist_api_retry -lt 5 ];
		do
			printf "%s\t - Downloading Anilist userlist\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			curl -s 'https://graphql.anilist.co/' \
			-X POST \
			-H 'content-type: application/json' \
			--data '{ "query": "{ MediaListCollection(userName: \"'"$ANILIST_USERNAME"'\" type:ANIME) {  lists {    name    entries {      mediaId    }  }}}" }' > "$SCRIPT_FOLDER/config/tmp/anilist-$ANILIST_USERNAME.json" -D "$SCRIPT_FOLDER/config/tmp/anilist-limit-rate.txt"
			if grep -q -w '"data": null' "$SCRIPT_FOLDER/config/tmp/anilist-$ANILIST_USERNAME.json"
			then
				((anilist_api_retry++))
				rm "$SCRIPT_FOLDER/config/tmp/anilist-$ANILIST_USERNAME.json"
				printf "%s - Invalid json from AniList API down, waiting 60s\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				sleep 61
			fi
			rate_limit=0
			rate_limit=$(grep -oP '(?<=x-ratelimit-remaining: )[0-9]+' "$SCRIPT_FOLDER/config/tmp/anilist-limit-rate.txt")
			((wait_time++))
			if [[ $wait_time == 4 ]] || [[ $anilist_api_retry == 4 ]]
			then
				printf "%s - Error can't download anilist data stopping script\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				exit 1
			elif [[ -z $rate_limit ]]
			then
				printf "%s\t - Cloudflare limit rate reached watiting 60s\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				sleep 61
			elif [[ $rate_limit -ge 3 ]]
			then
				sleep 1
				printf "%s\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				break
			elif [[ $rate_limit -lt 3 ]]
			then
				printf "%s\t - Anilist API limit reached watiting 30s" "$(date +%H:%M:%S)" | tee -a "$LOG"
				sleep 30
				printf "%s\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				break
			fi
		done
		printf "%s\t - Sorting Anilist userlist\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
		jq '.data.MediaListCollection.lists | .[] | select( .name == "Completed" ) | .entries | .[].mediaId ' -r "$SCRIPT_FOLDER/config/tmp/anilist-$ANILIST_USERNAME.json" | paste -s -d, - > "$SCRIPT_FOLDER/config/data/anilist-$ANILIST_USERNAME-Completed.tsv"
		jq '.data.MediaListCollection.lists | .[] | select( .name == "Watching" ) | .entries | .[].mediaId ' -r "$SCRIPT_FOLDER/config/tmp/anilist-$ANILIST_USERNAME.json" | paste -s -d, - > "$SCRIPT_FOLDER/config/data/anilist-$ANILIST_USERNAME-Watching.tsv"
		jq '.data.MediaListCollection.lists | .[] | select( .name == "Dropped" ) | .entries | .[].mediaId ' -r "$SCRIPT_FOLDER/config/tmp/anilist-$ANILIST_USERNAME.json" | paste -s -d, - > "$SCRIPT_FOLDER/config/data/anilist-$ANILIST_USERNAME-Dropped.tsv"
		jq '.data.MediaListCollection.lists | .[] | select( .name == "Paused" ) | .entries | .[].mediaId ' -r "$SCRIPT_FOLDER/config/tmp/anilist-$ANILIST_USERNAME.json" | paste -s -d, - > "$SCRIPT_FOLDER/config/data/anilist-$ANILIST_USERNAME-Paused.tsv"
		jq '.data.MediaListCollection.lists | .[] | select( .name == "Planning" ) | .entries | .[].mediaId ' -r "$SCRIPT_FOLDER/config/tmp/anilist-$ANILIST_USERNAME.json" | paste -s -d, - > "$SCRIPT_FOLDER/config/data/anilist-$ANILIST_USERNAME-Planning.tsv"
		printf "%s\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
		printf "%s - done\n\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
	fi
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
	mal_id=$(jq '.data.Media.idMal' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
	if [[ $mal_id == 'null' ]] || [[ -z $mal_id ]]
	then
		if [[ $media_type == "animes" ]]
		then
			mal_id=$(jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | .mal_id' -r "$SCRIPT_FOLDER/config/tmp/list-animes-id.json" | head -n 1)
		else
			mal_id=$(jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | .mal_id' -r "$SCRIPT_FOLDER/config/tmp/list-movies-id.json" | head -n 1)
		fi
	fi
}
function get-tvdb-id () {
	jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | .tvdb_id' -r "$SCRIPT_FOLDER/config/tmp/list-animes-id.json"
}
function get-anilist-infos () {
	if [ ! -f "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" ]
	then
		wait_time=0
		anilist_api_retry=0
		while [ $wait_time -lt 5 ] || [ $anilist_api_retry -lt 5 ];
		do
			if [[ "$airing_loop" == 1 ]]
			then
				printf "%s\t\t\t - Downloading airing info for Anilist : %s\n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
			elif [[ $cours_count_total -gt 1 ]]
			then
				printf "%s\t\t - Downloading data for S%s part-%s Anilist : %s\n" "$(date +%H:%M:%S)" "$season_number" "$cours_count" "$anilist_id" | tee -a "$LOG"
			elif [[ "$season_loop" == 1 ]]
			then
				printf "%s\t\t - Downloading data for S%s anilist : %s\n" "$(date +%H:%M:%S)" "$season_number" "$anilist_id" | tee -a "$LOG"
			else
				printf "%s\t\t - Downloading data for anilist : %s\n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
			fi
			curl -s 'https://graphql.anilist.co/' \
			-X POST \
			-H 'content-type: application/json' \
			--data '{ "query": "{ Media(type: ANIME, id: '"$anilist_id"') { relations { edges { relationType node { id type format title { romaji } status } } } title { romaji(stylised: false) english(stylised: false) native(stylised: false) } averageScore genres tags { name rank } studios { edges { node { name isAnimationStudio } } } startDate { year month } season seasonYear coverImage { extraLarge } status idMal} }" }' > "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" -D "$SCRIPT_FOLDER/config/tmp/anilist-limit-rate.txt"
			if grep -q -w '"data": null' "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json"
			then
				((anilist_api_retry++))
				rm "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json"
				printf "%s - Invalid json from AniList API down, waiting 60s\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				sleep 61
			fi
			rate_limit=0
			rate_limit=$(grep -oP '(?<=x-ratelimit-remaining: )[0-9]+' "$SCRIPT_FOLDER/config/tmp/anilist-limit-rate.txt")
			((wait_time++))
			if [[ $wait_time == 4 ]] || [[ $anilist_api_retry == 4 ]]
			then
				printf "%s - Error can't download anilist data stopping script\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				exit 1
			elif [[ -z $rate_limit ]]
			then
				printf "%s\t\t - Cloudflare limit rate reached watiting 60s\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				sleep 61
			elif [[ $rate_limit -ge 3 ]]
			then
				sleep 1
				if [[ "$airing_loop" == 1 ]]
				then
					printf "%s\t\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				else
					printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				fi
				break
			elif [[ $rate_limit -lt 3 ]]
			then
				printf "%s\t\t - Anilist API limit reached watiting 30s" "$(date +%H:%M:%S)" | tee -a "$LOG"
				sleep 30
				if [[ "$airing_loop" == 1 ]]
				then
					printf "%s\t\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				else
					printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				fi
				break
			fi
		done
	fi
}
function get-mal-infos () {
	mal_id=""
	get-mal-id
	if [[ $mal_id == 'null' ]] || [[ -z $mal_id ]]
	then
		printf "%s\t\t - Missing MAL ID for Anilist : %s / %s\n" "$(date +%H:%M:%S)" "$anilist_id" "$plex_title" | tee -a "$LOG"
		printf "%s - Missing MAL ID for Anilist : %s / %s\n" "$(date +%H:%M:%S)" "$anilist_id" "$plex_title" >> "$MATCH_LOG"
	else
		if [ ! -f "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json" ]
		then
			if [[ $cours_count_total -gt 1 ]]
			then
				printf "%s\t\t - Downloading data for S%s part-%s MAL : %s\n" "$(date +%H:%M:%S)" "$season_number" "$cours_count" "$mal_id" | tee -a "$LOG"
			elif [[ "$season_loop" == 1 ]]
			then
				printf "%s\t\t - Downloading data for S%s MAL : %s\n" "$(date +%H:%M:%S)" "$season_number" "$mal_id" | tee -a "$LOG"
			else
				printf "%s\t\t - Downloading data for MAL : %s\n" "$(date +%H:%M:%S)" "$mal_id" | tee -a "$LOG"
			fi
			curl -s -o "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json" -w "%{http_code}" "https://api.jikan.moe/v4/anime/$mal_id" > "$SCRIPT_FOLDER/config/tmp/jikan-limit-rate.txt"
			if grep -q -w "429" "$SCRIPT_FOLDER/config/tmp/jikan-limit-rate.txt"
			then
				printf "%s - Jikan API limit reached watiting 30s" "$(date +%H:%M:%S)" | tee -a "$LOG"
				sleep 30
				curl -s -o "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json" -w "%{http_code}" "https://api.jikan.moe/v4/anime/$mal_id" > "$SCRIPT_FOLDER/config/tmp/jikan-limit-rate.txt"
				printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			fi
			sleep 1.1
				printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
		fi
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
		else
			anime_score=$(printf %s "$anime_score" | awk '{print $1 / 10}')
		fi
	else
		anime_score=$(printf %s "$anime_score" | awk '{print $1 / 10}')
	fi
}
function get-mal-score () {
mal_id=""
get-mal-id
if [[ $mal_id == 'null' ]] || [[ -z $mal_id ]]
then
	printf "%s\t\t - Missing MAL ID for Anilist : %s / %s\n" "$(date +%H:%M:%S)" "$anilist_id" "$plex_title" | tee -a "$LOG"
	printf "%s - Missing MAL ID for Anilist : %s / %s\n" "$(date +%H:%M:%S)" "$anilist_id" "$plex_title" >> "$MATCH_LOG"
else
	anime_score=0
	get-mal-infos
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
	anime_season=$( (jq '.data.Media.seasonYear' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" && jq '.data.Media.season' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json") | paste -sd ' ' | tr '[:upper:]' '[:lower:]' | sed "s/\( \|^\)\(.\)/\1\u\2/g")
	if [ "$anime_season" == "Null Null" ]
		then
		year_season=$(jq '.data.Media.startDate.year' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
		month_season=$(jq '.data.Media.startDate.month' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
		if [[ $month_season -le 3 ]]
		then
			name_season=Winter
		elif [[ $month_season -ge 4 && $month_season -le 6 ]]
		then
			name_season=Spring
		elif [[ $month_season -ge 7 && $month_season -le 9 ]]
		then
			name_season=Summer
		elif [[ $month_season -ge 10 ]]
		then
			name_season=Fall
		fi
		anime_season=$(printf "%s %s" "$year_season" "$name_season")
	fi
}
function get-animes-award () {
	award_check=""
	cr_awards=""
	if [[ $ANIME_AWARDS_NO_FVA == "Yes" ]]
	then
		award_check=$(jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | select(.cr_award | contains("English") or contains("Arabic") or contains("Spanish") or contains("Castilian") or contains("French")or contains("German") or contains("Italian") or contains("Portuguese") or contains("Russian")  | not) | "AA " + .year + " " + .cr_award' -r "$SCRIPT_FOLDER/config/tmp/cr-award.json" | paste -s -d, -)  > /dev/null
		if [[ -n $award_check ]]
		then
			cr_awards=$award_check
		fi
	else
		award_check=$(jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | "AA " + .year + " " + .cr_award' -r "$SCRIPT_FOLDER/config/tmp/cr-award.json" | paste -s -d, -)  > /dev/null
		if [[ -n $award_check ]]
		then
			cr_awards=$award_check
		fi
	fi
}
function get-airing-status () {
	if jq '.data.Media.status' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" | grep -q -w "NOT_YET_RELEASED"
	then
		airing_status="Planned"
	else
		airing_loop=0
		anilist_backup_id=$anilist_id
		airing_status="Ended"
		last_sequel_found=0
		sequel_multi_check=0
		while [ $last_sequel_found -lt 50 ];
		do
			airing_loop=1
			if [[ $sequel_multi_check -gt 0 ]]
			then
				anilist_multi_id_backup=$anilist_id
				:> "$SCRIPT_FOLDER/config/tmp/airing_sequel_tmp.json"
				while IFS=$'\n' read -r anilist_id
				do
					get-anilist-infos
					cat "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" >> "$SCRIPT_FOLDER/config/tmp/airing_sequel_tmp.json"
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
				get-anilist-infos
				sequel_data=$(jq '.data.Media.relations.edges[] | select ( .relationType == "SEQUEL" ) | .node | select ( .format == "TV" or .format == "ONA" or .format == "MOVIE" or .format == "OVA" )' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
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
		airing_loop=0
		anilist_id=$anilist_backup_id
		if [[ $last_sequel_found -ge 50 ]]
		then
			airing_status="Ended"
		fi
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
				get-mal-infos
				printf "%s\t\t - Downloading poster for MAL : %s\n" "$(date +%H:%M:%S)" "$mal_id" | tee -a "$LOG"
				poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json")
				curl -s "$poster_url" -o "$ASSET_FOLDER/$asset_name/poster.jpg"
				sleep 1.5
				printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			else
				printf "%s\t\t - Downloading poster for anilist : %s\n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
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
					get-mal-infos
					printf "%s\t\t - Downloading poster for MAL : %s\n" "$(date +%H:%M:%S)" "$mal_id" | tee -a "$LOG"
					poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json")
					curl -s "$poster_url" -o "$ASSET_FOLDER/$asset_name/poster.jpg"
					sleep 1.5
					printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				else
					printf "%s\t\t - Downloading poster for anilist : %s\n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
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
				get-mal-infos
				printf "%s\t\t - Downloading poster for S%s MAL : %s\n" "$(date +%H:%M:%S)" "$season_number" "$mal_id" | tee -a "$LOG"
				poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json")
				curl -s "$poster_url" -o "$assets_filepath"
				sleep 1.5
				printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			else
				printf "%s\t\t - Downloading poster for S%s anilist : %s\n" "$(date +%H:%M:%S)" "$season_number" "$anilist_id" | tee -a "$LOG"
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
					get-mal-infos
					printf "%s\t\t - Downloading poster S%s MAL : %s\n" "$(date +%H:%M:%S)" "$season_number" "$mal_id" | tee -a "$LOG"
					poster_url=$(jq '.data.images.jpg.large_image_url' -r "$SCRIPT_FOLDER/config/data/MAL-$mal_id.json")
					curl -s "$poster_url" -o "$assets_filepath"
					sleep 1.5
					printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				else
					printf "%s\t\t - Downloading poster S%s anilist : %s\n" "$(date +%H:%M:%S)" "$season_number" "$anilist_id" | tee -a "$LOG"
					poster_url=$(jq '.data.Media.coverImage.extraLarge' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json")
					curl -s "$poster_url" -o "$assets_filepath"
					sleep 0.5
					printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
				fi
			fi
		fi
	fi
}
function get-rating-1 () {
	if [[ $RATING_1_SOURCE == "ANILIST" || $RATING_1_SOURCE == "MAL" ]]
	then
		if [[ $RATING_1_SOURCE == "ANILIST" ]]
		then
			get-score
			score_1=$anime_score
		else
			get-mal-score
			score_1=$anime_score
		fi
	fi
	if [[ "$score_1" == 0 ]]
	then
		if [[ $RATING_1_SOURCE == "ANILIST" ]]
		then
			printf "%s\t\t - invalid rating for Anilist : %s skipping \n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
		else 
			printf "%s\t\t - invalid rating for MAL : %s skipping \n" "$(date +%H:%M:%S)" "$mal_id" | tee -a "$LOG"
		fi
	else
		score_1=$(printf '%.*f\n' 1 "$score_1")
		printf "    %s_rating: %s\n" "$RATING_1_TYPE" "$score_1" >> "$METADATA"
	fi
}
function get-season-rating-1 () {
	if [[ $RATING_1_SOURCE == "ANILIST" || $RATING_1_SOURCE == "MAL" ]]
	then
		if [[ $RATING_1_SOURCE == "ANILIST" ]]
		then
			get-score
			score_1_season=$anime_score
		else
			get-mal-score
			score_1_season=$anime_score
		fi
		score_1_season=$(printf '%.*f\n' 1 "$score_1_season")
		if [[ "$score_1_season" == 0.0 ]]
		then
			((score_1_no_rating_seasons++))
		fi
	fi
}
function get-cour-rating-1 () {
	if [[ $RATING_1_SOURCE == "ANILIST" || $RATING_1_SOURCE == "MAL" ]]
	then
		if [[ $RATING_1_SOURCE == "ANILIST" ]]
		then
			get-score
			score_1_cour=$anime_score
		else
			get-mal-score
			score_1_cour=$anime_score
		fi
		score_1_cour=$(printf '%.*f\n' 1 "$score_1_cour")
		if [[ "$score_1_cour" == 0.0 ]]
		then
			((score_1_no_rating_cours++))
		fi
	fi
}
function total-cour-rating-1 () {
	if [[ $RATING_1_SOURCE == "ANILIST" || $RATING_1_SOURCE == "MAL" ]]
	then
		total_1_cours_score=$(echo | awk -v v1="$score_1_cour" -v v2="$total_1_cours_score" '{print v1 + v2}')
	fi
}
function total-rating-1 () {
	if [[ $RATING_1_SOURCE == "ANILIST" || $RATING_1_SOURCE == "MAL" ]]
	then
		total_1_score=$(echo | awk -v v1="$score_1_season" -v v2="$total_1_score" '{print v1 + v2}')
	fi
}
function check-rating-1-valid () {
	if [[ $RATING_1_SOURCE == "ANILIST" || $RATING_1_SOURCE == "MAL" ]]
	then
		if [[ "$score_1" == 0 ]]
		then
			if [[ $RATING_1_SOURCE == "ANILIST" ]]
			then
				printf "%s\t\t - invalid rating for Anilist : %s skipping \n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
			else
				get-mal-id
				if [[ $mal_id != 'null' ]] || [[ -n $mal_id ]]
				then
					printf "%s\t\t - invalid rating for MAL : %s skipping \n" "$(date +%H:%M:%S)" "$mal_id" | tee -a "$LOG"
				fi
			fi
		else
			score_1=$(printf '%.*f\n' 1 "$score_1")
			printf "    %s_rating: %s\n" "$RATING_1_TYPE" "$score_1" >> "$METADATA"
		fi
	fi
}
function get-rating-2 () {
	if [[ $RATING_2_SOURCE == "ANILIST" || $RATING_2_SOURCE == "MAL" ]]
	then
		if [[ $RATING_2_SOURCE == "ANILIST" ]]
		then
			get-score
			score_2=$anime_score
		else
			get-mal-score
			score_2=$anime_score
		fi
	fi
	if [[ "$score_2" == 0 ]]
	then
		if [[ $RATING_2_SOURCE == "ANILIST" ]]
		then
			printf "%s\t\t - invalid rating for Anilist : %s skipping \n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
		else 
			printf "%s\t\t - invalid rating for MAL : %s skipping \n" "$(date +%H:%M:%S)" "$mal_id" | tee -a "$LOG"
		fi
	else
		score_2=$(printf '%.*f\n' 1 "$score_2")
		printf "    %s_rating: %s\n" "$RATING_2_TYPE" "$score_2" >> "$METADATA"
	fi
}
function get-season-rating-2 () {
	if [[ $RATING_2_SOURCE == "ANILIST" || $RATING_2_SOURCE == "MAL" ]]
	then
		if [[ $RATING_2_SOURCE == "ANILIST" ]]
		then
			get-score
			score_2_season=$anime_score
		else
			get-mal-score
			score_2_season=$anime_score
		fi
		score_2_season=$(printf '%.*f\n' 1 "$score_2_season")
		if [[ "$score_2_season" == 0.0 ]]
		then
			((score_2_no_rating_seasons++))
		fi
	fi
}
function get-cour-rating-2 () {
	if [[ $RATING_2_SOURCE == "ANILIST" || $RATING_2_SOURCE == "MAL" ]]
	then
		if [[ $RATING_2_SOURCE == "ANILIST" ]]
		then
			get-score
			score_2_cour=$anime_score
		else
			get-mal-score
			score_2_cour=$anime_score
		fi
		score_2_cour=$(printf '%.*f\n' 1 "$score_2_cour")
		if [[ "$score_2_cour" == 0.0 ]]
		then
			((score_2_no_rating_cours++))
		fi
	fi
}
function total-cour-rating-2 () {
	if [[ $RATING_2_SOURCE == "ANILIST" || $RATING_2_SOURCE == "MAL" ]]
	then
		total_2_cours_score=$(echo | awk -v v1="$score_2_cour" -v v2="$total_2_cours_score" '{print v1 + v2}')
	fi
}
function total-rating-2 () {
	if [[ $RATING_2_SOURCE == "ANILIST" || $RATING_2_SOURCE == "MAL" ]]
	then
		total_2_score=$(echo | awk -v v1="$score_2_season" -v v2="$total_2_score" '{print v1 + v2}')
	fi
}
function check-rating-2-valid () {
	if [[ $RATING_2_SOURCE == "ANILIST" || $RATING_2_SOURCE == "MAL" ]]
	then
		if [[ "$score_2" == 0 ]]
		then
			if [[ $RATING_2_SOURCE == "ANILIST" ]]
			then
				printf "%s\t\t - invalid rating for Anilist : %s skipping \n" "$(date +%H:%M:%S)" "$anilist_id" | tee -a "$LOG"
			else
				get-mal-id
				if [[ $mal_id == 'null' ]] || [[ -n $mal_id ]]
				then
					printf "%s\t\t - invalid rating for MAL : %s skipping \n" "$(date +%H:%M:%S)" "$mal_id" | tee -a "$LOG"
				fi
			fi
		else
			score_2=$(printf '%.*f\n' 1 "$score_2")
			printf "    %s_rating: %s\n" "$RATING_2_TYPE" "$score_2" >> "$METADATA"
		fi
	fi
}
function get-season-infos () {
	override_id=""
	anilist_backup_id=$anilist_id
	season_check=$(jq --arg anilist_id "$anilist_id" '.[] | select( .anilist_id == $anilist_id ) | .tvdb_season' -r "$SCRIPT_FOLDER/config/tmp/list-animes-id.json")
	first_season=$(echo "$seasons_list" | awk -F "," '{print $1}')
	last_season=$(echo "$seasons_list" | awk -F "," '{print $NF}')
	total_seasons=$(echo "$seasons_list" | awk -F "," '{print NF}')
	valid_anilist_id=$(jq --arg tvdb_id "$tvdb_id" '.[] | select( .tvdb_id == $tvdb_id ) | .anilist_id' -r "$SCRIPT_FOLDER/config/tmp/list-animes-id.json")
	if awk -F"\t" '{print $2}' "$SCRIPT_FOLDER/config/$OVERRIDE" | grep -q -w "$anilist_backup_id" && [[ $last_season -eq 1 ]]
	then
		valid_anilist_id=1
		override_id=$anilist_backup_id
	fi
	if [[ "$first_season" -eq 0 ]]
	then
		total_seasons=$((total_seasons - 1))
	fi
	if [ -n "$valid_anilist_id" ] && [[ $season_check != -1 ]]
	then
		total_1_score=0
		total_2_score=0
		score_1_season=0
		score_2_season=0
		score_1_no_rating_seasons=0
		score_2_no_rating_seasons=0
		season_loop=0
		anime_season=""
		award_check=""
		cr_awards=""
		printf "    seasons:\n" >> "$METADATA"
		IFS=","
		for season_number in $seasons_list
		do
			if [[ $season_number -eq 0 ]]
			then
				printf "      0:\n        label.remove: Score\n" >> "$METADATA"
			else
				season_loop=1
				anilist_ids=$(jq --arg tvdb_id "$tvdb_id" --arg season_number "$season_number" '[.[] | select( .tvdb_id == $tvdb_id ) | select( .tvdb_season == $season_number )] | sort_by(.tvdb_epoffset) | .[].anilist_id' -r "$SCRIPT_FOLDER/config/tmp/list-animes-id.json" | paste -s -d, -)
				if [ -n "$override_id" ] && [[ $season_number -eq 1 ]]
				then
					anilist_ids=$anilist_backup_id
				fi
				cours_count_total=$(printf %s "$anilist_ids" | awk -F "," '{print NF}')
				total_1_cours_score=0
				total_2_cours_score=0
				score_1_no_rating_cours=0
				score_2_no_rating_cours=0
				cours_count=0
				cour_status=""
				all_cours_anime_season=""
				season_userlist_type_add=""
				seasons_userlist_type_remove=""
				IFS=','
				for anilist_id in $anilist_ids
				do
					((cours_count++))
					if [[ -n "$anilist_id" ]]
					then
						get-anilist-infos
						if jq '.data.Media.status' -r "$SCRIPT_FOLDER/config/data/anilist-$anilist_id.json" | grep -q -w "NOT_YET_RELEASED"
						then
							((score_1_no_rating_cours++))
							((score_2_no_rating_cours++))
							continue
						fi
						if { [[ $ANILIST_LISTS_LEVEL == "season" ]] || [[ $ANILIST_LISTS_LEVEL == "both" ]]; } && [[ $ANILIST_LISTS == "Yes" ]]
						then
							for userlist_type in Completed Watching Dropped Paused Planning
							do
								if grep -q -w "$anilist_id" "$SCRIPT_FOLDER/config/data/anilist-$ANILIST_USERNAME-$userlist_type.tsv"
								then
									userlist_type_count=$(printf %s "$season_userlist_type_add" | awk -F "," '{print NF}')
									if [[ $userlist_type_count -gt 1 ]]
									then
										season_userlist_type_add=$(printf "%s,%s" "$season_userlist_type_add" "$userlist_type")
									else
										season_userlist_type_add="$userlist_type"
									fi
								fi
							done
						fi
						get-cour-rating-1
						get-cour-rating-2
						if [[ $ANIME_AWARDS == "Yes" ]]
						then
							get-animes-award
						fi
						if [[ $SEASON_YEAR == "Yes" ]]
						then
							get-animes-season-year
							if [[ $cours_count -gt 1 ]]
							then
								all_cours_anime_season=$(printf "%s,%s" "$anime_season" "$all_cours_anime_season")
							else
								all_cours_anime_season=$anime_season
							fi
						fi
					else
						printf "%s\t\t - Missing Anilist ID for tvdb : %s - Season : %s cour : %s / %s\n" "$(date +%H:%M:%S)" "$tvdb_id" "$season_number" "$cours_count" "$plex_title" | tee -a "$LOG"
						printf "%s\t\t - Missing Anilist ID for tvdb : %s - Season : %s cour : %s / %s\n" "$(date +%H:%M:%S)" "$tvdb_id" "$season_number" "$cours_count" "$plex_title" >> "$MATCH_LOG"
						((score_1_no_rating_cours++))
						((score_2_no_rating_cours++))
					fi
					total-cour-rating-1
					total-cour-rating-2
				done
				anime_season=$all_cours_anime_season
				if [[ $RATING_1_SOURCE == "ANILIST" || $RATING_1_SOURCE == "MAL" ]]
				then
					if [[ "$total_1_cours_score" != 0 ]]
					then
						total_1_cours=$((cours_count - score_1_no_rating_cours))
						if [[ "$total_1_cours" != 0 ]]
						then
							score_1_season=$(echo | awk -v v1="$total_1_cours_score" -v v2="$total_1_cours" '{print v1 / v2}')
							score_1_season=$(printf '%.*f\n' 1 "$score_1_season")
						else
							score_1_season=0
							((score_1_no_rating_seasons++))
						fi
					else
						score_1_season=0
						((score_1_no_rating_seasons++))
					fi
				fi
				if [[ $RATING_2_SOURCE == "ANILIST" || $RATING_2_SOURCE == "MAL" ]]
				then
					if [[ "$total_2_cours_score" != 0 ]]
					then
						total_2_cours=$((cours_count - score_2_no_rating_cours))
						if [[ "$total_2_cours" != 0 ]]
						then
							score_2_season=$(echo | awk -v v1="$total_2_cours_score" -v v2="$total_2_cours" '{print v1 / v2}')
							score_2_season=$(printf '%.*f\n' 1 "$score_2_season")
						else
							score_2_season=0
							((score_2_no_rating_seasons++))
						fi
					else
						score_1_season=0
						((score_1_no_rating_seasons++))
					fi
				fi
				cours_count_total=0
				anilist_id=$(jq --arg tvdb_id "$tvdb_id" --arg season_number "$season_number" '.[] | select( .tvdb_id == $tvdb_id ) | select( .tvdb_season == $season_number ) | select( .tvdb_epoffset == "0" ) | .anilist_id' -r "$SCRIPT_FOLDER/config/tmp/list-animes-id.json" | head -n 1)
				if [ -n "$override_id" ] && [[ $season_number -eq 1 ]]
				then
					anilist_id=$anilist_backup_id 
				fi
				if [[ -z "$anilist_id" ]]
				then
					printf "%s\t\t - Missing Anilist ID for tvdb : %s - Season : %s / %s\n" "$(date +%H:%M:%S)" "$tvdb_id" "$season_number" "$plex_title" | tee -a "$LOG"
					printf "%s - Missing Anilist ID for tvdb : %s - Season : %s / %s\n" "$(date +%H:%M:%S)" "$tvdb_id" "$season_number" "$plex_title" >> "$MATCH_LOG"
					((score_1_no_rating_seasons++))
					((score_2_no_rating_seasons++))
				else
					printf "      %s:\n" "$season_number"  >> "$METADATA"
					romaji_title=$(get-romaji-title)
					english_title=$(get-english-title)
					if [ "$english_title" == "null" ]
					then
						english_title=$romaji_title
					fi
					if [[ $ALLOW_RENAMING == "Yes" && $RENAME_SEASONS == "Yes" ]]
					then
						if [[ $MAIN_TITLE_ENG == "Yes" ]]
						then
						printf "        title: |-\n          %s\n" "$english_title" >> "$METADATA"
						else
						printf "        title: |-\n          %s\n" "$romaji_title" >> "$METADATA"
						fi
					fi
					season_label_add=""
					season_label_remove=""
					if [[ -n "$cr_awards" ]]
					then
						if [[ -n "$season_label_add" ]]
						then
							season_label_add=$(printf "%s,AA Winner" "$season_label_add")
						else
							season_label_add="AA Winner"
						fi
					fi
					if { [[ $ANILIST_LISTS_LEVEL == "season" ]] || [[ $ANILIST_LISTS_LEVEL == "both" ]]; } && [[ $ANILIST_LISTS == "Yes" ]]
					then
						seasons_userlist_type_remove="Completed,Watching,Dropped,Paused,Planning"
						userlist_type_count=$(printf %s "$season_userlist_type_add" | awk -F "," '{print NF}')
						if [[ -n $season_userlist_type_add ]] && [[ $userlist_type_count -gt 0 ]]
						then
							IFS=","
							for userlist_type in $season_userlist_type_add
							do
								seasons_userlist_type_remove=$(printf "%s" "$seasons_userlist_type_remove" | sed s/"$userlist_type"// | sed 's/^,//' | sed 's/,,/,/g')
							done
						fi
						if [[ -n "$season_userlist_type_add" ]]
						then
							if [[ -n "$season_label_add" ]]
							then
								season_label_add=$(printf "%s,%s" "$season_label_add" "$season_userlist_type_add")
							else
								season_label_add="$season_userlist_type_add"
							fi
						fi
						if [[ -n "$seasons_userlist_type_remove" ]]
						then
							if [[ -n "$season_label_remove" ]]
							then
								season_label_remove=$(printf "%s,%s" "$season_label_remove" "$seasons_userlist_type_remove")
							else
								season_label_remove="$seasons_userlist_type_remove"
							fi
						fi
					fi
					if [[ -n "$anime_season" ]]
					then
						if [[ -n "$season_label_add" ]]
						then
							season_label_add=$(printf "%s,%s" "$season_label_add" "$anime_season")
						else
							season_label_add="$anime_season"
						fi
					fi
					if [[ -n "$season_label_add" ]]
					then
						if [[ $last_season -eq 1 ]]
						then
							if [[ $IGNORE_S1_ONLY_RATING == "Yes" ]]
							then
								printf "        label: %s\n" "$season_label_add" >> "$METADATA"
							else
								printf "        label: Score,%s\n" "$season_label_add" >> "$METADATA"
							fi
						else
							printf "        label: Score,%s\n" "$season_label_add" >> "$METADATA"
						fi
					else
						if [[ $last_season -eq 1 ]]
						then
							if [[ $IGNORE_S1_ONLY_RATING != "Yes" ]]
							then
								printf "        label: Score\n" >> "$METADATA"
							fi
						fi
					fi
					if [[ -n "$season_label_remove" ]]
					then
						if [[ $last_season -eq 1 ]]
						then
							if [[ $IGNORE_S1_ONLY_RATING == "Yes" ]]
							then
								printf "        label.remove: Score,%s\n" "$season_label_remove" >> "$METADATA"
							else
								printf "        label.remove: %s\n" "$season_label_remove" >> "$METADATA"
							fi
						else
							printf "        label.remove: %s\n" "$season_label_remove" >> "$METADATA"
						fi
					else
						if [[ $last_season -eq 1 ]]
						then
							if [[ $IGNORE_S1_ONLY_RATING == "Yes" ]]
							then
							printf "        label.remove: Score\n" >> "$METADATA"
							fi
						fi
					fi
					if [[ $last_season -eq 1 ]]
					then
						if [[ $IGNORE_S1_ONLY_RATING != "Yes" ]]
						then
						printf "        user_rating: %s\n" "$score_1_season" >> "$METADATA"
						fi
					else
						printf "        user_rating: %s\n" "$score_1_season" >> "$METADATA"
					fi
					total-rating-1
					total-rating-2
					get-season-poster
				fi
			fi
		done
		season_loop=0
		if [[ $RATING_1_SOURCE == "ANILIST" || $RATING_1_SOURCE == "MAL" ]]
		then
			if [[ "$total_1_score" != 0 ]]
			then
				total_1_seasons=$((total_seasons - score_1_no_rating_seasons))
				if [[ "$total_1_seasons" != 0 ]]
				then
					score_1=$(echo | awk -v v1="$total_1_score" -v v2="$total_1_seasons" '{print v1 / v2}')
					score_1=$(printf '%.*f\n' 1 "$score_1")
				else
					score_1=0
				fi
			else
				score_1=0
			fi
		fi
		if [[ $RATING_2_SOURCE == "ANILIST" || $RATING_2_SOURCE == "MAL" ]]
		then
			if [[ "$total_2_score" != 0 ]]
			then
				total_2_seasons=$((total_seasons - score_2_no_rating_seasons))
				if [[ "$total_2_seasons" != 0 ]]
				then
					score_2=$(echo | awk -v v1="$total_2_score" -v v2="$total_2_seasons" '{print v1 / v2}')
					score_2=$(printf '%.*f\n' 1 "$score_2")
				else
					score_2=0
				fi
			else
				score_2=0
			fi
		fi
	else
		if [[ $RATING_1_SOURCE == "ANILIST" || $RATING_1_SOURCE == "MAL" ]]
		then
			if [[ $RATING_1_SOURCE == "ANILIST" ]]
			then
				get-score
				score_1=$anime_score
			else
				get-mal-score
				score_1=$anime_score
			fi
		fi
		if [[ "$score_1" != 0 ]]
		then
			score_1=$(printf '%.*f\n' 1 "$score_1")
		fi
		if [[ $RATING_2_SOURCE == "ANILIST" || $RATING_2_SOURCE == "MAL" ]]
		then
			if [[ $RATING_2_SOURCE == "ANILIST" ]]
			then
				get-score
				score_2=$anime_score
			else
				get-mal-score
				score_2=$anime_score
			fi
		fi
		if [[ "$score_2" != 0 ]]
		then
			score_2=$(printf '%.*f\n' 1 "$score_2")
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
	if [ "$native_title" == "null" ]
	then
		native_title=$romaji_title
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
	if [[ $DISABLE_TAGS != "Yes" ]]
	then
		anime_tags=$(get-tags)
		if [[ "$ADD_ANIME_TAG" == "No" ]]
		then
			printf "    genre.sync: %s\n" "$anime_tags" >> "$METADATA"
		else
			printf "    genre.sync: Anime,%s\n" "$anime_tags" >> "$METADATA"
		fi
	fi
	get-studios
	if [[ -n "$studio" ]]
	then
		printf "    studio: %s\n" "$studio" >> "$METADATA"
	fi
	get-poster
	if [[ $media_type == "animes" ]]
	then
		if [[ $IGNORE_SEASONS == "Yes" ]] || [[ $override_seasons_ignore == "yes" ]]
		then
			get-rating-1
			get-rating-2
		else
			get-season-infos
			check-rating-1-valid
			check-rating-2-valid
		fi
	else
		get-rating-1
		get-rating-2
	fi
	label_add=""
	label_remove=""
	if [[ $media_type == "animes" ]]
	then
		printf "%s\t\t - Writing airing status\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
		if awk -F"\t" '{print "\""$1"\":"}' "$SCRIPT_FOLDER/config/data/ongoing.tsv" | grep -q -w "$tvdb_id"
		then
			label_add="Airing"
			label_remove="Planned,Ended"
			printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
		else
			get-airing-status
			if [[ $airing_status == Planned ]]
			then
				label_add="Planned"
				label_remove="Airing,Ended"
				printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			else
				label_add="Ended"
				label_remove="Planned,Airing"
				printf "%s\t\t - Done\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
			fi
		fi
	fi
	if [[ -n $cr_awards ]]
	then
		if [[ -n "$label_add" ]]
		then
			label_add=$(printf "AA Winner,%s" "$label_add")
		else
			label_add="AA Winner"
		fi
	else
		get-animes-award
		if [[ -n $cr_awards ]]
		then
			if [[ -n "$label_add" ]]
			then
				label_add=$(printf "AA Winner,%s" "$label_add")
			else
				label_add="AA Winner"
			fi
		fi
	fi
	if { [[ $ANILIST_LISTS_LEVEL == "show" ]] || [[ $ANILIST_LISTS_LEVEL == "both" ]]; } && [[ $ANILIST_LISTS == "Yes" ]]
	then
		all_anilist_ids=""
		userlist_type_add=""
		userlist_type_remove="Completed,Watching,Dropped,Paused,Planning"
		for userlist_type in Completed Watching Dropped Paused Planning
		do
			if [[ $media_type == "animes" ]]
			then
				all_anilist_ids=$(jq --arg tvdb_id "$tvdb_id" '.[] | select( .tvdb_id == $tvdb_id ) | .anilist_id' -r "$SCRIPT_FOLDER/config/tmp/list-animes-id.json" | paste -s -d, - | sed 's/,/\\|/g')
			else
				all_anilist_ids=$anilist_id
			fi
			if grep -q -w "$all_anilist_ids" "$SCRIPT_FOLDER/config/data/anilist-$ANILIST_USERNAME-$userlist_type.tsv"
			then
				userlist_type_count=$(printf %s "$userlist_type_add" | awk -F "," '{print NF}')
				if [[ $userlist_type_count -gt 1 ]]
				then
					userlist_type_add=$(printf "%s,%s" "$userlist_type_add" "$userlist_type")
				else
					userlist_type_add=$userlist_type
				fi
				userlist_type_remove=$(printf "%s" "$userlist_type_remove" | sed s/"$userlist_type"// | sed 's/^,//' | sed 's/,,/,/g')
			fi
		done
		if [[ -n "$userlist_type_add" ]]
		then
			if [[ -n "$label_add" ]]
			then
				label_add=$(printf "%s,%s" "$label_add" "$userlist_type_add")
			else
				label_add="$userlist_type_add"
			fi
		fi
		if [[ -n "$userlist_type_remove" ]]
		then
			if [[ -n "$label_remove" ]]
			then
				label_remove=$(printf "%s,%s" "$label_remove" "$userlist_type_remove")
			else
				label_remove="$userlist_type_remove"
			fi
		fi
	fi
	if [[ -n "$label_add" ]]
	then
		printf "    label: %s\n" "$label_add" >> "$METADATA"
	fi
	if [[ -n "$label_remove" ]]
	then
		printf "    label.remove: %s\n" "$label_remove" >> "$METADATA"
	fi
	tvdb_id=""
	imdb_id=""
	anilist_id=""
	mal_id=""
	override_seasons_ignore=""
	award_check=""
	cr_awards=""
}