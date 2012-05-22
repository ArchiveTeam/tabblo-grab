#!/bin/bash
# Script for downloading the data of one Tabblo.com user.
#
# Usage:   dld-tabblo-user.sh ${USERNAME}
#

VERSION="20120522.01"

# this script needs wget-warc-lua, which you can find on the ArchiveTeam wiki.

USER_AGENT="Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/533.20.25 (KHTML, like Gecko) Version/5.0.4 Safari/533.20.27"

if [ -z $DATA_DIR ]
then
  DATA_DIR=data
fi

username="$1"
prefix_dir="$DATA_DIR/${username:0:1}/${username:0:2}/${username:0:3}"
user_dir="$prefix_dir/$username"

if [ -d "$prefix_dir" ] && [ ! -z "$( find "$prefix_dir/" -maxdepth 1 -type f -name "tabblo-$username-*.warc.gz" )" ]
then
  echo "Already downloaded ${username}"
  exit 0
fi

rm -rf "${user_dir}"
mkdir -p "${user_dir}/files"

echo -n "Downloading ${username}... "

t=$( date -u +'%Y%m%d-%H%M%S' )
warc_file_base="tabblo-$username-$t"

./wget-warc-lua \
  -U "$USER_AGENT" \
  -nv \
  --lua-script="tabblo.lua" \
  --page-requisites \
  --span-hosts \
  -e "robots=off" \
  "http://www.tabblo.com/studio/person/$1" \
  --directory-prefix="${user_dir}/files" \
  --warc-file="${user_dir}/${warc_file_base}" \
  -o "${user_dir}/wget.log" \
  --warc-header="operator: Archive Team" \
  --warc-header="tabblo-dld-script-version: ${VERSION}" \
  --warc-header="tabblo: ${username}"

result=$?

if [ $result -ne 0 ] && [ $result -ne 6 ] && [ $result -ne 8 ]
then
  echo "ERROR ($result)."
  exit 1
fi

mv "$user_dir/$warc_file_base.warc.gz" "$prefix_dir/$warc_file_base.warc.gz"
rm -rf "$user_dir"

du -hs "$prefix_dir/$warc_file_base.warc.gz"

exit 0

