#!/usr/bin/env bash

if [[ $- != *i* ]]; then
    return
fi

if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi


RESET="\\[\\e[0m\\]"
BOLD="\\[\\e[1m\\]"

RED="\\[\\e[31m\\]"
GREEN="\\[\\e[32m\\]"
YELLOW="\\[\\e[33m\\]"
BLUE="\\[\\e[34m\\]"
MAGENTA="\\[\\e[35m\\]"
WHITE="\\[\\e[97m\\]"


####################
## PROMPT COMMAND ##
####################

__git_status() {
    local status

    status="${YELLOW}$(basename "$(git rev-parse --show-toplevel)")${BLUE}@"

    if ! branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"; then
        status+="${RED}INVALID"
    else
        status+="${YELLOW}${branch}"
    fi

    git_path=$(git rev-parse --absolute-git-dir)
    if [ -d "${git_path}/rebase-apply" ]; then
        status+="${BLUE}(${RED}REBASING${BLUE})"
    elif [ -f "${git_path}/MERGE_HEAD" ]; then
        status+="${BLUE}(${RED}MERGING${BLUE})"
    fi

    __modified() {
        changed=$(grep -c "${2}" <<< "${1}" | sed "s/[ \\t]*//g")
        if [ "${changed}" -ne 0 ]; then
            echo "$3$4$changed${BLUE};"
        fi
    }

    changed_files="$(git status --porcelain)"
    local changes=""
    # staged
    changes+=$(__modified "${changed_files}" '^A' "${GREEN}" +)
    # untracked
    changes+=$(__modified "${changed_files}" '^??' "${YELLOW}" -)
    # changed but unstaged
    changes+=$(__modified "${changed_files}" '^.M' "${RED}" \*)

    if [ ${#changes} -ne 0 ]; then
        status+="${BLUE}[${changes%?}${BLUE}]"
    fi

    echo "${status}"
}


__retcode_status() {
    # Set last command return code
    local last_successful=${BLUE}

    for code in "${@}"; do
        if [ "${code}" -ne 0 ]; then
            return_status+="${RED}"
            last_successful="${RED}"
        else
            return_status+="${BLUE}"
        fi
        return_status+="${code} "
    done

    echo "${last_successful}(${return_status%?}${last_successful})"
}


__venv_status() {
    if [ "${VIRTUAL_ENV}" ]; then
        echo "${BOLD}${MAGENTA}($(basename "${VIRTUAL_ENV}"))${RESET} "
    fi
}


__prompt_command() {
    local RETURN_CODES=("${PIPESTATUS[@]}")

    local git_status=""

    # Set git status
    if git rev-parse --is-inside-work-tree >/dev/null 2>/dev/null; then
        git_status="$(__git_status)${BLUE}:"
    fi

    PS1="$(__venv_status)${BOLD}${GREEN}\\u${BLUE}@${GREEN}\\h${BLUE}:${git_status} ${WHITE}\\W $(__retcode_status "${RETURN_CODES[@]}") ${BLUE}\$${RESET} "
}


export PROMPT_COMMAND=__prompt_command

export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh"

export EDITOR="/usr/bin/vim"
export VISUAL="/usr/bin/vim"

export SUDO_EDITOR="/usr/bin/vim"
export SUDO_VISUAL="/usr/bin/vim"
export SUDO_PATH="/usr/sbin:/sbin"

export LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=01;05;37;41:mi=01;05;37;41:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lz=01;31:*.xz=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.axv=01;35:*.anx=01;35:*.ogv=01;35:*.ogx=01;35:*.pdf=00;32:*.ps=00;32:*.txt=00;32:*.patch=00;32:*.diff=00;32:*.log=00;32:*.tex=00;32:*.doc=00;32:*.aac=00;36:*.au=00;36:*.flac=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.axa=00;36:*.oga=00;36:*.spx=00;36:*.xspf=00;36:'

export HISTCONTROL="erasedups"

alias clip="xclip -sel clip <"
alias grep="grep --color=auto --exclude-dir={.bzr,.cvs,.hg,.git,.svn}"

if ls --color >/dev/null 2>/dev/null; then
    alias ls="ls --color --ignore=lost+found"
fi

if [ -e /usr/share/terminfo/x/xterm-256color ]; then
    export TERM='xterm-256color'
else
    export TERM='xterm-color'
fi

if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi

if [ -f ~/.bashrc.local ]; then
    . ~/.bashrc.local
fi


############
## Python ##
############

if [ -f /usr/share/virtualenvwrapper/virtualenvwrapper_lazy.sh ]; then
    export WORKON_HOME=~/.virtualenvs/
    . /usr/share/virtualenvwrapper/virtualenvwrapper_lazy.sh
fi
