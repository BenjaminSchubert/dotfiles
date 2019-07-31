#!/usr/bin/env bash

BG1="colour232"
BG2="colour235"
BG3="colour238"
BG4="colour241"
BG5="colour244"

BAD="colour196"
NEUTRAL="colour231"
GOOD="colour76"


__batteries() {
    local batteries
    local battery_status=" "

    batteries=$(upower -e | grep 'BAT')

    for battery in ${batteries}; do
        if [ "$(upower -i "${battery}" | grep -E "state" | tr -s " " | cut -d " " -f 3)" == "charging" ]; then
            battery_status+="#[fg=${GOOD}]"
        else
            battery_status+="#[fg=${BAD}]"
        fi
        battery_status+=$(upower -i "${battery}" | grep -E "percentage" | tr -s " " | cut -d " " -f 3)
        battery_status+=" "
    done

    echo "${battery_status}"
}


__cpu() {
    local total_cpus
    local cpu_info
    local cpu_5m

    total_cpus=$(nproc --all)
    cpu_info=$(cut -d" " -f1-3 < /proc/loadavg)
    cpu_5m=$(cut -d " " -f 2 <<< "${cpu_info}")
    cpu_5m=${cpu_5m%.*}

    if [[ ${cpu_5m} -ge ${total_cpus} ]]; then
        local COLOR=${BAD}
    elif [ "${cpu_5m}" -ge $((total_cpus / 2)) ]; then
        local COLOR=${NEUTRAL}
    else
        local COLOR=${GOOD}
    fi

    echo "#[fg=${COLOR}] ${cpu_info} "
}


__memory() {
    local free_status
    local used_memory
    local used_swap
    local status=""

    free_status=$(free)
    used_memory=$(awk '/Mem/{printf("%.d"), $3/$2*100}' <<< "${free_status}")
    used_swap=$(awk '/Swap/{printf("%.d"), $3/$2*100}' <<< "${free_status}")

    if [ ! "${used_swap}" ]; then
        used_swap=0
    fi

    for entry in ${used_memory} ${used_swap}; do
        if [[ ${entry} -ge 75 ]]; then
            local COLOR=${BAD}
        elif [[ ${entry} -ge 25 ]]; then
            local COLOR=${NEUTRAL}
        else
            local COLOR=${GOOD}
        fi

        status+="#[fg=${COLOR}] ${entry}%"
    done

    echo "${status} "
}


hour_status="#[fg=${NEUTRAL}] $(date +%k:%M)"
date_status="#[fg=${NEUTRAL}] $(date +%d/%m/%y) "

status="#[fg=${BG5}]#[bg=${BG5}]$(__cpu)"
status+="#[fg=${BG4}]#[bg=${BG4}]$(__memory)"
status+="#[fg=${BG3}]#[bg=${BG3}]$(__batteries)"
status+="#[fg=${BG2}]#[bg=${BG2}]${date_status}"
status+="#[fg=${BG1}]#[bg=${BG1}]${hour_status}"
echo "${status}"

