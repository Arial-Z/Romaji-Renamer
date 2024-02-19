#!/bin/bash

RUN_ANIMES_SCRIPT=0
RUN_MOVIES_SCRIPT=0
RUN_SEASONAL_SCRIPT=0
SCRIPT_FOLDER=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_FOLDER/config/.env"
printf "PRR v1.23+\n" | tee -a "$LOG"
locale=$(locale -a | grep -i "utf" | head -n 1)
if [ -z "$locale" ]
then
	printf "%s - Error no utf8 locale installed\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
	exit 1
else
	export LC_ALL="$locale"
fi
if [ ! -d "$SCRIPT_FOLDER/config" ]
then
	printf "%s - Error config folder missing\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
	exit 1
fi
if [ ! -f "$SCRIPT_FOLDER/config/default.env" ]
then
curl -s "https://raw.githubusercontent.com/Arial-Z/Plex-Romaji-Renamer/dev/config/default.env" > "$SCRIPT_FOLDER/config/default.env"
fi
if [ ! -f "$SCRIPT_FOLDER/config/override-ID-animes.example.tsv" ]
then
curl -s "https://raw.githubusercontent.com/Arial-Z/Plex-Romaji-Renamer/dev/config/override-ID-animes.example.tsv" > "$SCRIPT_FOLDER/config/override-ID-animes.example.tsv"
fi
if [ ! -f "$SCRIPT_FOLDER/config/override-ID-movies.example.tsv" ]
then
curl -s "https://raw.githubusercontent.com/Arial-Z/Plex-Romaji-Renamer/dev/config/override-ID-movies.example.tsv" > "$SCRIPT_FOLDER/config/override-ID-movies.example.tsv"
fi
# sleep infinity
if [ -f "$SCRIPT_FOLDER/config/.env" ]
then
	source "$SCRIPT_FOLDER/config/.env"
	if [[ $RUN_ANIMES_SCRIPT == "Yes" ]]
	then
		bash "$SCRIPT_FOLDER/animes-renamer.sh"
	fi
	if [[ $RUN_MOVIES_SCRIPT == "Yes" ]]
	then
		bash "$SCRIPT_FOLDER/movies-renamer.sh"
	fi
		if [[ $RUN_SEASONAL_SCRIPT == "Yes" ]]
	then
		bash "$SCRIPT_FOLDER/seasonal-animes-download.sh"
	fi
else
	printf "%s - Error no config found\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
	exit 1
fi