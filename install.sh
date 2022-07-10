#!/bin/sh

CWD="$(realpath $(dirname "$0"))"

mkdir -p ~/.config/git

for file in \
        .bashrc \
        .tmux.conf \
        .tmux-status.sh \
        .vimrc \
        .config/git/config \
        .config/git/ignore\
; do
    ln -fs "${CWD}/${file}" "${HOME}/${file}"
done
