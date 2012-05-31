#!/bin/bash
#
# Uploader for half-downloaded users from Tabblo.com.
#
# ASK ON IRC BEFORE RUNNING THIS
#
# This will look for warc files with a wget.log. If the wget.log is finished
# (with a Downloaded: xxx files) the warc file is complete, but since it's
# still not uploaded there were probably one or more download errors.
# This script will upload the file anyway.
#
# Usage:
#   ./its-broken-but-upload-anyway.sh $YOURNICK
#

if [[ ! $1 =~ yesimsure ]]
then
  echo "This is not for normal use. Are you really sure you want to run this?"
  exit
fi

youralias="$2"
bwlimit=$3

if [[ ! $youralias =~ ^[-A-Za-z0-9_]+$ ]]
then
  echo "Usage:  $0 {nickname}"
  echo "Run with a nickname with only A-Z, a-z, 0-9, - and _"
  exit 4
fi

if [ -n "$bwlimit" ]
then
  if [[ ! $bwlimit =~ ^[1-9][0-9]*$ ]]
  then
    echo "Invalid bandwidth limit specified."
    echo "Usage:  $0 {nickname} [bwlimit]"
    echo "If bwlimit is specified, it must be a number, meaning kilobytes per second."
    exit 4
  fi
  bwlimit="--bwlimit=${bwlimit}"
fi

VERSION=$( grep 'VERSION=' dld-tabblo-user.sh | grep -oE "[-0-9.]+" )

find data/ -name "*.warc.gz" | grep -P "data/./../.../" | while read warcfile
do
  wget_log_file=$( dirname $warcfile )/wget.log
  itemname=$( basename $( dirname $warcfile ) )

  echo "Testing ${warcfile} ($itemname)"
  if [ ! -f $wget_log_file ]
  then
    echo "  No wget.log."
    echo
  elif ! grep -q "^Downloaded: " $wget_log_file
  then
    echo "  wget.log incomplete."
    echo
  else
    echo "  wget.log is finished, probably with errors."
    echo "  Better than nothing, uploading anyway!"
    echo

    prefix_dir="${itemname:0:1}/${itemname:0:2}/${itemname:0:3}"
    prefix_file="$prefix_dir/tabblo-$itemname-"

    # complete
    mv $warcfile data/$prefix_dir

    # statistics!
    bytes=$( ./du-helper.sh -b "data/$prefix_dir/tabblo-$itemname-"*".warc.gz" )
    bytes_str="{\"user\":${bytes}}"

    success_str="{\"downloader\":\"${youralias}\",\"item\":\"${itemname}\",\"bytes\":${bytes_str},\"version\":\"${VERSION}\",\"id\":\"with-errors\"}"

    # upload
    echo "Uploading ${itemname}..."

    cd data
    result=9
    while [ $result -ne 0 ]
    do
      ls -1 "$prefix_file"*".warc.gz" | \
      rsync -avz \
            --compress-level=9 \
            --progress \
            ${bwlimit} \
            --recursive \
            --remove-source-files \
            --files-from="-" \
            ./ fos.textfiles.com::tabblo/${youralias}/
      result=$?

      if [ $result -ne 0 ]
      then
        echo
        echo "An rsync error occurred. Sleeping 10 seconds before retrying..."
        echo
        sleep 10
      fi
    done
    cd ..

    if [ $result -eq 0 ]
    then
      delay=1
      while [ $delay -gt 0 ]
      do
        echo "Telling tracker that '${itemname}' is done."
        tracker_no=$(( RANDOM % 3 ))
        tracker_host="tabb-${tracker_no}.heroku.com"
        resp=$( curl -s -f -d "$success_str" http://${tracker_host}/done )
        if [[ "$resp" != "OK" ]]
        then
          echo "ERROR contacting tracker. Could not mark '$itemname' done."
          echo "Sleep and retry."
          sleep $delay
          delay=$(( delay * 2 ))
        else
          delay=0
        fi
      done
      echo
    else
      echo
      echo
      echo "An rsync error. Scary!"
      echo
      exit 1
    fi

  fi
done

