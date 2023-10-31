#!/bin/bash

RUN_ANIMES_SCRIPTS=0
RUN_MOVIES_SCRIPTS=0
export LC_ALL=C.UTF-8
SCRIPT_FOLDER=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_FOLDER/.env"

if [[ $RUN_ANIMES_SCRIPTS -eq 1 ]]
then
	bash "$SCRIPT_FOLDER/animes-renamer.sh"
fi
if [[ $RUN_MOVIES_SCRIPTS -eq 1 ]]
then
	bash "$SCRIPT_FOLDER/movies-renamer.sh"
fi