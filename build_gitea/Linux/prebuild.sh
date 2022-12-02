MAKE_DIR=$(mktemp -d)
DESTINATION=~/gitea-binaries/

mkdir -p $DESTINATION
cd $MAKE_DIR

# NodeJS

VERSION=v19.2.0
DISTRO=linux-x64

wget https://nodejs.org/dist/$VERSION/node-$VERSION-$DISTRO.tar.xz
sudo mkdir -p /usr/local/lib/nodejs
sudo tar -xJvf node-$VERSION-$DISTRO.tar.xz -C /usr/local/lib/nodejs 
export PATH=/usr/local/lib/nodejs/node-$VERSION-$DISTRO/bin:$PATH
. ~/.profile

# Golang

GO_VERSION=1.19.3

sudo unlink /usr/bin/go
wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
sudo ln -s /usr/local/go/bin /usr/bin/go

# Make

sudo apt-get update && sudo apt-get install make

curl -L https://github.com/minoplhy/scriptbox/raw/main/build_gitea/Linux/build.sh | sudo bash