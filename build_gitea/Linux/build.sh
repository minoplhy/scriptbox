#!/bin/bash

MAKE_DIR=$(mktemp -d)
DESTINATION=~/gitea-binaries/

rm -rf $DESTINATION
mkdir -p $DESTINATION
cd $MAKE_DIR

while [ ${#} -gt 0 ]; do
    case "$1" in
        --git-tag | -v) 
            shift
            GITEA_GIT_TAG=$1
            ;;                          # Gitea Git Tag
        --golang-version | -g) 
            shift
            GO_VERSION=$1 
            ;;                          # GOLANG Version
        --nodejs-version | -n) 
            shift
            NODEJS_VERSION=$1 
            ;;                          # NodeJS Version
        --static | -s) 
            BUILD_STATIC=true 
            ;;                          # Build as Static Assets file
        *)
            ;;
    esac
    shift # Shift to next response for parsing
done

# GITEA_GIT_TAG is being process below

# Install Dependencies

sudo apt-get update && sudo apt-get install xz-utils wget git tar g++ make -y

# NodeJS
if [[ $NODEJS_VERSION == "" ]]
then
    NODEJS_VERSION=v20.11.1
fi

DISTRO=linux-x64

wget https://nodejs.org/dist/$NODEJS_VERSION/node-$NODEJS_VERSION-$DISTRO.tar.xz
sudo mkdir -p /usr/local/lib/nodejs
sudo tar -xJvf node-$NODEJS_VERSION-$DISTRO.tar.xz -C /usr/local/lib/nodejs 
export PATH=/usr/local/lib/nodejs/node-$NODEJS_VERSION-$DISTRO/bin:$PATH
. ~/.profile

# Golang
if [[ $GO_VERSION == "" ]]
then
    GO_VERSION=1.22.1
fi

sudo unlink /usr/bin/go
wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
sudo ln -s /usr/local/go/bin /usr/bin/go

# Gitea

# GIT_TAG= 
# specify the tag which gitea will build on

git clone https://github.com/go-gitea/gitea
cd gitea

if [[ -n $GITEA_GIT_TAG ]]
then
    if git show-ref $GITEA_GIT_TAG --quiet;  then
        git checkout $GITEA_GIT_TAG
    else
        echo -e "\nGIT_TAG variable doesn't match the repo tag/version. exit to prevent further issue." && exit 1 && rm -rf $MAKE_DIR
    fi
else
    echo -e "GIT_TAG variable not found. will build on "main" branch."
fi

# Sometimes VPS Provider's CPU limitation is dick
export NODE_MAX_CONCURRENCY=1
export GOMAXPROCS=1

if [[ "$BUILD_STATIC" == true ]]
then
    mkdir -p $DESTINATION/gitea-static
    LDFLAGS="-X \"code.gitea.io/gitea/modules/setting.AppWorkPath=/var/lib/gitea/\" -X \"code.gitea.io/gitea/modules/setting.CustomConf=/etc/gitea/app.ini\"" TAGS="bindata sqlite sqlite_unlock_notify" GOOS=linux GOARCH=amd64 make frontend
    mv $MAKE_DIR/gitea/public/* $DESTINATION/gitea-static
else
    LDFLAGS="-X \"code.gitea.io/gitea/modules/setting.AppWorkPath=/var/lib/gitea/\" -X \"code.gitea.io/gitea/modules/setting.CustomConf=/etc/gitea/app.ini\"" TAGS="bindata sqlite sqlite_unlock_notify" GOOS=linux GOARCH=amd64 make build
    mv gitea $DESTINATION/gitea
fi

# Cleanup

rm -rf $MAKE_DIR