#!/bin/bash

#       update.sh
#   -- a convenient script for handling alpine repos updating tasks --
#
#   usage: ./update.sh
#   arguments: --dir --token --src-dir
#
#   Example: bash update.sh bash update.sh --dir "./aports" --src-dir "$(realpath ../alpine-cache)"

source .env

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            GIT_DIR="$2"
            shift 2
            ;;
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --src-dir)
            SRC_DIR="$2"
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

error() {
    local msg="$1"
    printf "error: $msg\n"
}

info() {
    local msg="$1"
    printf "info: $msg\n"
}

commit() {
    local PACKAGE="$1"
    local VERSION="$2"
    git add .
    git commit -S -m "$PACKAGE: upgrade to $VERSION"
}

reset() {
    local BRANCH="$1"
    git reset --hard
    git checkout $BRANCH
}

s_curl() {
    if [[ -n "$TOKEN" ]]; then
        curl -H "Authorization: Bearer $TOKEN" "$@"
    else
        curl "$@"
    fi
}

cd "$GIT_DIR" || panic "GIT_DIR location -> '$GIT_DIR' does not exist!"

if [[ ! -n "$GIT_DIR" ]]; then panic "--dir is not passthrough"; fi
if [[ ! -n "$SRC_DIR" ]]; then panic "--src-dir is not passthrough"; fi

PACKAGE=($PACKAGE)

for i in "${PACKAGE[@]}"; do 
    info "$i"
    git checkout "$MAIN_BRANCH"

    cd "$GIT_DIR"/"$i" || panic "file: '$GIT_DIR'/'$i' does not exist!"

    NAME=$(grep '^pkgname=' APKBUILD | cut -d'=' -f2)
    VERSION=$(grep '^pkgver=' APKBUILD | cut -d'=' -f2)
    RELEASE_N=$(grep '^pkgrel=' APKBUILD | cut -d'=' -f2)
    SOURCE=($(perl -0777 -ne 'while (/source="(.*?)"/sg) { print "$1\n" }' APKBUILD))
    TARGET_SOURCE=$(echo ${SOURCE[0]} | grep -oP 'https?://\S+')
    info "$NAME $VERSION $RELEASE_N"
    info "Source: $TARGET_SOURCE"

    if [[ "$TARGET_SOURCE" == *"github.com"* ]]; then
        user_repo=$(echo "$TARGET_SOURCE" | sed 's|https://github.com/\([^/]*\)/\([^/]*\).*|\1/\2|')
        GITHUB=true
        info "GitHub Repo: $user_repo"
    else
        GITHUB=false
    fi
    
    if [[ $GITHUB == true ]]; then
        case $NAME in
            *)
                REPO_VERSION=$(s_curl -s "https://api.github.com/repos/$user_repo/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
                ;;
        esac
        if [[ $VERSION != $REPO_VERSION ]]; then
            new_branch="$NAME"-"$REPO_VERSION"
            git branch "$new_branch"
            git checkout "$new_branch"
            sed -i "s/^pkgver=.*$/pkgver=$REPO_VERSION/" "APKBUILD"
            if [[ $RELEASE_N != 0 ]]; then
                sed -i "s/^pkgrel=.*$/pkgrel=0/" "APKBUILD"
            fi
            ARGS=()
            if [[ -n "$SRC_DIR" ]]; then
                ARGS+=(-s $SRC_DIR )
            fi
            ARGS+=(checksum)
            abuild "${ARGS[@]}"
            info "$NAME: pkgver updated to $REPO_VERSION in APKBUILD"

            # Check Diff
            while :
            do
                git diff
                read -p "is update ok ? Y/N" ok
                case $ok in
                    Y)
                        commit "$i" "$REPO_VERSION"
                        git push "$REPOSITORY_FORK" "$new_branch"
                        break
                    ;;
                    N)
                        reset "$MAIN_BRANCH"
                        break
                    ;;
                    *)
                    ;;
                esac 
            done
        elif [[ $VERSION == $REPO_VERSION ]]; then
            info "$NAME: pkgver is up-to-date"
        else
            error "$NAME: Internal Error!"
        fi
    fi
    info "========================================================"
done