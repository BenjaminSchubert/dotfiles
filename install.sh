#!/bin/sh

CWD="$(realpath $(dirname "$0"))"

mkdir -p ~/.config/git ~/.ssh/config.d

for file in \
        .bashrc \
        .config/git/config \
        .config/git/ignore\
        .ssh/config \
        .tmux.conf \
        .tmux-status.sh \
        .vimrc \
; do
    ln -fs "${CWD}/${file}" "${HOME}/${file}"
done
