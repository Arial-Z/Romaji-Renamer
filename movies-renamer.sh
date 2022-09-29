#!/bin/bash

SCRIPT_FOLDER=$(dirname $(readlink -f $0))
source $SCRIPT_FOLDER/config.conf
LOG=$LOG_FOLDER/movies/$(date +%Y.%m.%d).log
MATCH_LOG=$LOG_FOLDER/movies/missing-ID-link.log
ADDED_LOG=$LOG_FOLDER/movies/added.log
DELETED_LOG=$LOG_FOLDER/movies/deleted.log

# function
function get-mal-id () {
imdb_jq=$(echo $imdb_id | awk '{print "\""$1"\""}' )
jq ".[] | select( .imdb_id == ${imdb_jq} )" -r $SCRIPT_FOLDER/tmp/pmm_anime_ids.json | jq .mal_id | sort -n | head -1
}
function get-mal-infos () {
if [ ! -f $SCRIPT_FOLDER/data/movies/$mal_id.json ]
then
	sleep 0.5
	curl "https://api.jikan.moe/v4/anime/$mal_id" > $SCRIPT_FOLDER/data/movies/$mal_id.json 
	sleep 1.5
fi
}
function get-mal-title () {
jq .data.title -r $SCRIPT_FOLDER/data/movies/$mal_id.json
}
function get-mal-rating () {
jq .data.score -r $SCRIPT_FOLDER/data/movies/$mal_id.json
}
function get-mal-poster () {
if [ ! -f $SCRIPT_FOLDER/posters/$mal_id.jpg ]
then
sleep 0.5
	mal_poster_url=$(jq .data.images.jpg.large_image_url -r $SCRIPT_FOLDER/data/movies/$mal_id.json)
	curl "$mal_poster_url" > $SCRIPT_FOLDER/posters/$mal_id.jpg
sleep 1.5
fi
}
function get-mal-tags () {
(jq '.data.genres  | .[] | .name' -r $SCRIPT_FOLDER/data/movies/$mal_id.json && jq '.data.themes  | .[] | .name' -r $SCRIPT_FOLDER/data/movies/$mal_id.json  && jq '.data.demographics  | .[] | .name' -r $SCRIPT_FOLDER/data/movies/$mal_id.json) | awk '{print $0}' | paste -s -d, -
}
function get-mal-studios() {
jq '.data.studios[0] | [.name]| @tsv' -r $SCRIPT_FOLDER/data/movies/$mal_id.json
}

# download pmm animes mapping and check if files and folder exist
if [ ! -f $movies_titles ]
then
        echo "metadata:" > $movies_titles
fi
if [ ! -d $SCRIPT_FOLDER/data ]											#check if exist and create folder for json data
then
        mkdir $SCRIPT_FOLDER/data
fi
if [ ! -d $SCRIPT_FOLDER/data/movies ]	
then
	mkdir $SCRIPT_FOLDER/data/movies
else
	find $SCRIPT_FOLDER/data/movies/* -mtime +2 -exec rm {} \;						#delete json data if older than 2 days
fi
if [ ! -d $SCRIPT_FOLDER/posters ]
then
        mkdir $SCRIPT_FOLDER/posters
else
	find $SCRIPT_FOLDER/posters/* -mtime +30 -exec rm {} \;
fi
if [ ! -d $SCRIPT_FOLDER/ID ]
then
	mkdir $SCRIPT_FOLDER/ID
	touch $SCRIPT_FOLDER/ID/movies.tsv
elif [ ! -f $SCRIPT_FOLDER/ID/movies.tsv ]
then
	touch $SCRIPT_FOLDER/ID/movies.tsv	
fi
if [ ! -d $SCRIPT_FOLDER/tmp ]
then
        mkdir $SCRIPT_FOLDER/tmp
else
	rm $SCRIPT_FOLDER/tmp/*
fi
if [ ! -d $LOG_FOLDER ]
then
	mkdir $LOG_FOLDER
fi
if [ ! -d $LOG_FOLDER/movies ]
then
	mkdir $LOG_FOLDER/movies
fi

# Download anime mapping json data
curl "https://raw.githubusercontent.com/meisnate12/Plex-Meta-Manager-Anime-IDs/master/pmm_anime_ids.json" > $SCRIPT_FOLDER/tmp/pmm_anime_ids.json

# create pmm meta.log
rm $PMM_FOLDER/config/temp-movies.cache
$PMM_FOLDER/pmm-venv/bin/python3 $PMM_FOLDER/plex_meta_manager.py -r --config $PMM_FOLDER/config/temp-movies.yml
mv $PMM_FOLDER/config/logs/meta.log $SCRIPT_FOLDER/tmp

# create clean list-movies.tsv (imdb_id | title_plex) from meta.log
line_start=$(grep -n "Mapping Animes Films Library" $SCRIPT_FOLDER/tmp/meta.log | cut -d : -f 1)
line_end=$(grep -n -m1 "Animes Films Library Operations" $SCRIPT_FOLDER/tmp/meta.log | cut -d : -f 1)
head -n $line_end $SCRIPT_FOLDER/tmp/meta.log | tail -n $(( $line_end - $line_start - 1 )) | head -n -5 > $SCRIPT_FOLDER/tmp/cleanlog-movies.txt
awk -F"|" '{ OFS = "\t" } ; { gsub(/ /,"",$6) } ; { print  substr($6,8),substr($7,2,length($7)-2) }' $SCRIPT_FOLDER/tmp/cleanlog-movies.txt > $SCRIPT_FOLDER/tmp/list-movies.tsv

# Cleanup ID/movies.tsv
printf "\nCleaning ID/animes.tsv\n"  >> $LOG 
line=1
while IFS=$'\t' read -r imdb_id mal_id title_mal title_plex
do
        if ! awk -F"\t" '{print $1}' $SCRIPT_FOLDER/tmp/list-movies.tsv | grep -w $imdb_id
        then
                sed -i "${line}d" $SCRIPT_FOLDER/ID/movies.tsv
                echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_mal removed from ID/movies.tsv"  >> $DELETED_LOG
        else
                ((line++))
        fi
done < $SCRIPT_FOLDER/ID/movies.tsv
printf "ID/movies.tsv cleanup finished\n"  >> $LOG

# create ID/movies.tsv ( imdb_id | mal_id | title_mal | title_plex )
while IFS=$'\t' read -r imdb_id mal_id title_mal
do
	if ! awk -F"\t" '{print $1}' $SCRIPT_FOLDER/ID/movies.tsv | grep "\<$imdb_id\>"
	then
		line=$(grep -n "\<$imdb_id\>" $SCRIPT_FOLDER/tmp/list-movies.tsv | cut -d : -f 1)
		title_plex=$(sed -n "${line}p" $SCRIPT_FOLDER/tmp/list-movies.tsv | awk -F"\t" '{print $2}')
		printf "$imdb_id\t$mal_id\t$title_mal\t$title_plex\n" >> $SCRIPT_FOLDER/ID/movies.tsv
		echo "$(date +%Y.%m.%d" - "%H:%M:%S) - override found for : $title_mal / $title_plex" >> $LOG
	fi
done < $SCRIPT_FOLDER/override-ID-movies.tsv
while IFS=$'\t' read -r imdb_id title_plex
do
	if ! awk -F"\t" '{print $1}' $SCRIPT_FOLDER/ID/movies.tsv | grep "\<$imdb_id\>"
	then
		mal_id=$(get-mal-id)
		if [[ "$mal_title" == 'null' ]] || [[ "$mal_id" == 'null' ]] || [[ "${#mal_id}" == '0' ]]
		then
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - invalid MAL ID for : tvdb : $imdb_id / $title_plex" >> $MATCH_LOG
			continue
		fi
		get-mal-infos
		title_mal=$(get-mal-title)
		printf "$imdb_id\t$mal_id\t$title_mal\t$title_plex\n" >> $SCRIPT_FOLDER/ID/movies.tsv
		echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_mal / $title_plex added to ID/movies.tsv" >> $LOG
	fi
done < $SCRIPT_FOLDER/tmp/list-movies.tsv

# write PMM metadata file from ID/movies.tsv and jikan API
while IFS=$'\t' read -r imdb_id mal_id title_mal title_plex
do
	if grep "\"$title_mal\":" $movies_titles
	then
		get-mal-infos
		get-mal-poster
		sorttitleline=$(grep -n "sort_title: \"$title_mal\"" $movies_titles | cut -d : -f 1)
		ratingline=$((sorttitleline+1))
		echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_mal metadata updated :" >> $LOG
		if sed -n "${ratingline}p" $movies_titles | grep "audience_rating:"
		then
			sed -i "${ratingline}d" $movies_titles
			score_mal=$(get-mal-rating)
			sed -i "${ratingline}i\    audience_rating: ${score_mal}" $movies_titles
			printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tscore : $score_mal\n" >> $LOG
		fi
		tagsline=$((sorttitleline+2))
		if sed -n "${tagsline}p" $movies_titles | grep "genre.sync:"
		then
			sed -i "${tagsline}d" $movies_titles
			mal_tags=$(get-mal-tags)
			sed -i "${tagsline}i\    genre.sync: Anime,${mal_tags}" $movies_titles
			printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\ttags updated : $mal_tags\n" >> $LOG
		fi
	else
		get-mal-infos
		echo "  \"$title_mal\":" >> $movies_titles
                echo "    alt_title: \"$title_plex\"" >> $movies_titles
                echo "    sort_title: \"$title_mal\"" >> $movies_titles
		echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_mal / $title_plex added to metadata :" >> $LOG
		score_mal=$(get-mal-rating)
                echo "    audience_rating: $score_mal" >> $movies_titles
		printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tscore : $score_mal\n" >> $LOG
		mal_tags=$(get-mal-tags)
		echo "    genre.sync: Anime,${mal_tags}"  >> $movies_titles
		printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\ttags : $mal_tags\n" >> $LOG
		mal_studios=$(get-mal-studios)
		echo "    studio: ${mal_studios}"  >> $movies_titles
		printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tstudio : $mal_studios" >> $LOG
		get-mal-poster
		echo "    file_poster: $SCRIPT_FOLDER/posters/${mal_id}.jpg" >> $movies_titles
		printf "$(date +%Y.%m.%d" - "%H:%M:%S)\t\tPoster added\n" >> $LOG
		echo "$(date +%Y.%m.%d" - "%H:%M:%S) - added to metadata :\n\t$title_mal / $title_plex" >> $ADDED_LOG
	fi
done < $SCRIPT_FOLDER/ID/movies.tsv

# Remove from metadata deleted animes
printf "\nRunning metadata cleanup\n"  >> $LOG 
sed '/sort_title:/!d'  $movies_titles > $SCRIPT_FOLDER/tmp/movies-title-metadata.txt
line=1
while read -r title_metadata
do
        if ! awk -F"\t" '{print "sort_title: \""$3"\""}' $SCRIPT_FOLDER/ID/movies.tsv | grep "${title_metadata}"
        then
                lineprevious=$((line - 1))
                previoustitle=$(sed -n "${lineprevious}p" $SCRIPT_FOLDER/tmp/movies-title-metadata.txt)
                lineprevioustitle=$(grep -n "${previoustitle}" $animes_titles | cut -d : -f 1)
                linedelstart=$((lineprevioustitle + 6))
                linedelend=$((lineprevioustitle + 13))
                sed -i "${linedelstart},${linedelend}d" $movies_titles
                title=$(echo $title_metadata | cut -c 14- | sed 's/.$//')
                echo "$(date +%Y.%m.%d" - "%H:%M:%S) - removed from metadata :\n\t$title"  >> $DELETED_LOG
        fi
        ((line++))
done < $SCRIPT_FOLDER/tmp/movies-title-metadata.txt
printf "metadata cleanup finished\n"  >> $LOG