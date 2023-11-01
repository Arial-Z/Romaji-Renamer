#!/bin/bash

RUN_ANIMES_SCRIPT=0
RUN_MOVIES_SCRIPT=0
RUN_SEASONAL_SCRIPT=0
export LC_ALL=C.UTF-8
SCRIPT_FOLDER=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
LOG=$LOG_FOLDER/${media_type}_$(date +%Y.%m.%d).log
if [ ! -f "$SCRIPT_FOLDER/config/default.env" ]
then
cp "$SCRIPT_FOLDER/default.env" "$SCRIPT_FOLDER/config/default.env"
fi
if [ ! -f "$SCRIPT_FOLDER/config/override-ID-animes.example.tsv" ]
then
cp "$SCRIPT_FOLDER/override-ID-animes.example.tsv" "$SCRIPT_FOLDER/config/override-ID-animes.example.tsv"
fi
if [ ! -f "$SCRIPT_FOLDER/config/override-ID-movies.example.tsv" ]
then
cp "$SCRIPT_FOLDER/override-ID-movies.example.tsv" "$SCRIPT_FOLDER/config/override-ID-movies.example.tsv"
fi
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
fi