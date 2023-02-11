#!/bin/bash

SCRIPT_FOLDER=$(dirname $(readlink -f $0))
media_type=movies
source $SCRIPT_FOLDER/.env
source $SCRIPT_FOLDER/functions.sh
METADATA=$METADATA_MOVIES
OVERRIDE=override-ID-$media_type.tsv

# check if files and folder exist
echo "metadata:" > $METADATA
if [ ! -d $SCRIPT_FOLDER/data ]                                                                                 #check if exist and create folder for json data
then
	mkdir $SCRIPT_FOLDER/data
else
	find $SCRIPT_FOLDER/data/* -mmin +2880 -exec rm {} \;                           #delete json data if older than 2 days
fi
if [ ! -d $POSTERS_FOLDER ]
then
	mkdir $POSTERS_FOLDER
else
	find $ASSET_FOLDER/$asset_name/* -mtime +30 -exec rm {} \;
fi
if [ ! -d $SCRIPT_FOLDER/ID ]
then
	mkdir $SCRIPT_FOLDER/ID
	touch $SCRIPT_FOLDER/ID/movies.tsv
elif [ ! -f $SCRIPT_FOLDER/ID/movies.tsv ]
then
	touch $SCRIPT_FOLDER/ID/movies.tsv
else
	rm $SCRIPT_FOLDER/ID/movies.tsv
	touch $SCRIPT_FOLDER/ID/movies.tsv
fi
if [ ! -d $LOG_FOLDER ]
then
	mkdir $LOG_FOLDER
fi

# Download anime mapping json data
download-anime-id-mapping


# export movies list from plex
python $SCRIPT_FOLDER/plex_movies_export.py

# create ID/movies.tsv ( imdb_id | mal_id | title_anime | title_plex )
while IFS=$'\t' read -r imdb_id mal_id title_anime studio                                                                       # First add the override animes to the ID file
do
	if ! awk -F"\t" '{print $1}' $SCRIPT_FOLDER/ID/movies.tsv | grep -w  $imdb_id
	then
		if awk -F"\t" '{print $1}' $SCRIPT_FOLDER/tmp/plex_movies_export.tsv | grep -w  $imdb_id
		then
			line=$(grep -w -n $imdb_id $SCRIPT_FOLDER/tmp/plex_movies_export.tsv | cut -d : -f 1)
			title_plex=$(sed -n "${line}p" $SCRIPT_FOLDER/tmp/plex_movies_export.tsv | awk -F"\t" '{print $2}')
			asset_name=$(sed -n "${line}p" $SCRIPT_FOLDER/tmp/plex_movies_export.tsv | awk -F"\t" '{print $3}')
			printf "$imdb_id\t$mal_id\t$title_anime\t$title_plex\t$asset_name\n" >> $SCRIPT_FOLDER/ID/movies.tsv
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - override found for : $title_anime / $title_plex" >> $LOG
		fi
	fi
done < $SCRIPT_FOLDER/override-ID-movies.tsv
while IFS=$'\t' read -r imdb_id title_plex asset_name                                                                                      # then get the other ID from the ID mapping and download json data
do
	if ! awk -F"\t" '{print $1}' $SCRIPT_FOLDER/ID/movies.tsv | grep -w  $imdb_id
	then
		mal_id=$(get-mal-id-from-imdb-id)
		if [[ "$mal_id" == 'null' ]] || [[ "${#mal_id}" == '0' ]]                                               # Ignore anime with no tvdb to mal id conversion show in the error log you need to add them by hand in override
		then
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - invalid MAL ID for : imdb : $imdb_id / $title_plex" >> $MATCH_LOG
			continue
		fi
		anilist_id=$(get-anilist-id)
		if [[ "$anilist_id" == 'null' ]] || [[ "${#anilist_id}" == '0' ]]                               # Ignore anime with no tvdb to mal id conversion show in the error log you need to add them by hand in override
		then
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - invalid Anilist ID for : imdb : $imdb_id / $title_plex" >> $MATCH_LOG
			continue
		fi
		get-mal-infos
		get-anilist-infos
		title_anime=$(get-anilist-title)
		printf "$imdb_id\t$mal_id\t$title_anime\t$title_plex\t$asset_name\n" >> $SCRIPT_FOLDER/ID/movies.tsv
		echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_anime / $title_plex added to ID/movies.tsv" >> $LOG
	fi
done < $SCRIPT_FOLDER/tmp/plex_movies_export.tsv

# write PMM metadata file from ID/movies.tsv and jikan API
while IFS=$'\t' read -r imdb_id mal_id title_anime title_plex asset_name
do
	write-metadata
done < $SCRIPT_FOLDER/ID/movies.tsv
exit 0
