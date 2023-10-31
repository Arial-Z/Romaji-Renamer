#!/bin/bash

RUN_ANIMES_SCRIPTS=0
RUN_MOVIES_SCRIPTS=0
export LC_ALL=C.UTF-8
SCRIPT_FOLDER=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
LOG=$LOG_FOLDER/${media_type}_$(date +%Y.%m.%d).log
if [ -f "$SCRIPT_FOLDER/config/.env" ]
then
	source "$SCRIPT_FOLDER/config/.env"
	if [[ $RUN_ANIMES_SCRIPTS == "Yes" ]]
	then
		bash "$SCRIPT_FOLDER/animes-renamer.sh"
	fi
	if [[ $RUN_MOVIES_SCRIPTS == "Yes" ]]
	then
		bash "$SCRIPT_FOLDER/movies-renamer.sh"
	fi
else
	printf "%s - Error no config found\n" "$(date +%H:%M:%S)" | tee -a "$LOG"
fi