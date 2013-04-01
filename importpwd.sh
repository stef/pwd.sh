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

# use the firefox password-export addon to feed this script.
# invoke with
# cat password-export | fgrep '<entry host="' | importpwd.sh <keyid> | tee ~/.pwd/import.log

# put into ~/.pwd/.cfg
# keyid=0xDEADBEEF # this is you keyid for your "database" encryption key
# salt="anti-rainbow-technology" # this should be some random string

data=${1:-$HOME/.pwd/}
source $data/.cfg

[[ -z "$keyid" ]] && exit 1
salt=${salt:-anti-rainbow-garbage} # this should be some random string

while read line; do
    host=$(echo "$line" | sed 's/.* host="\(.*\)" user=".*/\1/')
    user=$(echo "$line" | sed 's/.* user="\(.*\)" password=".*/\1/')
    pass=$(echo "$line" | sed 's/.* password="\(.*\)" formSubmitURL=".*/\1/')
    # get hash of title/url
    { echo -n "$salt"; echo "$host"; } | md5sum | cut -d' ' -f1 | read hosthash
    { echo -n "$salt"; echo "$user"; } | md5sum | cut -d' ' -f1 | read userhash
    mkdir -p $data/$hosthash
    [[ -f $data/$hash/$userhash ]] && mv $data/$hash/$userhash $data/$hash/$userhash.$(date +%s)
    echo "importing $user for $host to $data/$hosthash/$userhash"
    echo -n "$user	$pass" | gpg --no-use-agent --yes --batch --no-tty --quiet $gpghome --encrypt -r $keyid >$data/$hosthash/$userhash
done
