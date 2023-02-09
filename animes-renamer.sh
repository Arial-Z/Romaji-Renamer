#!/bin/bash

SCRIPT_FOLDER=$(dirname $(readlink -f $0))
media_type=animes
source $SCRIPT_FOLDER/config.conf
source $SCRIPT_FOLDER/functions.sh
METADATA=$METADATA_ANIMES
OVERRIDE=override-ID-$media_type.tsv

#check temp folder + run of pmm for ID
pmm-id-run

# check if files and folder exist
echo "metadata:" > $METADATA
if [ ! -d $SCRIPT_FOLDER/data ]										#check if exist and create folder for json data
then
	mkdir $SCRIPT_FOLDER/data
else
	find $SCRIPT_FOLDER/data/* -mmin +2880 -exec rm {} \;					#delete json data if older than 2 days
	find $SCRIPT_FOLDER/data/ongoing.tsv -mmin +720 -exec rm {} \;			#delete ongoing if older than 12h
fi
if [ ! -d $POSTERS_FOLDER ]											#check if exist and create folder for posters
then
	mkdir $POSTERS_FOLDER
else
	find $POSTERS_FOLDER/* -mtime +30 -exec rm {} \;						#delete posters if older than 30 days
fi
if [ ! -d $SCRIPT_FOLDER/ID ]											#check if exist and create folder and file for ID
then
	mkdir $SCRIPT_FOLDER/ID
	touch $SCRIPT_FOLDER/ID/animes.tsv
elif [ ! -f $SCRIPT_FOLDER/ID/animes.tsv ]
then
	touch $SCRIPT_FOLDER/ID/animes.tsv
else
	rm $SCRIPT_FOLDER/ID/animes.tsv
	touch $SCRIPT_FOLDER/ID/animes.tsv
fi
if [ ! -d $LOG_FOLDER ]
then
	mkdir $LOG_FOLDER
fi

# Download anime mapping json data
download-anime-id-mapping

# create clean list-animes.tsv (tvdb_id	title_plex) from meta.log
line_start=$(grep -n "Mapping "$ANIME_LIBRARY_NAME" Library" $SCRIPT_FOLDER/tmp/meta.log | cut -d : -f 1)
line_end=$(grep -n -m1 "$ANIME_LIBRARY_NAME Library Operations" $SCRIPT_FOLDER/tmp/meta.log | cut -d : -f 1)
head -n $line_end $SCRIPT_FOLDER/tmp/meta.log | tail -n $(( $line_end - $line_start - 1 )) | head -n -5 > $SCRIPT_FOLDER/tmp/cleanlog-animes.txt
awk -F"|" '{ OFS = "\t" } ; { gsub(/ /,"",$5) } ; { print substr($5,8),substr($7,2,length($7)-2) }' $SCRIPT_FOLDER/tmp/cleanlog-animes.txt > $SCRIPT_FOLDER/tmp/list-animes-dirty.tsv
sed 's/^[ \t]*//;s/[ \t]*$//' < $SCRIPT_FOLDER/tmp/list-animes-dirty.tsv > $SCRIPT_FOLDER/tmp/list-animes.tsv

# create ID/animes.tsv from the clean list ( tvdb_id	mal_id	title_anime	title_plex )
while IFS=$'\t' read -r tvdb_id mal_id title_anime studio									# First add the override animes to the ID file
do
	if ! awk -F"\t" '{print $1}' $SCRIPT_FOLDER/ID/animes.tsv | grep -w $tvdb_id
	then
		if awk -F"\t" '{print $1}' $SCRIPT_FOLDER/tmp/list-animes.tsv | grep -w $tvdb_id
		then
			line=$(grep -w -n $tvdb_id $SCRIPT_FOLDER/tmp/list-animes.tsv | cut -d : -f 1)
			title_plex=$(sed -n "${line}p" $SCRIPT_FOLDER/tmp/list-animes.tsv | awk -F"\t" '{print $2}')
			printf "$tvdb_id\t$mal_id\t$title_anime\t$title_plex\n" >> $SCRIPT_FOLDER/ID/animes.tsv
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - override found for : $title_anime / $title_plex" >> $LOG
		fi
	fi
done < $SCRIPT_FOLDER/override-ID-animes.tsv
while IFS=$'\t' read -r tvdb_id title_plex											# then get the other ID from the ID mapping and download json data
do
	if ! awk -F"\t" '{print $1}' $SCRIPT_FOLDER/ID/animes.tsv | grep -w $tvdb_id
	then
		mal_id=$(get-mal-id-from-tvdb-id)
		if [[ "$mal_id" == 'null' ]] || [[ "${#mal_id}" == '0' ]]						# Ignore anime with no mal id
		then
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - invalid MAL ID for : tvdb : $tvdb_id / $title_plex" >> $MATCH_LOG
			continue
		fi
		anilist_id=$(get-anilist-id)
		if [[ "$anilist_id" == 'null' ]] || [[ "${#anilist_id}" == '0' ]]				# Ignore anime with no anilist id
		then
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - invalid Anilist ID for : tvdb : $tvdb_id / $title_plex" >> $MATCH_LOG
			continue
		fi
		get-mal-infos
		get-anilist-infos
		title_anime=$(get-anilist-title)
		printf "$tvdb_id\t$mal_id\t$title_anime\t$title_plex\n" >> $SCRIPT_FOLDER/ID/animes.tsv
		echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_anime / $title_plex added to ID/animes.tsv" >> $LOG
	fi
done < $SCRIPT_FOLDER/tmp/list-animes.tsv

# Create an ongoing list at $SCRIPT_FOLDER/data/ongoing.csv
if [ ! -f $SCRIPT_FOLDER/data/ongoing.tsv ]              								# check if already exist
then
	ongoingpage=0
	while [ $ongoingpage -lt 9 ];													# get the airing list from jikan API max 9 pages (225 animes)
	do
		curl "https://api.jikan.moe/v4/anime?status=airing&page=$ongoingpage&order_by=member&order=desc&genres_exclude=12&min_score=4" > $SCRIPT_FOLDER/tmp/ongoing-tmp.json
		sleep 2
		jq ".data[].mal_id" -r $SCRIPT_FOLDER/tmp/ongoing-tmp.json >> $SCRIPT_FOLDER/tmp/ongoing.tsv				# store the mal ID of the ongoing show
		echo "1"
		if grep "\"has_next_page\":false," $SCRIPT_FOLDER/tmp/ongoing-tmp.json								# stop if page is empty
		then
			break
		fi
		((ongoingpage++))
	done
	while read -r mal_id
	do
		echo "2"
		if awk -F"\t" '{print $2}' $SCRIPT_FOLDER/ID/animes.tsv | grep -w  $mal_id
		then
			printf "$mal_id\n" >> $SCRIPT_FOLDER/data/ongoing.tsv
		else
			tvdb_id=$(get-tvdb-id)																	# convert the mal id to tvdb id (to get the main anime)
			if [[ "$tvdb_id" == 'null' ]] || [[ "${#tvdb_id}" == '0' ]]										# Ignore anime with no mal to tvdb id conversion
			then
				echo "$(date +%Y.%m.%d" - "%H:%M:%S) - Ongoing invalid TVDB ID for : MAL : $mal_id" >> $LOG
				continue
			else
				echo "3"
				if awk -F"\t" '{print $1}' $SCRIPT_FOLDER/ID/animes.tsv | grep -w  $tvdb_id
				then
					echo "4"
					line=$(grep -w -n $tvdb_id $SCRIPT_FOLDER/ID/animes.tsv | cut -d : -f 1)
					mal_id=$(sed -n "${line}p" $SCRIPT_FOLDER/ID/animes.tsv | awk -F"\t" '{print $2}')
					printf "$mal_id\n" >> $SCRIPT_FOLDER/data/ongoing.tsv
				else
					mal_id=$(get-mal-id-from-tvdb-id)
					if [[ "$mal_id" == 'null' ]] || [[ "${#mal_id}" == '0' ]]						# Ignore anime with no tvdb to mal id
					then
						echo "$(date +%Y.%m.%d" - "%H:%M:%S) - Ongoing invalid MAL ID for : TVDB : $tvdb_id" >> $LOG
						continue
					else
						printf "$mal_id\n" >> $SCRIPT_FOLDER/data/ongoing.tsv
					fi
				fi
			fi
		fi
	done < $SCRIPT_FOLDER/tmp/ongoing.tsv
fi

# write PMM metadata file from ID/animes.tsv and jikan API
while IFS=$'\t' read -r tvdb_id mal_id title_anime title_plex
do
	write-metadata
done < $SCRIPT_FOLDER/ID/animes.tsv
exit 0