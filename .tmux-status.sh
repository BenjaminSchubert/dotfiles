#!/usr/bin/env bash

RED="#[fg=red]"
WHITE="#[fg=white]"
GREEN="#[fg=green]"
BLUE="#[fg=blue]"

SEP="${BLUE} | "

__batteries() {
    local batteries
    local battery_status=""

    batteries=$(upower -e | grep 'BAT')

    for battery in ${batteries}; do
        status=$(upower -i "${battery}" | grep -E "state" | tr -s " " | cut -d " " -f 3)

        if [ "${status}" == "charging" ] || [ "${status}" == "fully-charged" ]; then
            battery_status+="${GREEN}"
        else
            battery_status+="${RED}"
        fi
        battery_status+=$(upower -i "${battery}" | grep -E "percentage" | tr -s " " | cut -d " " -f 3)
        battery_status+=" "
    done

    echo "${battery_status::-1}"
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
        local COLOR=${RED}
    elif [ "${cpu_5m}" -ge $((total_cpus / 2)) ]; then
        local COLOR=${WHITE}
    else
        local COLOR=${GREEN}
    fi

    echo "${COLOR}${cpu_info}"
}


__memory() {
    local free_status
    local used_memory
    local used_swap
    local status=""

    free_status=$(free)
    used_memory=$(awk '/Mem/{printf "%.f", $3/$2*100}' <<< "${free_status}")
    used_swap=$(awk '/Swap/{printf "%.f", $3/$2*100}' <<< "${free_status}")

    if [ "${used_swap}" == "-nan" ]; then
        used_swap=0
    fi

    for entry in ${used_memory} ${used_swap}; do
        if [[ ${entry} -ge 75 ]]; then
            local COLOR=${RED}
        elif [[ ${entry} -ge 25 ]]; then
            local COLOR=${WHITE}
        else
            local COLOR=${GREEN}
        fi

        status+="${COLOR}${entry}% "
    done

    echo "${status::-1}"
}


status="${BLUE}L:$(__cpu)${SEP}"
status+="M:$(__memory)${SEP}"

if batteries=$(__batteries); then
    status+="B:$(__batteries)${SEP}"
fi

status+="${WHITE}$(date +%d/%m/%y-%k:%M)"
echo "${status}"

