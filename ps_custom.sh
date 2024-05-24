#!/bin/bash
function get_pid {
    echo $(cat "$1" | awk '{print $1}')
}

function get_tty {
    term=$(cat "$1" | awk '{print $7}')
    if [[ ($term -ge 1024) && ($term -le 2048) ]]
    then
        ((tty=term-1024))
        echo "tty/$tty"
    fi
    if [[ ($term -ge 34816) && ($term -le 35840) ]]
    then
        ((pts=term-34816))
        echo "pts/$pts"
    fi
}

function get_state {
    echo $(cat "$1" | sed -e 's/(.*)//' | awk '{print $2}')
}

function get_cmd_sys {
    echo $((tr -d '\0' </$1) | awk '{print $1}') 
}

function get_cmd_kern {
    echo $(cat "$1" | awk '{print $2}' | sed -e 'y/()/[]/')
}

function is_vsz_rss {
    vsz=$(cat "$1" | awk '{print $23}')
    rss=$(cat "$1" | awk '{print $24}')
    ((total=vsz+rss))
    echo $total
}

function get_time {
    utime=$(cat $1 | awk '{print $14}')
    cutime=$(cat $1 | awk '{print $16}')
    ((total_sec=(utime+cutime)/100))
    ((minutes=total_sec/60 % 60))
    ((seconds=total_sec % 60))
    printf -v total '%2d:%02d' $minutes $seconds
    echo $total 
}

for directory in $(ls /proc)
do
    if [[ ( -d /proc/$directory ) && ( $directory =~ ^[0-9]+$ ) ]]
    then
        if [[ $(is_vsz_rss /proc/$directory/stat) -eq 0 ]]
        then
            cmd=$(get_cmd_kern /proc/$directory/stat)
        else
            cmd=$(get_cmd_sys /proc/$directory/cmdline)
        fi
        pid=$(get_pid /proc/$directory/stat)
        tty=$(get_tty /proc/$directory/stat)
        state=$(get_state /proc/$directory/stat)
        time_=$(get_time /proc/$directory/stat)
    fi
    total+=$pid'\t'$tty'\t'$state'\t'$time_'\t'$cmd'\n';
done
echo -e "PID\tTTY\tSTAT\tTIME\tCOMMAND"
echo -en "$total" | sort -g
exit 0
