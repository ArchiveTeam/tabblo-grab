#!/bin/bash
# Tabblo.com ZIP downloader.
#
# This script downloads Tabblo ZIP files and uploads to s3.us.archive.org.
#
# Usage:
#  ./dld-tabblo-zip.sh $RANGE
# where $RANGE is a number.
#
# Example:
#  ./dld-tabblo-zip.sh 12
# will download and upload Tabblos 12000 to 12999.
#
# Notes:
# - You can kill and restart the script at any time, it will resume after
#   the last uploaded Tabblo.
# - The Tabblo ZIP function is somewhat unstable; sometimes the download
#   stop in the middle of the ZIP file. The script will check the ZIP
#   and will redownload it if necessary.
# - It's okay to run more than one script at a time in the same directory,
#   as long as each script downloads a different range.
#
# Version 1.
#

USERNAME=archiveteam
PASSWORD=archiveteam

S3_ACCESSKEY=ERXgnem8nxMYcoiB
S3_SECRET=47BbERXrOULLrzXX

DATA=data
RANGE=$1

if [[ -z $RANGE ]] || [[ ! $RANGE =~ ^[0-9]+$ ]]
then
  echo "Specify a range."
  exit
fi

echo -n "Logging in... "
LOGIN_COOKIE=$( curl -si -d "username=${USERNAME}&password=${PASSWORD}&remember_me=on" "http://www.tabblo.com/studio/login/" | grep -ohE "tabblosesh=[^;]+" )
echo $LOGIN_COOKIE

for TABBLO_ID in $( seq ${RANGE}000 ${RANGE}999 )
do
  TABBLO_ID8=$( printf "%08d" ${TABBLO_ID} )
  TABBLO_DIR=${TABBLO_ID8:0:2}/${TABBLO_ID8:0:5}
  mkdir -p "${DATA}/tabblo/${TABBLO_DIR}"

  if [ -f "${DATA}/tabblo/${TABBLO_DIR}/tabblo-${TABBLO_ID8}.zip" ] || [ -f "${DATA}/tabblo/${TABBLO_DIR}/not-exist-${TABBLO_ID8}.txt" ]
  then
    echo "Already downloaded Tabblo ${TABBLO_ID}."
  else
    echo
    echo "Downloading Tabblo ${TABBLO_ID}:"

    tries=50
    while [ $tries -gt 0 ]
    do
      http_code=$( curl --fail \
        --speed-limit 100 --speed-time 60 \
        --header "Cookie: ${LOGIN_COOKIE}" \
        --output ${DATA}/tmp.$$.zip \
        "http://www.tabblo.com/studio/stories/zip/${TABBLO_ID}/?orig=1" \
        --write-out "%{http_code}" )
      result=$?
      if [ $result -eq 22 ]
      then
        if [ $http_code -eq 404 ] || [ $http_code -eq 403 ]
        then
          echo " Page not found (HTTP ${http_code})."
          echo "${http_code}" > "${DATA}/tabblo/${TABBLO_DIR}/not-exist-${TABBLO_ID8}.txt"
          break
        else
          echo " HTTP error ${http_code}."
        fi
      fi
      echo -n " - Checking zip... "
      if unzip -tqq ${DATA}/tmp.$$.zip
      then
        echo "valid."

        # upload
        echo " - Uploading to s3.us.archive.org... "
        while ! curl --fail --retry 2 --location \
                  --header 'x-amz-auto-make-bucket:1' \
                  --header 'x-archive-queue-derive:0' \
                  --header 'x-archive-meta-mediatype:web' \
                  --header "x-archive-meta-title:ArchiveTeam Tabblo Panic Download: Range ${RANGE}000-${RANGE}999" \
                  --header "x-archive-meta-description:This item contains the ZIP files for Tabblos ${RANGE}000 to ${RANGE}999, as produced by the 'Download as ZIP' function of Tabblo.com." \
                  --header 'x-archive-meta-date:'$( date +"%Y-%m" ) \
                  --header 'x-archive-meta-year:'$( date +"%Y" ) \
                  --header "authorization: LOW ${S3_ACCESSKEY}:${S3_SECRET}" \
                  --header 'Host: s3.us.archive.org' \
                  --upload-file "${DATA}/tmp.$$.zip" \
                  "http://s3.us.archive.org/archiveteam-tabblo-${RANGE}/tabblo-${TABBLO_ID8}.zip" \
                  > /dev/null
        do
          echo "Upload error. Wait and try again."
          sleep 60
        done

        echo " - Uploaded."
        mv "${DATA}/tmp.$$.zip" "${DATA}/tabblo/${TABBLO_DIR}/tabblo-${TABBLO_ID8}.zip"
        break
      else
        echo "invalid."
      fi
      tries=$(( tries - 1 ))
    done

    echo
  fi
done

rm -f "${DATA}/tmp.$$.zip"

