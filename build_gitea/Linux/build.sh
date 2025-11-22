#!/bin/bash

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
        --dest | -d )
            shift
            DESTINATION=$1
            ;;                          # Destination Dir
        --static | -s)
            BUILD_STATIC=true
            ;;                          # Also Build Static Assets file
        --system | -s)
            USE_SYSTEM=true
            ;;                          # Use system's NPM and Go
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
        --source-folder=* )
            SOURCE_FOLDER="${1#*=}"
            case $SOURCE_FOLDER in
                "")
                    echo "ERROR: --source-folder= is empty!"
                    exit 1
                    ;;
                *)
                    ;;
            esac
            ;;                          # Source folder for your gitea/forgejo build / in case --type does not satisfy you
        --patch=* )
            PATCH_FILES="${1#*=}"
            case $PATCH_FILES in
                "")
                    echo "ERROR: --patch= is empty!"
                    exit 1
                    ;;
                *)
                    ;;
            esac                                                    # Add Patches to your Gitea build. Format -> patch1.patch or patch1.patch,https://patch (Absolute path)
            ;;
        --build-arch=* )
            BUILD_ARCH="${1#*=}"
            case $BUILD_ARCH in
                "x86_64")   BUILD_ARCH="x86_64"          ;;
                "aarch64")  BUILD_ARCH="aarch64"         ;;
                "")
                    echo "ERROR : --build-arch= is empty!"
                    exit 1
                    ;;
                *)
                    echo "ERROR :  Vaild values for --build-arch are -> x86_64, aarch64"
                    exit 1
                    ;;
            esac                                                    # Architect for your binary to be build. This is for Cross-compiling etc.
            ;;
        *)
            ;;
    esac
    shift # Shift to next response for parsing
done

# If empty
NODEJS_VERSION=${NODEJS_VERSION:-"v20.17.0"}
GO_VERSION=${GO_VERSION:-"1.23.2"}

# Source folder get more priority than the --type
if [[ -z $SOURCE_FOLDER ]]; then
    BUILD_TYPE=${BUILD_TYPE:-"gitea"}
fi

if [[ -n $SOURCE_FOLDER && ! -d $SOURCE_FOLDER ]]; then
    printf "Error: folder '%s' not exist! exiting...\n" $SOURCE_FOLDER
    exit 1
fi

DESTINATION=${DESTINATION:-"~/gitea-binaries"}

# Clean up old build
rm -rf $DESTINATION
mkdir -p $DESTINATION

# OS
GOOS=linux
NODEJS_DISTRO=linux

# ARCHITECT

# This Base Architect is to detect "build" build machine Architect. NOT BUILD ARCHITECT
ARCH=${ARCH:-$(uname -m)}
case $ARCH in
    "x86_64")
        NODEJS_ARCH=x64
        BASE_GOARCH=amd64
        ;;
    "aarch64")
        NODEJS_ARCH=arm64
        BASE_GOARCH=arm64
        ;;
    *)
        printf "\nPANIC: Arch %s is not supported! exit...\n" $ARCH
        exit 1
        ;;
esac

# This define the architect for Build to be. AKA cross-compile stuff.
BUILD_ARCH=${BUILD_ARCH:-$(uname -m)}
case $BUILD_ARCH in
    "x86_64")
        GOARCH=amd64
        ;;
    "aarch64")
        GOARCH=arm64
        ;;
    *)
        printf "PANIC: Build Arch %s is not supported! exit...\n" $BUILD_ARCH
        exit 1
        ;;
esac

printf "INFO: Build Architect: %s\nINFO: Machine Architect: %s\n" $BUILD_ARCH $ARCH

# GITEA_GIT_TAG is being process below

# Install Dependencies

DISTRO=$(grep '^ID=' /etc/os-release | cut -d'=' -f2)
case $DISTRO in
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
        echo "ERROR: the distro detected is not supported. The script will run as is."
        ;;
esac

# This part will be skip if USE_SYSTEM=true
if [[ ! "${USE_SYSTEM}" == true ]]; then
    # NodeJS
    case $DISTRO in
        "alpine")
            apk add nodejs npm pnpm # NodeJS in alpine required complex build to be done. For peace of mind  i'll use apk until i see better options. 
        ;;
        * )
            wget https://nodejs.org/dist/$NODEJS_VERSION/node-$NODEJS_VERSION-$NODEJS_DISTRO-$NODEJS_ARCH.tar.xz -O $DESTINATION/node-$NODEJS_VERSION-$DISTRO.tar.xz
            tar -xJvf $DESTINATION/node-$NODEJS_VERSION-$DISTRO.tar.xz -C $DESTINATION
            export PATH=$PATH:$DESTINATION/node-$NODEJS_VERSION-$DISTRO/bin
            
            npm install -g pnpm@latest-10
        ;;
    esac

    # Golang
    wget https://go.dev/dl/go$GO_VERSION.$GOOS-$BASE_GOARCH.tar.gz -O $DESTINATION/go$GO_VERSION.$GOOS-$BASE_GOARCH.tar.gz
    tar -C $DESTINATION -xzf $DESTINATION/go$GO_VERSION.$GOOS-$BASE_GOARCH.tar.gz
    export PATH=$PATH:$DESTINATION/go/bin
fi

# Gitea

# GIT_TAG=
# specify the tag which gitea will build on
if [[ -z $SOURCE_FOLDER ]]; then
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
else
    echo "INFO: Building on custom source"
    echo "INFO: Copying source from original folder"
    cp -r "${SOURCE_FOLDER}" $DESTINATION/gitea-repo
    cp -r "${SOURCE_FOLDER}"/* $DESTINATION/gitea-repo
fi

cd $DESTINATION/gitea-repo

if [[ -n $GITEA_GIT_TAG ]]
then
    if git show-ref $GITEA_GIT_TAG --quiet;  then
        git checkout $GITEA_GIT_TAG
    else
        echo -e "\nGITEA_GIT_TAG variable doesn't match the repo tag/version. exit to prevent further issue." && exit 1
    fi
else
    echo -e "GITEA_GIT_TAG variable not found. will build on "main" branch."
fi

if [[ -n $PATCH_FILES ]]
then
    for patch in $(echo "$PATCH_FILES" | tr ',' '\n'); do
        case $patch in
            http://*|https://*)
                # The random part:
                # https://stackoverflow.com/questions/2793812/generate-a-random-filename-in-unix-shell
                NEW_PATCH_PATH=$DESTINATION/$(head /dev/urandom | tr -cd 'a-f0-9' | head -c 32)".patch"
                
                if wget $patch -O $NEW_PATCH_PATH; then
                    printf "Info: '%s' has been downloaded. Filename: %s\n" $patch $NEW_PATCH_PATH
                else
                    printf "Info: '%s' Download failed! The task is aborted.\n" $patch
                    exit 1
                fi

                patch=$NEW_PATCH_PATH   ;;
            *) ;;
        esac

        if git apply --check $patch; then
            git apply $patch
            printf "Info: PATCH '%s' applied successful!\n" $patch
        else
            printf "Error: PATCH '%s' cannot be applied! exiting...\n" $patch
            exit 1
        fi
    done
fi

# Sometimes VPS Provider's CPU limitation is dick
export LDFLAGS="-X \"code.gitea.io/gitea/modules/setting.AppWorkPath=/var/lib/gitea/\" -X \"code.gitea.io/gitea/modules/setting.CustomConf=/etc/gitea/app.ini\""
export TAGS="bindata sqlite sqlite_unlock_notify"
export GOOS=$GOOS
export GOARCH=$GOARCH

make build
mv gitea $DESTINATION/gitea

if [[ "$BUILD_STATIC" == true ]]
then
    mkdir -p $DESTINATION/gitea-static

    make frontend
    mv $DESTINATION/gitea-repo/public/* $DESTINATION/gitea-static
fi