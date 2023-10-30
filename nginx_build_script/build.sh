#!/bin/bash

HOMEDIRECTORY=~/nginx_scriptbox

rm -rf $HOMEDIRECTORY
curl -sSL https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/packages.sh | bash
mkdir $HOMEDIRECTORY && cd $HOMEDIRECTORY

# Install Golang
GO_VERSION=1.20.5

unlink /usr/bin/go
wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
ln -s /usr/local/go/bin /usr/bin/go

hg clone -b default https://hg.nginx.org/nginx
git clone --depth=1 https://github.com/google/boringssl $HOMEDIRECTORY/boringssl
cd $HOMEDIRECTORY/boringssl
mkdir $HOMEDIRECTORY/boringssl/build && cd $HOMEDIRECTORY/boringssl/build && cmake .. && make

# ModSecurity Part
git clone --depth=1 https://github.com/SpiderLabs/ModSecurity $HOMEDIRECTORY/ModSecurity
cd $HOMEDIRECTORY/ModSecurity
git submodule init
git submodule update
./build.sh
./configure
make
sudo make install

# lua-nginx-module buildup part (Big Part)
#
mkdir $HOMEDIRECTORY/nginx-lua && cd $HOMEDIRECTORY/nginx-lua
mkdir -p /opt/nginx-lua-module/
git clone https://github.com/openresty/lua-resty-core
git clone https://github.com/openresty/lua-resty-lrucache
git clone https://github.com/openresty/luajit2

cd luajit2 && make install PREFIX=/opt/nginx-lua-module/luajit2 && cd ..
cd lua-resty-core && make install PREFIX=/opt/nginx-lua-module/ && cd ..
cd lua-resty-lrucache && make install PREFIX=/opt/nginx-lua-module/ && cd ..

export LUAJIT_LIB=/opt/nginx-lua-module/luajit2/lib
export LUAJIT_INC=/opt/nginx-lua-module/luajit2/include/luajit-2.1

# Build Nginx

mkdir $HOMEDIRECTORY/nginx/mosc && cd $HOMEDIRECTORY/nginx/mosc && curl -sSL https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/modules.sh | bash && cd ..
curl -sSL https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/configure.sh | bash && make

if [[ $Nginx_Install == "yes" ]]; then
    mkdir -p /lib/nginx/ && mkdir -p /lib/nginx/modules
    mkdir -p /etc/nginx && mkdir -p /etc/nginx/sites-enabled && mkdir -p /etc/nginx/modules-enabled
    cp $HOMEDIRECTORY/nginx/objs/*.so /lib/nginx/modules
    rm /usr/sbin/nginx
    cp $HOMEDIRECTORY/nginx/objs/nginx /usr/sbin/nginx
    curl -sSL https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/modules.conf > modules.conf
    cp modules.conf /etc/nginx/modules-enabled
else
    echo "Nginx_Install variable isn't set/vaild. Your Nginx assets location is : '$HOMEDIRECTORY'/nginx-quic/objs"
fi