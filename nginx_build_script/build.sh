#!/bin/bash

cd ~/
rm -rf nginx_scriptbox
curl -sSL https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/packages.sh | bash
mkdir nginx_scriptbox && cd nginx_scriptbox

# Install Golang
GO_VERSION=1.20.5

unlink /usr/bin/go
wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
ln -s /usr/local/go/bin /usr/bin/go

hg clone -b default https://hg.nginx.org/nginx
git clone --depth=1 https://github.com/google/boringssl
cd boringssl
mkdir build && cd build && cmake .. && make
cd ../..

# ModSecurity Part
git clone --depth=1 https://github.com/SpiderLabs/ModSecurity
cd ModSecurity
git submodule init
git submodule update
./build.sh
./configure
make
sudo make install
cd ..

# Whoops! Openresty doesn't support QUIC yet!
# lua-nginx-module buildup part (Big Part)
#
## mkdir nginx-lua && cd nginx-lua
## mkdir -p /opt/nginx-lua-module/
## git clone https://github.com/openresty/lua-resty-core
## git clone https://github.com/openresty/lua-resty-lrucache
## git clone https://github.com/openresty/luajit2
##
## cd luajit2 && make install PREFIX=/opt/nginx-lua-module/luajit2 && cd ..
## cd lua-resty-core && make install PREFIX=/opt/nginx-lua-module/ && cd ..
## cd lua-resty-lrucache && make install PREFIX=/opt/nginx-lua-module/ && cd ..
## cd ..
##
## export LUAJIT_LIB=/opt/nginx-lua-module/luajit2/lib
## export LUAJIT_INC=/opt/nginx-lua-module/luajit2/include/luajit-2.1

# Build Nginx

cd nginx
mkdir mosc && cd mosc && curl -sSL https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/modules.sh | bash && cd ..
curl -sSL https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/configure.sh | bash && make

if [[ $Nginx_Install == "yes" ]]; then
    mkdir -p /lib/nginx/ && mkdir -p /lib/nginx/modules
    mkdir -p /etc/nginx && mkdir -p /etc/nginx/sites-enabled && mkdir -p /etc/nginx/modules-enabled
    cd objs && cp *.so /lib/nginx/modules
    rm /usr/sbin/nginx
    cp nginx /usr/sbin/nginx
    curl -sSL https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/modules.conf > modules.conf
    cp modules.conf /etc/nginx/modules-enabled
else
    echo "Nginx_Install variable isn't set/vaild. Your Nginx assets location is : ~/nginx_scriptbox/nginx-quic/objs"
fi