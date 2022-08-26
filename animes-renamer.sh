#!/bin/bash

SCRIPT_FOLDER=$(dirname $(readlink -f $0))
source $SCRIPT_FOLDER/config.conf

# function
function get-mal-id () {
jq ".[] | select(".tvdb_id"==${tvdb_id})" -r $SCRIPT_FOLDER/pmm_anime_ids.json |jq ."mal_id" | sort -n | head -1
}
function get-mal-infos () {
wget "https://api.jikan.moe/v4/anime/$mal_id" -O $SCRIPT_FOLDER/data/$mal_id.json 
sleep 1.2
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
# create pmm meta.log
rm $PMM_FOLDER/config/temp-animes.cache
$PMM_FOLDER/pmm-venv/bin/python3 $PMM_FOLDER/plex_meta_manager.py -r --config $PMM_FOLDER/config/temp-animes.yml
mv $PMM_FOLDER/config/logs/meta.log $SCRIPT_FOLDER

# create clean list-animes.csv (tvdb_id | title_plex) from meta.log
rm $SCRIPT_FOLDER/list-animes.csv
line_start=$(grep -n "Mapping Animes Library" $SCRIPT_FOLDER/meta.log | cut -d : -f 1)
line_end=$(grep -n -m1 "Animes Library Operations" $SCRIPT_FOLDER/meta.log | cut -d : -f 1)
head -n $line_end $SCRIPT_FOLDER/meta.log | tail -n $(( $line_end - $line_start - 1 )) | head -n -5 > $SCRIPT_FOLDER/cleanlog.txt
rm $SCRIPT_FOLDER/meta.log
awk -F"|" '{ OFS = "|" } ; { gsub(/ /,"",$5) } ; { print substr($5,8),substr($7,2,length($7)-2) }' $SCRIPT_FOLDER/cleanlog.txt > $SCRIPT_FOLDER/list-animes.csv
rm $SCRIPT_FOLDER/cleanlog.txt

# download pmm animes mapping and check if files and folder exist
curl "https://raw.githubusercontent.com/meisnate12/Plex-Meta-Manager-Anime-IDs/master/pmm_anime_ids.json" > $SCRIPT_FOLDER/pmm_anime_ids.json
if [ ! -f $animes_titles ]
then
        echo "metadata:" > $animes_titles
fi
if [ ! -d $SCRIPT_FOLDER/data ]
then
        mkdir $SCRIPT_FOLDER/data
else
	rm $SCRIPT_FOLDER/data/*
fi
if [ ! -d $SCRIPT_FOLDER/posters ]
then
        mkdir $SCRIPT_FOLDER/posters
fi
if [ ! -f $SCRIPT_FOLDER/ID-animes.csv ]
then
        touch $SCRIPT_FOLDER/ID-animes.csv
fi

# create ID-animes.csv ( tvdb_id | mal_id | title_mal | title_plex )
while IFS="|" read -r tvdb_id title_plex
do
	if ! awk -F"|" '{print $1}' $SCRIPT_FOLDER/ID-animes.csv | grep $tvdb_id                                                   					# check if not already in ID-animes.csv
	then
		if awk -F"|" '{print $1}' $SCRIPT_FOLDER/override-ID-animes.csv | tail -n +2 | grep $tvdb_id								# check if in override
		then
			overrideline=$(grep -n "$tvdb_id" $SCRIPT_FOLDER/override-ID-animes.csv | cut -d : -f 1)
			mal_id=$(sed -n "${overrideline}p" $SCRIPT_FOLDER/override-ID-animes.csv | awk -F"|" '{print $2}')
			title_mal=$(sed -n "${overrideline}p" $SCRIPT_FOLDER/override-ID-animes.csv | awk -F"|" '{print $3}')
			get-mal-infos
			echo "override found for : $title_mal / $title_plex" >> $LOG_PATH
			echo "$tvdb_id|$mal_id|$title_mal|$title_plex" >> $SCRIPT_FOLDER/ID-animes.csv
		else
			mal_id=$(get-mal-id)
		if [[ "$mal_title" == 'null' ]] || [[ "$mal_id" == 'null' ]] || [[ "${#mal_id}" == '0' ]]
		then
			echo "invalid MAL ID for : tvdb : $tvdb_id / $title_plex" >> $LOG_PATH
		fi
			get-mal-infos
			title_mal=$(get-mal-title)
			echo "$tvdb_id|$mal_id|$title_mal|$title_plex" >> $SCRIPT_FOLDER/ID-animes.csv
			echo "$title_mal / $title_plex added to ID-animes.csv" >> $LOG_PATH
		fi
	fi
done < $SCRIPT_FOLDER/list-animes.csv

# write PMM metadata file from ID-animes.csv and jikan API
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
                        echo "$title_mal updated score : $mal_score" >> $LOG_PATH
		fi
                tagsline=$((sorttitleline+2))
                if sed -n "${tagsline}p" $animes_titles | grep "genre.sync:"
                then
                        sed -i "${tagsline}d" $animes_titles
                        mal_tags=$(get-mal-tags)
                        sed -i "${tagsline}i\    genre.sync: anime,${mal_tags}" $animes_titles
                        echo "$title_mal updated tags : $mal_tags" >> $LOG_PATH
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
		
		echo "added to metadata : $title_mal / $title_plex / score : $score_mal / tags / poster" >> $LOG_PATH

        fi
done < $SCRIPT_FOLDER/ID-animes.csv
