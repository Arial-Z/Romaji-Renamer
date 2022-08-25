# Plex-Romaji-Renamer

Bash script to create and maintain a PMM metadata file for anime with data from MAL (with jikan) :
  - Romaji title
  - Mal Score
  - Mal tags
  - Mal Poster

## Getting Started
First you need plex, Plex-Meta-Manager and JQ
to install and use see : https://github.com/meisnate12/Plex-Meta-Manager
you also need to install jq wich is a json parser see : https://stedolan.github.io/jq/

Then you need to create 1 PMM config for exporting anime name and the corresponding tvdb-id
copy your "config.yml" to "temp-animes.yml"
and modify the library part like that :

libraries:
  Animes:

settings:
...

Once that's done clone to the folder of your choice
cd to this folder
and copy .conf.delfaut to .conf
edit the path folder and file


