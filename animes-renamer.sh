#!/bin/bash

SCRIPT_FOLDER=$(dirname $(readlink -f $0))
source $SCRIPT_FOLDER/config.conf
LOG=$LOG_FOLDER/animes_$(date +%Y.%m.%d).log
ERROR_LOG=$LOG_FOLDER/error.log

# function
function get-mal-id () {
jq ".[] | select( .tvdb_id == ${tvdb_id} )" -r $SCRIPT_FOLDER/pmm_anime_ids.json |jq .mal_id | sort -n | head -1
}
function get-mal-infos () {
wget "https://api.jikan.moe/v4/anime/$mal_id" -O $SCRIPT_FOLDER/data/$mal_id.json 
sleep 2
}
function get-mal-title () {
jq .data.title -r $SCRIPT_FOLDER/data/$mal_id.json
}
function get-mal-rating () {
jq .data.score -r $SCRIPT_FOLDER/data/$mal_id.json
}
function get-mal-poster () {
mal_poster_url=$(jq .data.images.jpg.large_image_url -r $SCRIPT_FOLDER/data/$mal_id.json)
wget "$mal_poster_url" -O $SCRIPT_FOLDER/posters/$mal_id.jpg
sleep 2
}
function get-mal-tags () {
(jq '.data.genres  | .[] | .name' -r $SCRIPT_FOLDER/data/$mal_id.json && jq '.data.themes  | .[] | .name' -r $SCRIPT_FOLDER/data/$mal_id.json) | awk '{print $1}' | paste -s -d, -
}
function echo-ID () {
echo "$tvdb_id\t$mal_id\t$title_mal\t$title_plex" >> $SCRIPT_FOLDER/ID-animes.tsv
echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_mal / $title_plex added to ID-movies.tsv" >> $LOG
}

#create and check needed folder and files
if [ ! -f $movies_titles ]
then
        echo "metadata:" > $movies_titles
fi
if [ ! -d $SCRIPT_FOLDER/data ]
then
        mkdir $SCRIPT_FOLDER/data
else
	rm $SCRIPT_FOLDER/data/*
fi
if [ ! -d $SCRIPT_FOLDER/tmp ]
then
        mkdir $SCRIPT_FOLDER/tmp
fi
if [ ! -d $SCRIPT_FOLDER/posters ]
then
        mkdir $SCRIPT_FOLDER/posters
fi
if [ ! -f $SCRIPT_FOLDER/ID-animes.tsv ]
then
        touch $SCRIPT_FOLDER/ID-animes.tsv
fi

# create pmm meta.log
rm $PMM_FOLDER/config/temp-animes.cache
$PMM_FOLDER/pmm-venv/bin/python3 $PMM_FOLDER/plex_meta_manager.py -r --config $PMM_FOLDER/config/temp-animes.yml
mv $PMM_FOLDER/config/logs/meta.log $SCRIPT_FOLDER

# create clean list-animes.tsv (tvdb_id | title_plex) from meta.log
rm $SCRIPT_FOLDER/list-animes.tsv
line_start=$(grep -n "Mapping Animes Library" $SCRIPT_FOLDER/meta.log | cut -d : -f 1)
line_end=$(grep -n -m1 "Animes Library Operations" $SCRIPT_FOLDER/meta.log | cut -d : -f 1)
head -n $line_end $SCRIPT_FOLDER/meta.log | tail -n $(( $line_end - $line_start - 1 )) | head -n -5 > $SCRIPT_FOLDER/cleanlog-animes.txt
rm $SCRIPT_FOLDER/meta.log
awk -F"|" '{ OFS = "\t" } ; { gsub(/ /,"",$5) } ; { print substr($5,8),substr($7,2,length($7)-2) }' $SCRIPT_FOLDER/cleanlog-animes.txt > $SCRIPT_FOLDER/list-animes.tsv
rm $SCRIPT_FOLDER/cleanlog-animes.txt

# download pmm animes mapping and check if files and folder exist
curl "https://raw.githubusercontent.com/meisnate12/Plex-Meta-Manager-Anime-IDs/master/pmm_anime_ids.json" > $SCRIPT_FOLDER/pmm_anime_ids.json

# create ID-animes.tsv ( tvdb_id | mal_id | title_mal | title_plex )
while IFS="|" read -r tvdb_id title_plex
do
	if ! awk -F"\t" '{print $1}' $SCRIPT_FOLDER/ID-animes.tsv | grep $tvdb_id                                                   					# check if not already in ID-animes.tsv
	then
		if awk -F"\t" '{print $1}' $SCRIPT_FOLDER/override-ID-animes.tsv | tail -n +2 | grep $tvdb_id								# check if in override
		then
			overrideline=$(grep -n "$tvdb_id" $SCRIPT_FOLDER/override-ID-animes.tsv | cut -d : -f 1)
			mal_id=$(sed -n "${overrideline}p" $SCRIPT_FOLDER/override-ID-animes.tsv | awk -F"\t" '{print $2}')
			title_mal=$(sed -n "${overrideline}p" $SCRIPT_FOLDER/override-ID-animes.tsv | awk -F"\t" '{print $3}')
			get-mal-infos
			echo-ID
		else
			mal_id=$(get-mal-id)
		if [[ "$mal_title" == 'null' ]] || [[ "$mal_id" == 'null' ]] || [[ "${#mal_id}" == '0' ]]
		then
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - invalid MAL ID for : tvdb : $tvdb_id / $title_plex" >> $ERROR_LOG
		fi
			get-mal-infos
			title_mal=$(get-mal-title)
			echo-ID
		fi
	fi
done < $SCRIPT_FOLDER/list-animes.csv

# write PMM metadata file from ID-animes.tsv and jikan API
while IFS="|" read -r tvdb_id mal_id title_mal title_plex
do
        if grep "$title_mal" $animes_titles
        then
                if [ ! -f $SCRIPT_FOLDER/data/$mal_id.json ]														# check if data exist
		then
			get-mal-infos
		fi
		sorttitleline=$(grep -n "sort_title: \"$title_mal\"" $animes_titles | cut -d : -f 1)
                ratingline=$((sorttitleline+1))
                if sed -n "${ratingline}p" $animes_titles | grep "audience_rating:"
                then
                        sed -i "${ratingline}d" $animes_titles
                        mal_score=$(get-mal-rating)
                        sed -i "${ratingline}i\    audience_rating: ${mal_score}" $animes_titles
                        echo "$(date +%H:%M:%S) - $title_mal updated score : $mal_score" >> $LOG
		fi
                tagsline=$((sorttitleline+2))
                if sed -n "${tagsline}p" $animes_titles | grep "genre.sync:"
                then
                        sed -i "${tagsline}d" $animes_titles
                        mal_tags=$(get-mal-tags)
                        sed -i "${tagsline}i\    genre.sync: anime,${mal_tags}" $animes_titles
                        echo "$(date +%H:%M:%S) - $title_mal updated tags : $mal_tags" >> $LOG
		fi		
        else
		if [ ! -f $SCRIPT_FOLDER/data/$mal_id.json ]														# check if data exist
		then
			get-mal-infos
		fi
		echo "  \"$title_mal\":" >> $animes_titles
                echo "    alt_title: \"$title_plex\"" >> $animes_titles
                echo "    sort_title: \"$title_mal\"" >> $animes_titles
		score_mal=$(get-mal-rating)
                echo "    audience_rating: $score_mal" >> $animes_titles
		mal_tags=$(get-mal-tags)
		echo "    genre.sync: anime,${mal_tags}"  >> $animes_titles
                if [ ! -f $SCRIPT_FOLDER/posters/$mal_id.jpg ]														# check if poster exist
		then
			get-mal-poster
			echo "    file_poster: $SCRIPT_FOLDER/posters/${mal_id}.jpg" >> $animes_titles
		fi
		
		echo "$(date +%H:%M:%S) - added to metadata : $title_mal / $title_plex / score : $score_mal / tags / poster" >> $LOG

        fi
done < $SCRIPT_FOLDER/ID-animes.tsv
