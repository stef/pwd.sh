#!/usr/bin/env bash
# (c) 2013 s@ctrlc.hu, asciimoo@faszkorbacs.hu, mail@crazypotato.tk
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
function pwgen { /usr/bin/apg -q -a1 -n 1 -m 14 -M NCL; }

# ssh-askpass path fix for ARCH linux
if [[ -x "/usr/lib/ssh/ssh-askpass" ]]; then
    function pwprompt { /usr/lib/ssh/ssh-askpass; }
else
    function pwprompt { /usr/bin/ssh-askpass; }
fi

# end of config

function userprompt {
    echo -e "$USER\n$(/usr/bin/xclip -o)" | /usr/bin/dmenu -p 'user>'
}

function xdoget {
    title="$1"
    shift 1
    echo -n '' | /usr/bin/xclip -i
    sleep 0.2
    /usr/bin/xdotool key --window $windowid $*
    retries=0
    while [[ retries -lt 3 ]]; do
        sleep 0.2
        x=$(/usr/bin/xclip -o)
        [[ "$x" =~ ^https?:.* ]] && {
            echo $x | cut -d'/' -f1-3
            break
        }
        retries=$((retries+1))
    done
    [[ $retries -ge 3 ]] && echo "$title"
}

function noagent {
    # gpg-agent is buggy with 4K keys on cryptosticks, so we disable it:
    [[ -n "$GPG_AGENT_INFO" ]] && {
        export OLD_GPGAGENT="$GPG_AGENT_INFO"
        unset GPG_AGENT_INFO
    }
}

function reagent {
    # restore gpg-agent if it was running
    [[ -n "$OLD_GPGAGENT" ]] && {
        export GPG_AGENT_INFO="$OLD_GPGAGENT"
        unset OLD_GPGAGENT
    }
}

# use $1 to pass an alternative root-dir for the password store.
# TODO proper parameter handling someday
if [[ -n "$1" && -f "$1/.cfg" ]]; then
    data="$1"
    shift 1
else
    data="$HOME/.pwd"
fi
# load keyid & salt
source $data/.cfg
[[ -z "$keyid" ]] && exit 1
salt=${salt:-anti-rainbow-garbage} # this should be some random string

# if $1 = host and $2 = user get host/user passwords
# Todo fix parameter handling
[[ "$#" -eq 3 ]] && {
    hosthash="$( { echo -n "$salt"; echo "$1"; } | /usr/bin/md5sum | cut -d' ' -f1 )"
    userhash="$( { echo -n "$salt"; echo "$2"; } | /usr/bin/md5sum | cut -d' ' -f1 )"
    noagent
    line=$(pwprompt | /usr/bin/gpg --batch --no-tty --quiet -d --passphrase-fd 0 $gpghome -d ~/.pwd/$hosthash/$userhash )
    reagent
    echo -n "${line}" | cut -d"	" -f2 | /usr/bin/xclip -i -selection clipboard
    exit 0
}

# find out title/url of active window
windowid=$(/usr/bin/xdotool getactivewindow)
title=$(/usr/bin/xdotool getwindowname $windowid | /bin/sed -e 's/^ *//g;s/ *$//g')
case $title in
    *Pentadactyl|*Vimperator) title="$(xdoget "$title" Escape y)"; wintype=dactyl;;
    *Iceweasel|*Firefox) title="$(xdoget "$title" Escape ctrl+l ctrl+a ctrl+c)"; wintype=firefox;;
    *Chromium) title="$(xdoget "$title" Escape ctrl+l ctrl+a ctrl+c)"; wintype=chromium;;
    *Uzbl\ browser*) title="$(xdoget "title" Escape y u)"; wintype=uzbl;;
    luakit*) title="$(xdoget "title" shift+o Home ctrl+Right Right ctrl+shift+End ctrl+c Escape)"; wintype=luakit;;
esac
# get hash of title/url
hash="$( { echo -n "$salt"; echo "$title"; } | /usr/bin/md5sum | cut -d' ' -f1 )"

# if invoked with $1 = a
# add a new random password with the current window
[[ "$1" == "a" ]] && {
    pwd=$(pwgen)
    user=$(userprompt)
    userhash="$( { echo -n "$salt"; echo "$user"; } | /usr/bin/md5sum | cut -d' ' -f1 )"
    mkdir -p ~/.pwd/$hash
    [[ -f ~/.pwd/$hash/$userhash ]] && mv ~/.pwd/$hash/$userhash ~/.pwd/$hash/$userhash.$(date +%s)
    echo -n "$user	$pwd" | /usr/bin/gpg --command-file <(pwprompt) --yes --no-tty --quiet $gpghome --sign --local-user $keyid --encrypt -r $keyid >~/.pwd/$hash/$userhash
    echo -n "$pwd" | /usr/bin/xclip -i -selection clipboard
    exit 0
}

# query all stored passwords for the current active window
#echo "key=$title" >>~/.pwd/log
[[ -d ~/.pwd/$hash ]] || exit 1 # no such host/label available

noagent
pass="$(pwprompt)"
user="$(for key in ~/.pwd/$hash/* ; do
            fname="${key##*/}"; [[ "$fname" =~ .*\..* ]] && continue
            # todo adapt
            line=$(echo "$pass" | /usr/bin/gpg --batch --no-tty --quiet --passphrase-fd 0 $gpghome -d $key )
            user="$(echo "${line}" | cut -d"	" -f1)"
            echo "$user"
            sleep 0.2
        done | /usr/bin/dmenu)"

[[ -n "$user" ]] && {
    userhash="$( { echo -n "$salt"; echo "$user"; } | /usr/bin/md5sum | cut -d' ' -f1)"
    line=$(echo "$pass" | /usr/bin/gpg --batch --no-tty --quiet --passphrase-fd 0 $gpghome -d ~/.pwd/$hash/$userhash )
    echo -n "${line}" | cut -d"	" -f2 | /usr/bin/xclip -i -selection clipboard
    [[ -n "$wintype" ]] && {
        case $wintype in
            dactyl) /usr/bin/xdotool key --window $windowid Escape g i ctrl+u ;;
            luakit) /usr/bin/xdotool key --window $windowid Escape g i Tab ctrl+u ;;
            firefox) /usr/bin/xdotool key --window $windowid Tab Tab Tab ;;
            chromium) /usr/bin/xdotool key --window $windowid Tab ;;
        esac
        /usr/bin/xdotool type --window $windowid "$user"
        /usr/bin/xdotool key --window $windowid Tab
    }
}
reagent
