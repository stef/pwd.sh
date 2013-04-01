#!/usr/bin/ksh
# (c) 2013 s@ctrlc.hu
#
#  This is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
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
# apt-get install gnupg xdotool xclip gpg-agent suckless-tools kdialog pinentry-gtk-2 apg
# (suckless-tools provides dmenu)
#
# you need to config gpg a bit:
#     personal-digest-preferences SHA512
#     cert-digest-algo SHA512
#     require-secmem
#     use-agent
#
#and also ~/pwd/gnupg/gpg-agent.conf needs some contents:
#     enable-ssh-support
#     pinentry-program /usr/bin/pinentry-gtk-2
#     no-grab

# if you want a private gnupg setup for pwd.sh enable this
#gpghome="--homedir ~/.pwd/gnupg"

# how you like your passwords?
alias apg=apg -q -a1 -n 1 -m 14 -M NCL

# generate a new storage key with (homedir should exist)
# new database gpg --gen-key --homedir ~/.pwd/gnupg
keyid=0xDEADBEEF # this is you keyid for your "database" encryption key

salt="anti-rainbow-technology" # this should be some random string

# end of config

# gpg-agent is buggy with 4K keys on cryptosticks, so we disable it:
[[ -n "$GPG_AGENT_INFO" ]] && {
    export OLD_GPGAGENT="$GPG_AGENT_INFO"
    unset GPG_AGENT_INFO
}

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

# init gpg-agent
[[ -f "${HOME}/.gpg-agent-info" ]] && {
    . "${HOME}/.gpg-agent-info"
    export GPG_AGENT_INFO
    export SSH_AUTH_SOCK
}

[[ -z "$GPG_AGENT_INFO" || ! -r ${GPG_AGENT_INFO%%:*} ]] &&
    eval $(gpg-agent --daemon --write-env-file "${HOME}/.gpg-agent-info")

[[ "$#" -eq 2 ]] && {
    { printf "$salt"; echo "$1"; } | md5sum | cut -d' ' -f1 | read hosthash
    { printf "$salt"; echo "$2"; } | md5sum | cut -d' ' -f1 | read userhash
    line=$(kdialog --password "unlock pwd" | gpg --no-tty --quiet -d --passphrase-fd 0 $gpghome -d ~/.pwd/$hosthash/$userhash )
    printf "${line}" | cut -d"	" -f2 | xclip -i
    exit 0
}

# find out title/url
# TODO maybe also detect chromium, etc?
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
    printf "$user\t$pwd" | gpg --yes --batch --no-tty --quiet $gpghome --encrypt --encrypt-to $keyid -r $keyid >~/.pwd/$hash/$userhash
    printf "$pass" | xclip -i
    exit 0
}

# query all stored passwords for the current active window
echo "key=$title" >~/.pwd/log
[[ -d ~/.pwd/$hash ]] || exit 1 # no such host/label available

pass="$(kdialog --password 'unlock pwd')"
for key in ~/.pwd/$hash/* ; do
    # todo adapt
    line=$(echo "$pass" | gpg --no-tty --quiet --passphrase-fd 0 $gpghome -d $key )
    user="$( echo "${line}" | cut -d"	" -f1 )"
    echo "$user"
    sleep 0.2
done | dmenu | read user

[[ -n "$user" ]] && {
    { printf "$salt"; echo "$user"; } | md5sum | cut -d' ' -f1 | read userhash
    echo "pass=$pass"
    line=$(echo "$pass" | gpg --no-tty --quiet --passphrase-fd 0 $gpghome -d ~/.pwd/$hash/$userhash )
    echo "${line}" | cut -d"	" -f2 | xclip -i
    [[ "$wintype" == "dactyl" ]] && {
        xdotool getactivewindow key g i ctrl+u
        xdotool getactivewindow type "$user"
        xdotool getactivewindow key Tab
    }
}

# restore gpg-agent if it was running
[[ -n "$OLD_GPGAGENT" ]] && {
    export GPG_AGENT_INFO="$OLD_GPGAGENT"
    unset OLD_GPGAGENT
}
