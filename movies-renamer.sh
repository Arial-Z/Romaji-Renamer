#!/bin/bash

SCRIPT_FOLDER=$(dirname $(readlink -f $0))
source $SCRIPT_FOLDER/config.conf
LOG=$LOG_FOLDER/movies_$(date +%Y.%m.%d).log
ERROR_LOG=$LOG_FOLDER/error.log

# function
function get-mal-id () {
imdb_jq=$(echo $imdb_id | awk '{print "\""$1"\""}' )
jq ".[] | select( .imdb_id == ${imdb_jq} )" -r $SCRIPT_FOLDER/tmp/pmm_anime_ids.json | jq .mal_id | sort -n | head -1
}
function get-mal-infos () {
sleep 0.5
curl "https://api.jikan.moe/v4/anime/$mal_id" > $SCRIPT_FOLDER/data/$mal_id.json 
sleep 1.5
}
function get-mal-title () {
jq .data.title -r $SCRIPT_FOLDER/data/$mal_id.json
}
function get-mal-rating () {
jq .data.score -r $SCRIPT_FOLDER/data/$mal_id.json
}
function get-mal-poster () {
sleep 0.5
mal_poster_url=$(jq .data.images.jpg.large_image_url -r $SCRIPT_FOLDER/data/$mal_id.json)
curl "$mal_poster_url" > $SCRIPT_FOLDER/posters/$mal_id.jpg
sleep 1.5
}
function get-mal-tags () {
(jq '.data.genres  | .[] | .name' -r $SCRIPT_FOLDER/data/$mal_id.json && jq '.data.themes  | .[] | .name' -r $SCRIPT_FOLDER/data/$mal_id.json  && jq '.data.demographics  | .[] | .name' -r $SCRIPT_FOLDER/data/$mal_id.json) | awk '{print $0}' | paste -s -d, -
}

# download pmm animes mapping and check if files and folder exist
if [ ! -f $movies_titles ]
then
        echo "metadata:" > $movies_titles
fi
if [ ! -d $SCRIPT_FOLDER/data ]
then
        mkdir $SCRIPT_FOLDER/data
else
	find $SCRIPT_FOLDER/data/* -mmin +1440 -exec rm {} \;
fi
if [ ! -d $SCRIPT_FOLDER/posters ]
then
        mkdir $SCRIPT_FOLDER/posters
else
	find $SCRIPT_FOLDER/posters/* -mtime +7 -exec rm {} \;
fi
if [ ! -d $SCRIPT_FOLDER/ID ]
then
	mkdir $SCRIPT_FOLDER/ID
	touch $SCRIPT_FOLDER/ID/movies.csv
elif [ ! -f $SCRIPT_FOLDER/ID/movies.csv ]
then
	touch $SCRIPT_FOLDER/ID/movies.csv
fi
if [ ! -d $SCRIPT_FOLDER/tmp ]
then
        mkdir $SCRIPT_FOLDER/tmp
else
	rm $SCRIPT_FOLDER/tmp/*
fi
curl "https://raw.githubusercontent.com/meisnate12/Plex-Meta-Manager-Anime-IDs/master/pmm_anime_ids.json" > $SCRIPT_FOLDER/tmp/pmm_anime_ids.json

# create pmm meta.log
rm $PMM_FOLDER/config/temp-movies.cache
$PMM_FOLDER/pmm-venv/bin/python3 $PMM_FOLDER/plex_meta_manager.py -r --config $PMM_FOLDER/config/temp-movies.yml
mv $PMM_FOLDER/config/logs/meta.log $SCRIPT_FOLDER/tmp

# create clean list-movies.csv (imdb_id | title_plex) from meta.log
line_start=$(grep -n "Mapping Animes Films Library" $SCRIPT_FOLDER/tmp/meta.log | cut -d : -f 1)
line_end=$(grep -n -m1 "Animes Films Library Operations" $SCRIPT_FOLDER/tmp/meta.log | cut -d : -f 1)
head -n $line_end $SCRIPT_FOLDER/tmp/meta.log | tail -n $(( $line_end - $line_start - 1 )) | head -n -5 > $SCRIPT_FOLDER/tmp/cleanlog-movies.txt
awk -F"|" '{ OFS = "|" } ; { gsub(/ /,"",$6) } ; { print  substr($6,8),substr($7,2,length($7)-2) }' $SCRIPT_FOLDER/tmp/cleanlog-movies.txt > $SCRIPT_FOLDER/tmp/list-movies.csv

# create ID/movies.csv ( imdb_id | mal_id | title_mal | title_plex )
while IFS="|" read -r imdb_id title_plex
do
	if ! awk -F"|" '{print $1}' $SCRIPT_FOLDER/ID/movies.csv | grep "^${imdb_id}$"                                                   					# check if not already in ID/movies.csv
	then
		if awk -F"\t" '{print $1}' $SCRIPT_FOLDER/override-ID-movies.tsv | tail -n +2 | grep "^${imdb_id}$"								# check if in override
		then
			overrideline=$(grep -n "^${imdb_id}$" $SCRIPT_FOLDER/override-ID-movies.tsv | cut -d : -f 1)
			mal_id=$(sed -n "${overrideline}p" $SCRIPT_FOLDER/override-ID-movies.tsv | awk -F"\t" '{print $2}')
			title_mal=$(sed -n "${overrideline}p" $SCRIPT_FOLDER/override-ID-movies.tsv | awk -F"\t" '{print $3}')
			get-mal-infos
			echo "$imdb_id|$mal_id|$title_mal|$title_plex" >> $SCRIPT_FOLDER/ID/movies.csv
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - override found for : $title_mal / $title_plex" >> $LOG
		else
			mal_id=$(get-mal-id)
		if [[ "$mal_title" == 'null' ]] || [[ "$mal_id" == 'null' ]] || [[ "${#mal_id}" == '0' ]]
		then
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - invalid MAL ID for : imdb : $imdb_id / $title_plex" >> $ERROR_LOG
		fi
			get-mal-infos
			title_mal=$(get-mal-title)
			echo "$imdb_id|$mal_id|$title_mal|$title_plex" >> $SCRIPT_FOLDER/ID/movies.csv
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_mal / $title_plex added to ID/movies.csv" >> $LOG
		fi
	fi
done < $SCRIPT_FOLDER/tmp/list-movies.csv

# write PMM metadata file from ID/movies.csv and jikan API
while IFS="|" read -r imdb_id mal_id title_mal title_plex
do
        if grep "^${mal_id}$" $movies_titles
        then
                if [ ! -f $SCRIPT_FOLDER/data/$mal_id.json ]														# check if data exist
		then
			get-mal-infos
		fi
		sorttitleline=$(grep -n "sort_title: \"$title_mal\"" $movies_titles | cut -d : -f 1)
                ratingline=$((sorttitleline+1))
                if sed -n "${ratingline}p" $movies_titles | grep "audience_rating:"
                then
                        sed -i "${ratingline}d" $movies_titles
                        mal_score=$(get-mal-rating)
                        sed -i "${ratingline}i\    audience_rating: ${mal_score}" $movies_titles
                        echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_mal updated score : $mal_score" >> $LOG
		fi
                tagsline=$((sorttitleline+2))
                if sed -n "${tagsline}p" $movies_titles | grep "genre.sync:"
                then
                        sed -i "${tagsline}d" $movies_titles
                        mal_tags=$(get-mal-tags)
                        sed -i "${tagsline}i\    genre.sync: anime,${mal_tags}" $movies_titles
                        echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_mal updated tags : $mal_tags" >> $LOG
		fi
        else
		if [ ! -f $SCRIPT_FOLDER/data/$mal_id.json ]														# check if data exist
		then
			get-mal-infos
		fi
		echo "  \"$title_mal\":" >> $movies_titles
                echo "    alt_title: \"$title_plex\"" >> $movies_titles
                echo "    sort_title: \"$title_mal\"" >> $movies_titles
		score_mal=$(get-mal-rating)
                echo "    audience_rating: $score_mal" >> $movies_titles
		mal_tags=$(get-mal-tags)
		echo "    genre.sync: anime,${mal_tags}"  >> $movies_titles
		if [ ! -f $SCRIPT_FOLDER/posters/$mal_id.jpg ]														# check if poster exist
		then
			get-mal-poster
			echo "    file_poster: $SCRIPT_FOLDER/posters/${mal_id}.jpg" >> $movies_titles
		else
			echo "    file_poster: $SCRIPT_FOLDER/posters/${mal_id}.jpg" >> $movies_titles
		fi
		echo "#   mal_id: $mal_id" >> $movies_titles
		echo "$(date +%Y.%m.%d" - "%H:%M:%S) - added to metadata : $title_mal / $title_plex / score : $score_mal / tags / poster" >> $LOG
        fi
done < $SCRIPT_FOLDER/ID/movies.csv
