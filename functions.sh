#!/bin/bash

# functions
function get-mal-id-from-tvdb-id () {
jq ".[] | select( .tvdb_id == ${tvdb_id} ) | select( .tvdb_season == 1 ) | select( .tvdb_epoffset == 0 ) | .mal_id" -r $SCRIPT_FOLDER/tmp/list-animes-id.json
}
function get-mal-id-from-imdb-id () {
imdb_jq=$(echo $imdb_id | awk '{print "\""$1"\""}' )
jq ".[] | select( .imdb_id == ${imdb_jq} )" -r $SCRIPT_FOLDER/tmp/list-animes-id.json | jq .mal_id | sort -n | head -1
}
function get-anilist-id () {
jq ".[] | select( .mal_id == ${mal_id} ) | .anilist_id" -r $SCRIPT_FOLDER/tmp/list-animes-id.json
}
function get-tvdb-id () {
jq ".[] | select( .mal_id == ${mal_id} ) | .tvdb_id" -r $SCRIPT_FOLDER/tmp/list-animes-id.json
}
function get-mal-infos () {
if [ ! -f $SCRIPT_FOLDER/data/$mal_id.json ] 										#check if exist
then
	sleep 0.5
	curl "https://api.jikan.moe/v4/anime/$mal_id" > $SCRIPT_FOLDER/data/$mal_id.json
	sleep 1.5
fi
}
function get-anilist-infos () {
if [ ! -f $SCRIPT_FOLDER/data/title-$mal_id.json ]
then
	sleep 0.5
	curl 'https://graphql.anilist.co/' \
	-X POST \
	-H 'content-type: application/json' \
	--data '{ "query": "{ Media(id: '"$anilist_id"') { title { romaji } } }" }' > $SCRIPT_FOLDER/data/title-$mal_id.json
	sleep 1.5
fi
}
function get-anilist-title () {
jq .data.Media.title.romaji -r $SCRIPT_FOLDER/data/title-$mal_id.json
}
function get-mal-eng-title () {
jq .data.title_english -r $SCRIPT_FOLDER/data/$mal_id.json
}
function get-mal-rating () {
jq .data.score -r $SCRIPT_FOLDER/data/$mal_id.json
}
function get-mal-poster () {
if [ ! -f $POSTERS_FOLDER/$mal_id.jpg ]										#check if exist
then
	sleep 0.5
	mal_poster_url=$(jq .data.images.jpg.large_image_url -r $SCRIPT_FOLDER/data/$mal_id.json)
	wget --no-use-server-timestamps -O $POSTERS_FOLDER/$mal_id.jpg "$mal_poster_url"
	sleep 1.5
else
	postersize=$(du -b $POSTERS_FOLDER/$mal_id.jpg | awk '{ print $1 }')
	if [[ $postersize -lt 10000 ]]
	then
		rm $POSTERS_FOLDER/$mal_id.jpg
		sleep 0.5
		mal_poster_url=$(jq .data.images.jpg.large_image_url -r $SCRIPT_FOLDER/data/$mal_id.json)
		wget --no-use-server-timestamps -O $POSTERS_FOLDER/$mal_id.jpg "$mal_poster_url"
		sleep 1.5
	fi
fi
}
function get-mal-tags () {
(jq '.data.genres  | .[] | .name' -r $SCRIPT_FOLDER/data/$mal_id.json && jq '.data.demographics  | .[] | .name' -r $SCRIPT_FOLDER/data/$mal_id.json && jq '.data.themes  | .[] | .name' -r $SCRIPT_FOLDER/data/$mal_id.json) | awk '{print $0}' | paste -s -d, -
}
function get-mal-studios() {
if awk -F"\t" '{print $2}' $SCRIPT_FOLDER/override-ID-animes.tsv | grep -w  $mal_id
then
     line=$(grep -w -n $mal_id $SCRIPT_FOLDER/override-ID-animes.tsv | cut -d : -f 1)
	studio=$(sed -n "${line}p" $SCRIPT_FOLDER/override-ID-animes.tsv | awk -F"\t" '{print $4}')
     if [[ -z "$studio" ]]
	then
          mal_studios=$(jq '.data.studios[0] | [.name]| @tsv' -r $SCRIPT_FOLDER/data/$mal_id.json)
     else
          mal_studios=$(echo "$studio")
     fi
else
	mal_studios=$(jq '.data.studios[0] | [.name]| @tsv' -r $SCRIPT_FOLDER/data/$mal_id.json)
fi
}
function downlaod-anime-id-mapping () {
if [ -d $SCRIPT_FOLDER/tmp/list-animes-id.json ]
then
	rm $SCRIPT_FOLDER/tmp/list-animes-id.json
fi
wait_time=0
while [ $wait_time -le 4 ];
do
	wget -O $SCRIPT_FOLDER/tmp/list-animes-id.json "https://raw.githubusercontent.com/Arial-Z/Animes-ID/main/list-animes-id.json"
	size=$(du -b $SCRIPT_FOLDER/tmp/list-animes-id.json | awk '{ print $1 }')
	if [[ $size -lt 1000 ]]
	then
		sleep 30
	else
		break
	fi
	((wait_time++))
done
if [[ $wait_time = 4 ]]
then
	echo "can't download anime ID mapping file"
	exit 1
fi
}