#!/bin/bash

# function
function get-mal-id ()
{
        jq ".[] | select(".tvdb_id"==${tvdb_id})" -r $SCRIPT_FOLDER/pmm_anime_ids.json |jq ."mal_id" | sort -n | head -1
}

function get-mal-title ()
{
curl "https://api.jikan.moe/v4/anime/$mal_id" | jq .data.title | sed 's/^.//;s/.$//'
}
function get-mal-rating ()
{
curl "https://api.jikan.moe/v4/anime/$mal_id" | jq .data.score
}

## folder and file emplacement
SCRIPT_FOLDER=/home/arialz/scripts/plex-renamer
PMM_FOLDER=/home/plexmetamanager
PMM_CONFIG=$PMM_FOLDER/config/temp.yml
LOG_PATH=/home/arialz/log/plex-renamer_$(date +%Y.%m.%d).log
animes_titles=/home/arialz/github/PMM-Arialz/metadata/animes-titles.yml

# get library titles and tvdb-ID list by PMM
rm $PMM_FOLDER/config/temp.cache
rm $SCRIPT_FOLDER/animes-id.txt
rm $SCRIPT_FOLDER/meta.log
rm $SCRIPT_FOLDER/cleanlog.txt
$PMM_FOLDER/pmm-venv/bin/python3 $PMM_FOLDER/plex_meta_manager.py -r --config $PMM_FOLDER/config/temp.yml
mv $PMM_FOLDER/config/logs/meta.log $SCRIPT_FOLDER
line_start=$(grep -n "Mapping Animes Library" $SCRIPT_FOLDER/meta.log | cut -d : -f 1)
line_end=$(grep -n "Running animes-airing Metadata File" $SCRIPT_FOLDER/meta.log | cut -d : -f 1)
head -n $line_end $SCRIPT_FOLDER/meta.log | tail -n $(( $line_end -$line_start - 1 )) | head -n -5 > $SCRIPT_FOLDER/cleanlog.txt
awk '{FS = "|";OFS = "|" } ; { print $5,substr($7,2,length($7)-2) }' cleanlog.txt > $SCRIPT_FOLDER/animes-id.txt
while IFS= read -r title; do
        cut -c 11- > $SCRIPT_FOLDER/animes-list.csv
done < animes-id.txt

# get corresponding MAL title and score
curl "https://raw.githubusercontent.com/meisnate12/Plex-Meta-Manager-Anime-IDs/master/pmm_anime_ids.json" > $SCRIPT_FOLDER/pmm_anime_ids.json
while IFS="|" read -r tvdb_id title
do
        if ! awk '{FS = "|"} ; { print $1}' ID-override.csv | tail -n +2 | grep $tvdb_id || awk '{FS = "|"} ; { print $1}' ID.csv | tail -n +2 | grep $tvdb_id     # check if already parsed
        then
                echo "$title ID already found" >> $LOG_PATH
        else
                mal_id=$(get-mal-id)
                if [[ "$mal_title" == 'null' ]] || [[ "$mal_id" == 'null' ]] || [[ "${#mal_id}" == '0' ]]
                then
                        echo "invalid MAL ID / tvdb : $tvdb_id / $title" >> $LOG_PATH
                        continue
                fi
                title_mal=$(get-mal-title)
                echo "$tvdb_id|$mal_id|$title_mal" >> $SCRIPT_FOLDER/ID.csv
                sleep 3
        fi
        if awk '{FS = "|"} ; { print $1}' ID-override.csv | tail -n +2 | grep $tvdb_id || awk '{FS = "|"} ; { print $1}' ID.csv | tail -n +2 | grep $tvdb_id     # check if already parsed
        then
                while IFS="|" read -r tvdb_id mal_id title_mal
                do
                        if grep "$title_mal" $animes_titles
                        then
                                line_anime_title=$(grep -n "sort_title: \"$title_mal\"" | cut -d : -f 1)
                                sed '$(( $line_anime_title + 1 ))' $animes_titles
                                mal_score=$(get-mal-rating)
                                echo "    user_rating: $mal_score" >> $animes_titles
                        else
                                title_mal=$(get-mal-title)
                                mal_score=$(get-mal-rating)
                                echo "tvdb : $tvdb_id - MAL : $mal_id / $title_mal - $title" >> $LOG_PATH
                                echo "  \"$title_mal\":" >> $animes_titles
                                echo "    alt_title: \"$title\"" >> $animes_titles
                                echo "    sort_title: \"$title_mal\"" >> $animes_titles
                                echo "    user_rating: $mal_score" >> $animes_titles
                                sleep 3
                        fi
                done < < <(tail -n +3 $SCRIPT_FOLDER/ID-override.csv)        
done < <(tail -n +2 $SCRIPT_FOLDER/animes-list.csv)

# if ! awk '{FS = "|"} ; { print $1}' ID-override.csv | tail -n +2 | grep $tvdb_id               