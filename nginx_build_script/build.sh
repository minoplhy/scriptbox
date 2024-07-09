#!/bin/bash

while [ ${#} -gt 0 ]; do
    case "$1" in
        --no-modsecurity | -nm )            DISABLE_MODSECURITY=true;;  # Not include ModSecurity in building
        --no-lua | -nl )                    DISABLE_LUA=true        ;;  # Not include Lua in building
        --install | -i )                    INSTALL=true            ;;  # Install Nginx
        --ssl=* )
            SSL_LIB="${1#*=}"
            case $SSL_LIB in                # Re-define SSL_LIB
                "quictls")                  SSL_LIB="quictls"   ;;
                "boringssl")                SSL_LIB="boringssl" ;;
                "libressl")                 SSL_LIB="libressl"  ;;
                "")
                    echo "ERROR : --ssl= is empty!"
                    exit 1
                    ;;
                *)
                    echo "ERROR : Vaild values for --ssl are -> quictls, boringssl, libressl"
                    exit 1
                    ;;
            esac
            ;;
        --nginx-tag=* )
            NGINX_TAG="${1#*=}"             # Specify Nginx Mercurial Tag
            case $NGINX_TAG in
                "")
                    echo "ERROR: --nginx-tag= is empty!"
                    exit 1
                    ;;
                *)
                    ;;
            esac
            ;;
        *)
            ;;
    esac
    shift
done

# if $SSL_LIB is null/empty
SSL_LIB=${SSL_LIB:-"boringssl"}

#################################
##                             ##
##    Dependencies Setup       ##
##                             ##
#################################

# Get Dependencies
sudo apt-get install mercurial libunwind-dev libpcre3 libpcre3-dev zlib1g-dev cmake make libxslt1-dev libgd-dev libssl-dev libperl-dev libpam0g-dev libgeoip-dev git g++ -y
sudo apt-get install apt-utils autoconf automake build-essential libcurl4-openssl-dev liblmdb-dev libtool libxml2-dev libyajl-dev pkgconf wget ninja-build -y

HOMEDIRECTORY=~/nginx_scriptbox

# Remove old build directory
rm -rf $HOMEDIRECTORY

mkdir $HOMEDIRECTORY && cd $HOMEDIRECTORY

# Nginx
cd $HOMEDIRECTORY
hg clone https://hg.nginx.org/nginx $HOMEDIRECTORY/nginx

cd $HOMEDIRECTORY/nginx
# Check if the tag exists
if [[ -n $NGINX_TAG ]]
then
    if hg tags | grep -q "^${NGINX_TAG}\>"; then
        echo "INFO: Switching Nginx Branch to ${NGINX_TAG}"
        hg checkout $NGINX_TAG
    else
        echo "ERROR: NGINX_TAG specified is not existed. aborting..." && exit 1
    fi
else
    hg checkout default
fi

# Build SSL Library
case $SSL_LIB in
    "quictls")
        git clone --depth=1 https://github.com/quictls/openssl $HOMEDIRECTORY/openssl
        cd $HOMEDIRECTORY/openssl
        ./Configure --prefix=/opt/quictls
        make
        make install
        mkdir -p /opt/quictls/.openssl
        cp -r /opt/quictls/include /opt/quictls/.openssl/include
        cp -r /opt/quictls/lib64 /opt/quictls/.openssl/lib
        ;;
    "boringssl")
        # Golang
        GO_VERSION=1.22.1

        unlink /usr/bin/go
        wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz
        sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
        export PATH=$PATH:/usr/local/go/bin
        ln -s /usr/local/go/bin /usr/bin/go

        git clone --depth=1 https://github.com/google/boringssl $HOMEDIRECTORY/boringssl
        cd $HOMEDIRECTORY/boringssl
        cmake -GNinja -B build
        ninja -C build
        ;;
    "libressl")
        git clone --depth=1 https://github.com/libressl/portable $HOMEDIRECTORY/libressl
        cd $HOMEDIRECTORY/libressl
        ./autogen.sh
        ./configure
        cmake -GNinja -B build
        ninja -C build
        export DESTDIR=$HOMEDIRECTORY/libressl/libressl-build
        ninja install -C build
        export -n DESTDIR   # unset to avoid problems with Luajit2/Lua*

        mkdir -p /opt/libressl/.openssl
        cp -r $HOMEDIRECTORY/libressl/libressl-build/usr/local/include /opt/libressl/.openssl
        cp -r $HOMEDIRECTORY/libressl/libressl-build/usr/local/lib /opt/libressl/.openssl
        ;;
esac

# ModSecurity
if [ ! "${DISABLE_MODSECURITY}" == true ]; then
    git clone --depth=1 https://github.com/SpiderLabs/ModSecurity $HOMEDIRECTORY/ModSecurity
    cd $HOMEDIRECTORY/ModSecurity
    git submodule init
    git submodule update
    ./build.sh
    ./configure
    make
    sudo make install
fi

#################################
##                             ##
##       Nginx Modules         ##
##                             ##
#################################

mkdir $HOMEDIRECTORY/nginx/mosc
git clone https://github.com/openresty/headers-more-nginx-module $HOMEDIRECTORY/nginx/mosc/headers-more-nginx-module
git clone https://github.com/sto/ngx_http_auth_pam_module $HOMEDIRECTORY/nginx/mosc/ngx_http_auth_pam_module
git clone https://github.com/arut/nginx-dav-ext-module $HOMEDIRECTORY/nginx/mosc/nginx-dav-ext-module
git clone https://github.com/openresty/echo-nginx-module $HOMEDIRECTORY/nginx/mosc/echo-nginx-module
git clone https://github.com/nginx-modules/ngx_cache_purge $HOMEDIRECTORY/nginx/mosc/ngx_cache_purge

if [ ! "${DISABLE_MODSECURITY}" == true ]; then
    git clone https://github.com/SpiderLabs/ModSecurity-nginx $HOMEDIRECTORY/nginx/mosc/ModSecurity-nginx
fi

if [ ! "${DISABLE_LUA}" == true ]; then
    git clone https://github.com/vision5/ngx_devel_kit $HOMEDIRECTORY/nginx/mosc/ngx_devel_kit
    git clone https://github.com/openresty/lua-nginx-module $HOMEDIRECTORY/nginx/mosc/lua-nginx-module
fi

# Nginx Module: ngx_brotli
git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli $HOMEDIRECTORY/nginx/mosc/ngx_brotli
cd $HOMEDIRECTORY/nginx/mosc/ngx_brotli/deps/brotli
mkdir out && cd out
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..
cmake --build . --config Release --target brotlienc

# Nginx Module: lua-nginx-module, requirement
#
# lua resty core,lrucache,luajit2

if [ ! "${DISABLE_LUA}" == true ]; then
    mkdir -p $HOMEDIRECTORY/nginx-lua && cd $HOMEDIRECTORY/nginx-lua
    mkdir -p /opt/nginx-lua-module/
    git clone https://github.com/openresty/lua-resty-core $HOMEDIRECTORY/nginx-lua/lua-resty-core
    git clone https://github.com/openresty/lua-resty-lrucache $HOMEDIRECTORY/nginx-lua/lua-resty-lrucache
    git clone https://github.com/openresty/luajit2 $HOMEDIRECTORY/nginx-lua/luajit2
    git clone https://github.com/openresty/lua-resty-string $HOMEDIRECTORY/nginx-lua/lua-resty-string

    cd $HOMEDIRECTORY/nginx-lua/luajit2 && make && make install PREFIX=/opt/nginx-lua-module/luajit2
    cd $HOMEDIRECTORY/nginx-lua/lua-resty-core && make install PREFIX=/usr/local/lua LUA_LIB_DIR=/usr/local/lua
    cd $HOMEDIRECTORY/nginx-lua/lua-resty-lrucache && make install PREFIX=/usr/local/lua LUA_LIB_DIR=/usr/local/lua
    cd $HOMEDIRECTORY/nginx-lua/lua-resty-string && make install PREFIX=/usr/local/lua LUA_LIB_DIR=/usr/local/lua

    export LUAJIT_LIB=/opt/nginx-lua-module/luajit2/lib
    export LUAJIT_INC=/opt/nginx-lua-module/luajit2/include/luajit-2.1
fi

######################################################################
##                                                                  ##
##      Build Nginx                                                 ##
##                                                                  ##
##      Why "--with-cc=c++"?                                        ##
##      see -> https://trac.nginx.org/nginx/ticket/2605#comment:8   ##
##                                                                  ##
######################################################################

NGINX_CONFIG_PARAMS=(
    --with-cc=c++
    --prefix=/usr/share/nginx
    --conf-path=/etc/nginx/nginx.conf
    --http-log-path=/var/log/nginx/access.log
    --error-log-path=/var/log/nginx/error.log
    --lock-path=/var/lock/nginx.lock
    --pid-path=/run/nginx.pid
    --modules-path=/usr/lib/nginx/modules
    --http-client-body-temp-path=/var/lib/nginx/body
    --http-fastcgi-temp-path=/var/lib/nginx/fastcgi
    --http-proxy-temp-path=/var/lib/nginx/proxy
    --http-scgi-temp-path=/var/lib/nginx/scgi
    --http-uwsgi-temp-path=/var/lib/nginx/uwsgi
    --with-compat
    --with-debug
    --with-pcre-jit
    --with-http_ssl_module
    --with-http_stub_status_module
    --with-http_realip_module
    --with-http_auth_request_module
    --with-http_v2_module
    --with-http_v3_module
    --with-http_dav_module
    --with-http_slice_module
    --with-threads
    --with-http_addition_module
    --with-http_flv_module
    --with-http_gunzip_module
    --with-http_gzip_static_module
    --with-http_image_filter_module=dynamic
    --with-http_mp4_module
    --with-http_perl_module=dynamic
    --with-http_random_index_module
    --with-http_secure_link_module
    --with-http_sub_module
    --with-http_xslt_module=dynamic
    --with-mail=dynamic
    --with-mail_ssl_module
    --with-stream
    --with-stream_realip_module
    --with-stream_ssl_module
    --with-stream_ssl_preread_module
    --add-dynamic-module=mosc/headers-more-nginx-module
    --add-dynamic-module=mosc/ngx_http_auth_pam_module
    --add-dynamic-module=mosc/ngx_cache_purge
    --add-dynamic-module=mosc/nginx-dav-ext-module
    --add-dynamic-module=mosc/echo-nginx-module
    --add-dynamic-module=mosc/ngx_brotli
    --with-http_geoip_module
    --with-stream_geoip_module
)

# NGINX Config Params configuration
case $SSL_LIB in
    "quictls")
        NGINX_CONFIG_PARAMS+=(
            --with-openssl="/opt/quictls"
            --with-cc-opt="-I/opt/quictls/.openssl/include -x c"
        )
        WITH_LD_OPT="-L/opt/quictls/.openssl/lib"
        ;;
    "boringssl")
        NGINX_CONFIG_PARAMS+=(
            --with-cc-opt="-I../boringssl/include -x c"
        )
        WITH_LD_OPT="-L../boringssl/build/ssl -L../boringssl/build/crypto"
        ;;
    "libressl")
        NGINX_CONFIG_PARAMS+=(
            --with-openssl="/opt/libressl"
            --with-cc-opt="-x c"
        )
        ;;
esac

if [ ! "${DISABLE_MODSECURITY}" == true ]; then
    NGINX_CONFIG_PARAMS+=(
        --add-dynamic-module=mosc/ModSecurity-nginx
    )
fi

# SomeHow, Nginx is broken when compiling as dynamic module with BoringSSL. 
# Compiling as module seems to fix this.
if [ ! "${DISABLE_LUA}" == true ]; then
    NGINX_CONFIG_PARAMS+=(
        --add-module=mosc/ngx_devel_kit
        --add-module=mosc/lua-nginx-module
    )
    WITH_LD_OPT+=" -Wl,-rpath,$LUAJIT_LIB"
fi

# Build --with-ld-opt arguments here
if [[ -n ${WITH_LD_OPT} && ${WITH_LD_OPT} != "" ]]; then
    NGINX_CONFIG_PARAMS+=(
        --with-ld-opt="${WITH_LD_OPT}"
    )
fi

cd $HOMEDIRECTORY/nginx
./auto/configure "${NGINX_CONFIG_PARAMS[@]}"

# Prevent Error 127, When building.
if [ $SSL_LIB == "quictls" ]; then
    touch /opt/quictls/.openssl/include/openssl/ssl.h
elif [ $SSL_LIB == "libressl" ]; then
    touch /opt/libressl/.openssl/include/openssl/ssl.h
fi

make

#################################
##                             ##
##   Install Nginx(optional)   ##
##                             ##
#################################

if [[ $Nginx_Install == "yes" || $INSTALL == true ]]; then
    mkdir -p /lib/nginx/ && mkdir -p /lib/nginx/modules
    mkdir -p /etc/nginx && mkdir -p /etc/nginx/sites-enabled && mkdir -p /etc/nginx/modules-enabled
    cp $HOMEDIRECTORY/nginx/objs/*.so /lib/nginx/modules
    cp $HOMEDIRECTORY/nginx/objs/nginx /usr/sbin/nginx

    cat >modules.conf <<EOL
load_module /lib/nginx/modules/ngx_http_auth_pam_module.so;
load_module /lib/nginx/modules/ngx_http_cache_purge_module.so;
load_module /lib/nginx/modules/ngx_http_dav_ext_module.so;
load_module /lib/nginx/modules/ngx_http_echo_module.so;
load_module /lib/nginx/modules/ngx_http_headers_more_filter_module.so;
load_module /lib/nginx/modules/ngx_http_brotli_filter_module.so;
load_module /lib/nginx/modules/ngx_http_brotli_static_module.so;
EOL

    if [ ! "${DISABLE_MODSECURITY}" == true ]; then
        cat >>modules.conf <<EOL
load_module /lib/nginx/modules/ngx_http_modsecurity_module.so;
EOL
    fi

    cp modules.conf /etc/nginx/modules-enabled
else
    echo "Nginx_Install variable isn't set/vaild. Your Nginx assets location is : '$HOMEDIRECTORY'/nginx/objs"
fi