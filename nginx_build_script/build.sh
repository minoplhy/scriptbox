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
cd .. && cd ..

# ModSecurity Part
git clone --depth=1 https://github.com/SpiderLabs/ModSecurity
cd ModSecurity/
git submodule init
git submodule update
./build.sh
./configure
make
sudo make install
cd ..

cd nginx
mkdir mosc && cd mosc && curl -sSL https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/modules.sh | bash && cd ..
curl -sSL https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/configure.sh | bash && make

if [[ $Nginx_Install == "yes" ]]; then
    mkdir /lib/nginx/ && mkdir /lib/nginx/modules
    cd objs && cp *.so /lib/nginx/modules
    rm /usr/sbin/nginx
    cp nginx /usr/sbin/nginx
    curl -sSL https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/modules.conf > modules.conf
    cp modules.conf /etc/nginx/modules-enabled
else
    echo "Nginx_Install variable isn't set/vaild. Your Nginx assets location is : ~/nginx_scriptbox/nginx-quic/objs"
fi