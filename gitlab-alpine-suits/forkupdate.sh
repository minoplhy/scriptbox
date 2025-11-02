#!/bin/bash

#       forkupdate.sh
#   -- a convenient script for handling alpine repos updating tasks --
#
#   usage: ./forkupdate.sh
#   arguments: --dir
#
#   Example: bash forkupdate.sh --dir "/root/aports" 

source .env

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            GIT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

panic() {
    local msg="$1"
    printf "PANIC: $msg\n"
    exit 1
}

if [[ ! -n "$GIT_DIR" ]]; then
    panic "--dir is not passthrough"
fi

# cd to target directory
cd "$GIT_DIR"

git checkout "$MAIN_BRANCH"
git pull $REPOSITORY_SRC
git push $REPOSITORY_FORK "$MAIN_BRANCH"