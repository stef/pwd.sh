#!/usr/bin/ksh
# (c) 2013 s@ctrlc.hu
#
#  This is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.

# warning! i accidentally clobbered the original version of this. this
# is mostly a quick rewrite from memory. please test this before using
# it live.

# invoke with
# cat password-export | fgrep '<entry host="' | importpwd.sh <keyid> | tee ~/.pwd/import.log

keyid=${1:-0xDEADBEEF} # this is you keyid for your "database" encryption key
salt="anti-rainbow-technology" # this should be some random string
data=${2:-$HOME/.pwd/}

while read line; do
    host=$(echo $line | sed 's/.* host="\(.*\)" user=".*/\1/')
    user=$(echo $line | sed 's/.* user="\(.*\)" password=".*/\1/')
    pass=$(echo $line | sed 's/.* password="\(.*\)" formSubmitURL=".*/\1/')
    # get hash of title/url
    { printf "$salt"; echo "$host"; } | md5sum | cut -d' ' -f1 | read hosthash
    { printf "$salt"; echo "$user"; } | md5sum | cut -d' ' -f1 | read userhash
    mkdir -p $data/$hosthash
    [[ -f $data/$hash/$userhash ]] && mv $data/$hash/$userhash $data/$hash/$userhash.$(date +%s)
    echo "importing $user for $host to $data/$hosthash/$userhash"
    printf "$user\t$pass" | gpg --no-use-agent --yes --batch --no-tty --quiet $gpghome --encrypt -r $keyid >$data/$hosthash/$userhash
done
