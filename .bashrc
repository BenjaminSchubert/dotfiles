#!/usr/bin/env bash

if [[ $- != *i* ]]; then
    return
fi

if [ -f /etc/bashrc ]; then
    # don't follow source when validating with shellcheck
    # shellcheck disable=SC1091
    . /etc/bashrc
fi

# ASCII color codes in use here
RESET="\\e[0m"
BOLD="\\e[1m"
RED="\\e[31m"
GREEN="\\e[32m"
YELLOW="\\e[33m"
BLUE="\\e[34m"
MAGENTA="\\e[35m"
WHITE="\\e[97m"

# Same colors but wrapped for use in the bash prompt
B_RESET="\\[${RESET}\\]"
B_BOLD="\\[${BOLD}\\]"
B_RED="\\[${RED}\\]"
B_GREEN="\\[${GREEN}\\]"
B_YELLOW="\\[${YELLOW}\\]"
B_BLUE="\\[${BLUE}\\]"
B_MAGENTA="\\[${MAGENTA}\\]"
B_WHITE="\\[${WHITE}\\]"


####################
##   UTILITIES    ##
####################

_timeout() {
    (
        set +b;

        "${@:2}" &
        pid=$!

        (sleep "$1" && kill -15 $pid) &
        watcher=$!

        wait $pid 2>/dev/null
        retcode=$?

        if [ $retcode -eq 0 ]; then
            kill -15 $watcher
        fi

        exit $retcode
    )
}

_log_info() {
    echo -e "${BLUE}${1}${RESET}" >&2
}

_log_error() {
    echo -e "${RED}${1}${RESET}" >&2
}


##############
## Commands ##
##############
export PROJECTS_HOME="${HOME}/projects"

# Clone a git repository following a set structure
gg() {
    if [ "${#}" -ge 2 ]; then
        _log_error "Only support 0 argument if in the right directory, or 1 to precise a path."
        return 1
    fi

    local clone_uri="${1}"

    # Based on https://www.rfc-editor.org/rfc/rfc3986#appendix-B, but remove
    # non supported groups

    # group 1, the protocol with :, e.g. https: or git+ssh:
    local uri_protocol="([^:/?#]+:)"
    # group 2, the hostname starting with //, and containing the port
    # group 3, the hostname
    local uri_hostinfo="(//([^/?#]*))"
    # group 4, the path
    local uri_path="([^?#]*)"
    local re_uri="^${uri_protocol}?${uri_hostinfo}?${uri_path}"
    if ! [[ "$1" =~ $re_uri ]]; then
        _log_error "Unable to parse url"
        return 1
    fi

    local hostname="${BASH_REMATCH[3]}"
    local path="${BASH_REMATCH[4]}"

    if [ "${hostname}" == "" ]; then
        case "${PWD}" in
            "${PROJECTS_HOME}"/*)
                hostname="${PWD#"${PROJECTS_HOME}/"}"
                clone_uri="https://${hostname}/${path}"
            ;;
            *)
                _log_error "No hostname detected in ${clone_uri} and not in a subdirectory of ${PROJECTS_HOME}"
                return 1
            ;;
        esac
    fi

    local dest_path="${PROJECTS_HOME}/${hostname}/${path}"
    if [ -e "${dest_path}" ]; then
        if [ ! -d "${dest_path}" ]; then
            _log_error "Cannot clone ${clone_uri} to ${dest_path}, destination exists and is not a directory."
            return 1
        fi

        if [ -e "${dest_path}/.git" ]; then
            _log_error "Cannot clonse ${clone_uri} to ${dest_path}, destination is already a git repository."
            return 1
        fi

        _log_info "Directory ${dest_path} already exists. Initializing origin remote to ${clone_uri}"
        # We don't want to handle pushd errors
        # shellcheck disable=SC2164
        git -C "${dest_path}" init && \
            git -C "${dest_path}" remote add origin "${clone_uri}" && \
            git -C "${dest_path}" fetch && \
            pushd "${dest_path}" > /dev/null
        return $?
    fi

    _log_info "Will clone ${clone_uri} to ${dest_path}"
    # We don't want to handle pushd errors
    # shellcheck disable=SC2164
    git clone "${clone_uri}" "${dest_path}" && \
        pushd "${dest_path}" > /dev/null
    return $?
}


# Show some information about the specified git repository
_git_info() {
    print_status_if_not_empty() {
        local header="${1}"
        shift
        local entries=( "$@" )

        if [ ${#entries[@]} -ne 0 ]; then
            echo "${header}"
            for entry in "${entries[@]}"; do
                echo -e "\t${entry}"
            done
        fi
    }

    local retcode
    local cwd

    if [ "$#" -gt 1 ]; then
        echo "Illegal number of parameters: only accept 1 positional argument being the directory" >&2
        return 1
    fi

    if [ "$#" -eq 1 ]; then
        cwd=$(realpath "${1}")
        retcode=$?
        if [ ${retcode} -ne 0 ]; then
            echo "Unable to resolve directory: ${1}"
            return ${retcode}
        fi
    else
        cwd="${PWD}"
    fi

    local branches_info
    branches_info=$(git -C "${cwd}" branch --format '%(refname:short) %(upstream:short) %(upstream:track)')
    retcode=$?
    if [ ${retcode} -ne 0 ]; then
        return ${retcode}
    fi

    local branches_without_remotes=()
    local branches_with_remotes_gone=()
    local branches_unsynced=()

    IFS='
'
    for branch_info in ${branches_info}; do
        local branch=${branch_info%% *}
        local remote_and_status=${branch_info#"${branch} "}
        local remote=${remote_and_status%% *}
        local status=${remote_and_status#"${remote} "}

        if [ -z "${remote}" ]; then
            branches_without_remotes+=( "${branch}" )
            continue
        fi

        if [ -z "${status}" ]; then
            # This one is up to date, nothing to report
            continue
        fi

        if [ "${status}" == "[gone]" ]; then
            branches_with_remotes_gone+=( "${branch}")
            continue
        fi

        local status_regex='\[(ahead ([0-9]+)(, behind ([0-9]+))?)|(behind ([0-9]+))\]'
        local branch_status="${branch}"
        if [[ "${status}" =~ ${status_regex} ]]; then
            if [ -n "${BASH_REMATCH[2]}" ]; then
                branch_status+=" ${BOLD}${YELLOW}⇑${BASH_REMATCH[2]}${RESET}"
            fi
            if [ -n "${BASH_REMATCH[4]}" ]; then
                branch_status+=" ${BOLD}${MAGENTA}⇓${BASH_REMATCH[4]}${RESET}"
            fi
            if [ -n "${BASH_REMATCH[6]}" ]; then
                branch_status+=" ${BOLD}${MAGENTA}⇓${BASH_REMATCH[6]}${RESET}"
            fi

            branches_unsynced+=( "${branch_status}" )
        else
            echo "Could not extract information from git track info"
            return 1
        fi
    done

    local status
    status=$(git -C "${cwd}" status --porcelain | awk  '{a[$1]=a[$1]?a[$1]" "$2:$2;} {c[$1]=c[$1]?c[$1]+1:1;} END{for (i in a)print i, c[i], a[i];}')
    retcode=$?
    if [ ${retcode} -ne 0 ]; then
        echo "Error getting git status"
        return ${retcode}
    fi

    local unclean_files=()

    IFS='
'
    for entry in ${status}; do
        local type=${entry%% *}
        local count_and_files=${entry#* }
        local count=${count_and_files%% *}
        local files=${count_and_files#* }
        local color=${RED}
        local message

        case $type in
            A)
                message="added"
                ;;
            D)
                color=${YELLOW}
                message="deleted"
                ;;
            M)
                message="modified"
                ;;
            R)
                color=${YELLOW}
                message="renamed"
                ;;
            U)
                message="updated but unmerged"
                ;;
            ??)
                color=${YELLOW}
                message="untracked"
                ;;
            *)
                echo -e "${YELLOW}Unknown git porcelain status in ${cwd}: ${type}${RESET}" >&2
                continue
                ;;
        esac

        unclean_files+=( "${BOLD}${color}${count}${RESET} ${message} files: ${files}")
    done

    print_status_if_not_empty "The following branches do not have a remote:" "${branches_without_remotes[@]}"
    print_status_if_not_empty "The following branches' remotes don't exist anymore:" "${branches_with_remotes_gone[@]}"
    print_status_if_not_empty "The following branches differ from their remote:" "${branches_unsynced[@]}"
    print_status_if_not_empty "The following changes are not tracked:" "${unclean_files[@]}"
}

# Show information about all git repositories under ${PROJECT_HOME}
_git_info_all() {
    local retcode
    local projects
    local do_update=0

    if [ "$#" -gt 1 ]; then
        _log_error "Illegal number of parameters: only accept 1 argument: --update"
        return 1
    elif [ "$#" -eq 1 ]; then
        if [ "${1}" != "--update" ]; then
            _log_error "Unknown parameter '${1}'. Only supports --update."
            return 1
        fi
        do_update=1
    fi

    projects=$(find "${PROJECTS_HOME}" -name .git -exec dirname {} ';')
    retcode=$?
    if [ ${retcode} -ne 0 ]; then
        echo "Unable to list projects: ${projects}" >&2
        return ${retcode}
    fi

    local had_error=0

    IFS='
'

    if [ ${do_update} -eq 1 ]; then
        local status

        for project in ${projects}; do
            status=$(git -C "${project}" fetch --prune 2>&1)
            retcode=$?
            if [ ${retcode} -ne 0 ]; then
                _log_error "error fetching project: ${project}\n${RESET}${status}"
                had_error=${retcode}
            else
                _log_info "Updated ${project}"
            fi
        done
    fi

    for project in ${projects}; do
        local status
        status=$(_git_info "${project}")
        retcode=$?

        if [ ${retcode} -ne 0 ]; then
            had_error=${retcode}
            _log_error "${BOLD}${project}: could not get status${RESET}:\n${status}"
            continue
        fi

        if [ -z "${status}" ]; then
            echo -e "${GREEN}✓ ${project}${GREEN}"
        else
            echo -e "${BOLD}${RED}X${RESET} ${RED}${project}${RESET}\n${status}"
        fi
    done

    return ${had_error}
}


# And some aliases
alias git-root="cd \$(git rev-parse --show-toplevel)"
alias git-info="_git_info"
alias git-info-all="_git_info_all"

alias clip="xclip -sel clip <"
alias grep="grep --color=auto --exclude-dir={.bzr,.cvs,.hg,.git,.svn}"

if ls --color >/dev/null 2>/dev/null; then
    alias ls="ls --color --ignore=lost+found"
fi


####################
## PROMPT COMMAND ##
####################

__git_status() {
    local status

    status="${B_YELLOW}$(basename "$(git rev-parse --show-toplevel)")${B_BLUE}@"

    if ! branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"; then
        status+="${B_RED}INVALID"
    else
        status+="${B_YELLOW}${branch}"
    fi

    git_path=$(git rev-parse --absolute-git-dir)
    if [ -d "${git_path}/rebase-apply" ]; then
        status+="${B_BLUE}(${B_RED}REBASING${B_BLUE})"
    elif [ -f "${git_path}/MERGE_HEAD" ]; then
        status+="${B_BLUE}(${B_RED}MERGING${B_BLUE})"
    fi

    __modified() {
        changed=$(grep -c "${2}" <<< "${1}" | sed "s/[ \\t]*//g")
        if [ "${changed}" -ne 0 ]; then
            echo "$3$4$changed${B_BLUE};"
        fi
    }

    if ! changed_files="$(_timeout 0.1 git status --porcelain)"; then
        status+="${B_BLUE}[${B_RED}???${B_BLUE}]"
    else
        local changes=""
        # staged
        changes+=$(__modified "${changed_files}" '^A' "${B_GREEN}" +)
        # untracked
        changes+=$(__modified "${changed_files}" '^??' "${B_YELLOW}" -)
        # changed but unstaged
        changes+=$(__modified "${changed_files}" '^.M' "${B_RED}" \*)

        if [ ${#changes} -ne 0 ]; then
            status+="${B_BLUE}[${changes%?}${B_BLUE}]"
        fi
    fi

    echo "${status}"
}


__retcode_status() {
    # Set last command return code
    local last_successful=${B_BLUE}
    local return_status=""

    for code in "${@}"; do
        if [ "${code}" -ne 0 ]; then
            return_status+="${B_RED}"
            last_successful="${B_RED}"
        else
            return_status+="${B_BLUE}"
        fi
        return_status+="${code} "
    done

    echo "${last_successful}(${return_status%?}${last_successful})"
}


__venv_status() {
    if [ "${VIRTUAL_ENV}" ]; then
        echo "${B_BOLD}${B_MAGENTA}($(basename "${VIRTUAL_ENV}"))${B_RESET} "
    fi
}


__prompt_command() {
    local RETURN_CODES=("${PIPESTATUS[@]}")

    local git_status=""

    # Set git status
    if git rev-parse --is-inside-work-tree >/dev/null 2>/dev/null; then
        git_status="$(__git_status)${B_BLUE}:"
    fi

    PS1="$(__venv_status)${B_BOLD}${B_GREEN}\\u${B_BLUE}@${B_GREEN}\\h${B_BLUE}:${git_status} ${B_WHITE}\\W $(__retcode_status "${RETURN_CODES[@]}") ${B_BLUE}\$${B_RESET} "
}


export PROMPT_COMMAND=__prompt_command

export EDITOR="vim"
export VISUAL="vim"

export SUDO_EDITOR="vim"
export SUDO_VISUAL="vim"
export SUDO_PATH="/usr/sbin:/sbin"

export LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=01;05;37;41:mi=01;05;37;41:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lz=01;31:*.xz=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.axv=01;35:*.anx=01;35:*.ogv=01;35:*.ogx=01;35:*.pdf=00;32:*.ps=00;32:*.txt=00;32:*.patch=00;32:*.diff=00;32:*.log=00;32:*.tex=00;32:*.doc=00;32:*.aac=00;36:*.au=00;36:*.flac=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.axa=00;36:*.oga=00;36:*.spx=00;36:*.xspf=00;36:'

export HISTCONTROL="erasedups"

if [ -f /usr/share/bash-completion/bash_completion ]; then
    # don't follow source when validating with shellcheck
    # shellcheck disable=SC1091
    . /usr/share/bash-completion/bash_completion
fi

if [ -f ~/.bashrc.local ]; then
    # don't follow source when validating with shellcheck
    # shellcheck disable=SC1090
    . ~/.bashrc.local
fi


############
## Python ##
############

if [ -f /usr/share/virtualenvwrapper/virtualenvwrapper_lazy.sh ]; then
    export WORKON_HOME=~/.virtualenvs/
    # don't follow source when validating with shellcheck
    # shellcheck disable=SC1091
    . /usr/share/virtualenvwrapper/virtualenvwrapper_lazy.sh
else
    # This is necessary to ensure the return code of the source is not 0
    # and thus don't show 1 as startup
    :
fi
