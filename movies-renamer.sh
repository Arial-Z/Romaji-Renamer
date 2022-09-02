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
if [ ! -f $SCRIPT_FOLDER/data/$mal_id.json ]
then
	sleep 0.5
	curl "https://api.jikan.moe/v4/anime/$mal_id" > $SCRIPT_FOLDER/data/$mal_id.json 
	sleep 1.5
fi
}
function get-mal-title () {
jq .data.title -r $SCRIPT_FOLDER/data/$mal_id.json
}
function get-mal-rating () {
jq .data.score -r $SCRIPT_FOLDER/data/$mal_id.json
}
function get-mal-poster () {
if [ ! -f $SCRIPT_FOLDER/posters/$mal_id.jpg ]
then
sleep 0.5
	mal_poster_url=$(jq .data.images.jpg.large_image_url -r $SCRIPT_FOLDER/data/$mal_id.json)
	curl "$mal_poster_url" > $SCRIPT_FOLDER/posters/$mal_id.jpg
sleep 1.5
fi
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
	find $SCRIPT_FOLDER/data/* -mtime +2 -exec rm {} \;
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

# create ID/movies.tsv ( imdb_id | mal_id | title_mal | title_plex )
while IFS=$'\t' read -r imdb_id mal_id title_mal
do
	if ! awk -F"|" '{print $1}' $SCRIPT_FOLDER/ID/movies.tsv | grep '\s{$imdb_id}\>'
	then
		line=$(grep -n '\s{$imdb_id}\>' $SCRIPT_FOLDER/tmp/list-movies.tsv | cut -d : -f 1)
		title_plex=$(sed -n "${line}p" $SCRIPT_FOLDER/tmp/list-movies.tsv | awk -F"\t" '{print $2}')
		printf "$imdb_id\t$mal_id\t$title_mal\t$title_plex\n" >> $SCRIPT_FOLDER/ID/movies.tsv
		echo "$(date +%H:%M:%S) - override found for : $title_mal / $title_plex" >> $LOG
	fi
done < $SCRIPT_FOLDER/override-ID-movies.tsv
while IFS=$'\t' read -r imdb_id title_plex
do
	if ! awk -F"\t" '{print $1}' $SCRIPT_FOLDER/ID/movies.tsv | grep '\s{$imdb_id}\>'
	then
		mal_id=$(get-mal-id)
		if [[ "$mal_title" == 'null' ]] || [[ "$mal_id" == 'null' ]] || [[ "${#mal_id}" == '0' ]]
		then
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - invalid MAL ID for : tvdb : $imdb_id / $title_plex" >> $ERROR_LOG
		fi
		get-mal-infos
		title_mal=$(get-mal-title)
		printf "$imdb_id\t$mal_id\t$title_mal\t$title_plex\n" >> $SCRIPT_FOLDER/ID/movies.tsv
		echo "$(date +%H:%M:%S) - $title_mal / $title_plex added to ID/movies.tsv" >> $LOG
	fi
done < $SCRIPT_FOLDER/tmp/list-movies.tsv

#Create an MAL top 100 movies
if [ ! -f $SCRIPT_FOLDER/data/top-movies.tsv ]		#check if already exist in data folder is stored for 2 days 
then
        topmoviesgpage=1
        while [ $topmoviesgpage -lt 5 ];			#get the airing list from jikan API max 4 pages (100 movies)
        do
                curl "https://api.jikan.moe/v4/top/anime?type=movie&page=$topmoviesgpage" > $SCRIPT_FOLDER/tmp/top-movies-tmp.json
                sleep 2
                jq ".data[].mal_id" -r $SCRIPT_FOLDER/tmp/top-movies-tmp.json >> $SCRIPT_FOLDER/tmp/top-movies.tsv		# store the mal ID of the ongoing show
                ((topmoviesgpage++))
        done
        while read -r mal_id
        do
                if awk -F"\t" '{print $2}' $SCRIPT_FOLDER/ID/movies.tsv | grep '\s$mal_id\>'		# create the top movies list
		then
			line=$(grep -n "\<$mal_id\>" $SCRIPT_FOLDER/ID/movies.tsv | cut -d : -f 1)
			imdb_id=$(sed -n "${line}p" $SCRIPT_FOLDER/ID/movies.tsv | awk -F"\t" '{print $1}')
			title_mal=$(sed -n "${line}p" $SCRIPT_FOLDER/ID/movies.tsv | awk -F"\t" '{print $3}')
			printf "$imdb_id\t$mal_id\t$title_mal\n" >> $SCRIPT_FOLDER/data/top-movies.tsv
		fi
	done < $SCRIPT_FOLDER/tmp/top-movies.tsv
fi


# write PMM metadata file from ID/movies.tsv and jikan API
while IFS=$'\t' read -r imdb_id mal_id title_mal title_plex
do
	if grep '\s$mal_id\>' $movies_titles
	then
		get-mal-infos
		get-mal-poster
		sorttitleline=$(grep -n "sort_title: \"$title_mal\"" $movies_titles | cut -d : -f 1)
		ratingline=$((sorttitleline+1))
		if sed -n "${ratingline}p" $movies_titles | grep "audience_rating:"
		then
			sed -i "${ratingline}d" $movies_titles
			mal_score=$(get-mal-rating)
			sed -i "${ratingline}i\    audience_rating: ${mal_score}" $movies_titles
			echo "$(date +%H:%M:%S) - $title_mal updated score : $mal_score" >> $LOG
		fi
		tagsline=$((sorttitleline+2))
		if sed -n "${tagsline}p" $movies_titles | grep "genre.sync:"
		then
			sed -i "${tagsline}d" $movies_titles
			mal_tags=$(get-mal-tags)
			sed -i "${tagsline}i\    genre.sync: anime,${mal_tags}" $movies_titles
			echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_mal updated tags : $mal_tags" >> $LOG
		fi
		topmoviesline=$((sorttitleline+3))
		if sed -n "${topmoviesline}p" $movies_titles | grep "label"			# replace the Movies-top-100 label
		then
			sed -i "${topmoviesline}d" $movies_titles
			if awk -F"\t" '{print $2}' $SCRIPT_FOLDER/data/top-movies.tsv | grep '\s$mal_id\>'
			then
				sed -i "${topmoviesline}i\    label: AM-100" $movies_titles
				echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_mal added to AM-100" >> $LOG
			else
				sed -i "${topmoviesline}i\    label.remove: AM-100" $movies_titles
				echo "$(date +%Y.%m.%d" - "%H:%M:%S) - $title_mal removed from AM-100" >> $LOG
			fi
		fi
	else
		get-mal-infos
		echo "  \"$title_mal\":" >> $movies_titles
                echo "    alt_title: \"$title_plex\"" >> $movies_titles
                echo "    sort_title: \"$title_mal\"" >> $movies_titles
		score_mal=$(get-mal-rating)
                echo "    audience_rating: $score_mal" >> $movies_titles
		mal_tags=$(get-mal-tags)
		echo "    genre.sync: anime,${mal_tags}"  >> $movies_titles
		if awk -F"\t" '{print $2}' $SCRIPT_FOLDER/data/top-movies.tsv | grep '\s$mal_id\>'		# Movies-top-100 label
		then
			echo "    label: AM-100" >> $movies_titles
		else
			echo "    label.remove: AM-100" >> $movies_titles
		fi
		get-mal-poster
		echo "    file_poster: $SCRIPT_FOLDER/posters/${mal_id}.jpg" >> $movies_titles
		echo "#   mal_id: $mal_id" >> $movies_titles
		echo "$(date +%H:%M:%S) - added to metadata : $title_mal / $title_plex / score : $score_mal / tags / poster" >> $LOG
	fi
done < $SCRIPT_FOLDER/ID/movies.tsv