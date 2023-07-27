#!/bin/bash

MAKE_DIR=$(mktemp -d)
DESTINATION=~/gitea-binaries/

mkdir -p $DESTINATION
cd $MAKE_DIR

GIT_TAG=$1

# Install Dependencies

sudo apt-get update && sudo apt-get install xz-utils wget git tar g++ make -y

# NodeJS

VERSION=v20.3.1
DISTRO=linux-x64

wget https://nodejs.org/dist/$VERSION/node-$VERSION-$DISTRO.tar.xz
sudo mkdir -p /usr/local/lib/nodejs
sudo tar -xJvf node-$VERSION-$DISTRO.tar.xz -C /usr/local/lib/nodejs 
export PATH=/usr/local/lib/nodejs/node-$VERSION-$DISTRO/bin:$PATH
. ~/.profile

# Golang

GO_VERSION=1.20.5

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

if [[ -n $GIT_TAG ]]
then
    if git show-ref $GIT_TAG --quiet;  then
        git checkout $GIT_TAG
    else
        echo -e "\nGIT_TAG variable doesn't match the repo tag/version. exit to prevent further issue." && exit 1 && rm -rf $MAKE_DIR
    fi
else
    echo -e "GIT_TAG variable not found. will build on "main" branch."
fi

LDFLAGS="-X \"code.gitea.io/gitea/modules/setting.AppWorkPath=/var/lib/gitea/\" -X \"code.gitea.io/gitea/modules/setting.CustomConf=/etc/gitea/app.ini\"" TAGS="bindata sqlite sqlite_unlock_notify" GOOS=linux GOARCH=amd64 make build
mv gitea $DESTINATION/gitea

# Cleanup

rm -rf $MAKE_DIR