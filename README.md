# Plex-Romaji-Renamer

Bash script to retrieve metadata from MAL (from jikan) and import it to plex with PMM metadata file
  - Romaji title
  - Mal Score
  - Mal tags
  - Mal Poster
  
  Will likely only work with plex TV agent and not Hama

## Getting Started
First you need plex, Plex-Meta-Manager and JQ
to install and use see : https://github.com/meisnate12/Plex-Meta-Manager
you also need to install jq wich is a json parser see : https://stedolan.github.io/jq/

Then you need to create a PMM config for exporting anime name and the corresponding tvdb-id
copy your "config.yml" to "temp-animes.yml"
and modify the library to only leave your Animes library name
```
libraries:
  Animes:

settings:
...
```
Once that's done clone to the folder of your choice
cd to this folder
and copy .conf.delfaut to .conf
edit the path folder and file


