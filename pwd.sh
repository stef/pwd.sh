#!/usr/bin/ksh
# (c) 2013 s@ctrlc.hu
#
#  This is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
# put into ~/.pwd/.cfg
# keyid=<yourkeyid>
# salt="anti-rainbow-garbage" # this should be some random string
#
#
# bind to some window manager keys
# pwd.sh      # for getting a password
# pwd.sh a    # creating a new random password
#
# passwords are stored in hashed filenamed files, encrypted using a
# gpg public key
#
# pwd uses window titles or in case of firefox the current page url
# for indexing keys, these are hashed with a salt for their final
# directory name. Users are stored in separate files, similarily named
# using hashed names underneath their respective "site" directory.
# check out ~/.pwd after issuing a few "pwd.sh a" invocations.
#
# depends:
# apt-get install gnupg xdotool xclip suckless-tools kdialog
# (suckless-tools provides dmenu)

# if you want a private gnupg setup for pwd.sh enable this
# gpghome="--homedir ~/.pwd/gnupg"
# and generate a new storage key with (homedir should exist)
# gpg --gen-key --homedir ~/.pwd/gnupg

# how you like your passwords?
alias apg=apg -q -a1 -n 1 -m 14 -M NCL

# end of config

# use $1 to pass an alternative root-dir for the password store.
# TODO proper parameter handling someday
if [[ -n "$1" && "$1" != "a" ]]; then
    data="$1"
    shift 1
else
    data="$HOME/.pwd/"
fi
# load keyid & salt
source $data/.cfg
[[ -z "$keyid" ]] && exit 1
salt=${salt:-anti-rainbow-garbage} # this should be some random string

function xdoget {
    title="$1"
    shift 1
    printf '' | xclip -i
    sleep 0.2
    xdotool getactivewindow key $*
    retries=0
    while [[ retries -lt 3 ]]; do
        sleep 0.2
        x=$(xclip -o)
        [[ "$x" =~ ^https?:.* ]] && {
            echo $x | cut -d'/' -f1-3
            break
        }
        retries=$((retries+1))
    done
    [[ $retries -ge 3 ]] && echo "$title"
}

# get host/user passwords
[[ "$#" -eq 2 ]] && {
    { printf "$salt"; echo "$1"; } | md5sum | cut -d' ' -f1 | read hosthash
    { printf "$salt"; echo "$2"; } | md5sum | cut -d' ' -f1 | read userhash
    line=$(kdialog --password "unlock pwd" | gpg --no-use-agent --no-tty --quiet -d --passphrase-fd 0 $gpghome -d ~/.pwd/$hosthash/$userhash )
    echo -n "${line}" | cut -d"	" -f2 | xclip -i
    exit 0
}

# find out title/url
# TODO maybe also detect chromium, uzbl, luakit, etc?
title=$(xdotool getactivewindow getwindowname | sed -e 's/^ *//g;s/ *$//g')
case $title in
    *Pentadactyl) title="$(xdoget "$title" Escape y)"; wintype=dactyl; break;;
    *Iceweasel|*Firefox) title="$(xdoget "$title" Escape ctrl+l ctrl+a ctrl+c)"; wintype=firefox; break;;
esac

# get hash of title/url
{ printf "$salt"; echo "$title"; } | md5sum | cut -d' ' -f1 | read hash

# add a new random password with the current window
[[ "$1" == "a" ]] && {
    pwd=$(apg)
    user=$(kdialog --inputbox "user")
    { printf "$salt"; echo "$user"; } | md5sum | cut -d' ' -f1 | read userhash
    mkdir -p ~/.pwd/$hash
    [[ -f ~/.pwd/$hash/$userhash ]] && mv ~/.pwd/$hash/$userhash ~/.pwd/$hash/$userhash.$(date +%s)
    echo -n "$user	$pwd" | gpg --no-use-agent --yes --batch --no-tty --quiet $gpghome --encrypt --encrypt-to $keyid -r $keyid >~/.pwd/$hash/$userhash
    echo -n "$pass" | xclip -i
    exit 0
}

# query all stored passwords for the current active window
#echo "key=$title" >>~/.pwd/log
[[ -d ~/.pwd/$hash ]] || exit 1 # no such host/label available

pass="$(kdialog --password 'unlock pwd')"
for key in ~/.pwd/$hash/* ; do
    # todo adapt
    line=$(echo "$pass" | gpg --no-use-agent --no-tty --quiet --passphrase-fd 0 $gpghome -d $key )
    user="$(echo "${line}" | cut -d"	" -f1)"
    echo "$user"
    sleep 0.2
done | dmenu | read user

[[ -n "$user" ]] && {
    { printf "$salt"; echo "$user"; } | md5sum | cut -d' ' -f1 | read userhash
    line=$(echo "$pass" | gpg --no-use-agent --no-tty --quiet --passphrase-fd 0 $gpghome -d ~/.pwd/$hash/$userhash )
    echo -n "${line}" | cut -d"	" -f2 | xclip -i
    [[ "$wintype" == "dactyl" ]] && {
        xdotool getactivewindow key g i ctrl+u
        xdotool getactivewindow type "$user"
        xdotool getactivewindow key Tab
    }
}
