#!/bin/bash

DESTINATION=~/gitea-binaries

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
            ;;                          # Also Build Static Assets file
        --type=* )
            BUILD_TYPE="${1#*=}"
            BUILD_TYPE="${BUILD_TYPE,,}"
            case $BUILD_TYPE in
                "gitea")                    BUILD_TYPE="gitea"      ;;
                "forgejo")                  BUILD_TYPE="forgejo"    ;;
                "")
                    echo "ERROR : --type= is empty!"
                    exit 1
                    ;;
                *)
                    echo "ERROR :  Vaild values for --type are -> gitea, forgejo"
                    exit 1
                    ;;
            esac
            ;;
        *)
            ;;
    esac
    shift # Shift to next response for parsing
done

# If empty
NODEJS_VERSION=${NODEJS_VERSION:-"v20.17.0"}
GO_VERSION=${GO_VERSION:-"1.23.2"}
BUILD_TYPE=${BUILD_TYPE:-"gitea"}

# GITEA_GIT_TAG is being process below

# Install Dependencies

os=$(grep '^ID=' /etc/os-release | cut -d'=' -f2)
case $os in
    "debian" | "ubuntu" )
        sudo apt update
        sudo apt install -y \
            xz-utils \
            wget \
            git \
            tar \
            g++ \
            make
        ;;
    "alpine" )
        apk update
        apk add \
            xz \
            wget \
            git \
            tar \
            g++ \
            make
        ;;
    * )
        echo "ERROR: the os detected is not supported. The script will run as is."
        ;;
esac

# NodeJS
DISTRO=linux-x64

case $os in
    "alpine")
        apk add nodejs # NodeJS broken when install from binary
    ;;
    * )
        wget https://nodejs.org/dist/$NODEJS_VERSION/node-$NODEJS_VERSION-$DISTRO.tar.xz -O $DESTINATION/node-$NODEJS_VERSION-$DISTRO.tar.xz
        tar -xJvf $DESTINATION/node-$NODEJS_VERSION-$DISTRO.tar.xz -C $DESTINATION
        export PATH=$PATH:$DESTINATION/node-$NODEJS_VERSION-$DISTRO/bin
    ;;
esac

# Golang
wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz -O $DESTINATION/go$GO_VERSION.linux-amd64.tar.gz
tar -C $DESTINATION -xzf $DESTINATION/go$GO_VERSION.linux-amd64.tar.gz
export PATH=$PATH:$DESTINATION/go/bin

# Gitea

# GIT_TAG=
# specify the tag which gitea will build on

case $BUILD_TYPE in
    "gitea")
        echo "INFO: Building on gitea"
        git clone https://github.com/go-gitea/gitea $DESTINATION/gitea-repo
        ;;
    "forgejo")
        echo "INFO: Building on forgejo"
        git clone https://codeberg.org/forgejo/forgejo $DESTINATION/gitea-repo #LOL
        ;;
esac

cd $DESTINATION/gitea-repo

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
export LDFLAGS="-X \"code.gitea.io/gitea/modules/setting.AppWorkPath=/var/lib/gitea/\" -X \"code.gitea.io/gitea/modules/setting.CustomConf=/etc/gitea/app.ini\""
export TAGS="bindata sqlite sqlite_unlock_notify"
export GOOS=linux
export GOARCH=amd64

make build
mv gitea $DESTINATION/gitea

if [[ "$BUILD_STATIC" == true ]]
then
    mkdir -p $DESTINATION/gitea-static

    make frontend
    mv $DESTINATION/gitea-repo/public/* $DESTINATION/gitea-static
fi