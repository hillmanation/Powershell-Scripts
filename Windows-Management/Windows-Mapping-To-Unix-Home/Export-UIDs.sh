#!/bin/bash
IFS=$'\n'
HOMEFOLDERS="home"
FOLDERS=$(ls "/$HOMEFOLDERS")

echo "Name,UID,GID"

for FOLDER in $FOLDERS
do
        DIR="/$HOMEFOLDERS/$FOLDER"
        UUID=$(stat -c '%u' "$DIR")
        GUID=$(stat -c '%g' "$DIR")

        echo "$FOLDER,$UUID,$GUID"
done