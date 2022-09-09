#!/bin/bash

function remove-line () {
while :
do
	if grep "$del_name" anime-list.xml
	then
		linedel=$(grep -m 1 -n "$del_name" anime-list.xml | cut -d : -f 1)
		sed -i "${linedel}d" anime-list.xml
	else
		break
	fi
done
}

for  del_name in "<supplemental-info" "<studio" "</supplemental-info>" "<mapping" "</mapping-list>"
do
	remove-line
done

https://webdevdesigner.com/q/how-to-parse-xml-in-bash-38700/

parse_dom () {
    if [[ $TAG_NAME = "foo" ]] ; then
        eval local $ATTRIBUTES
        echo "foo size is: $size"
    elif [[ $TAG_NAME = "bar" ]] ; then
        eval local $ATTRIBUTES
        echo "bar type is: $type"
    fi
}