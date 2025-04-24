#!/bin/bash

info() {
    local INFO_MSG=$1
    local VARIABLE=$2

    printf "INFO: $INFO_MSG\n" $VARIABLE
}

error() {
    local ERROR_MSG=$1
    local VARIABLE=$2

    printf "ERROR: $ERROR_MSG\n" $VARIABLE
}

panic() {
    local PANIC_MSG=$1
    local VARIABLE=$2

    printf "PANIC: $PANIC_MSG\n" $VARIABLE
    exit 1
}

# Check for empty variable input from CLI arguments
check_empty() {
    VARIABLE="$1"
    VARIABLE_NAME="$2"
    case $VARIABLE in
        "")
            panic "%s is empty!" "${VARIABLE_NAME}"
            ;;
        *)
            ;;
        esac
}

while [ ${#} -gt 0 ]; do
    case "$1" in
        --modsecurity )                     WITH_MODSECURITY=true       ;;  # Include ModSecurity in building
        --lua )                             WITH_LUA=true               ;;  # Include Lua in building
        --no-modsecurity | -nm )            WITH_MODSECURITY=false      ;;  # LEGACY: Not include ModSecurity in building
        --no-lua | -nl )                    WITH_LUA=false              ;;  # LEGACY: Not include Lua in building
        --install | -i )                    INSTALL=true                ;;  # Install Nginx
        --preserve | -p )                   PRESERVE=true               ;;  # PRESERVE Existing installation(only ModSecurity, Lua)
        --lua-prefix=* )
            LUA_BASE_PATH="${1#*=}"
            check_empty "$LUA_BASE_PATH" "LUA_BASE_PATH"
            ;;
        --modsecurity-prefix=* )
            MODSEC_BASE_PATH="${1#*=}"
            check_empty "$MODSEC_BASE_PATH" "MODSEC_BASE_PATH"
            ;;
        --luajit2-prefix=* )
            LUAJIT_BASE_PATH="${1#*=}"
            check_empty "$LUAJIT_BASE_PATH" "LUAJIT_BASE_PATH"
            ;;
        --ssl=* )
            SSL_LIB="${1#*=}"
            SSL_LIB="${SSL_LIB,,}"
            case $SSL_LIB in                # Re-define SSL_LIB
                "quictls")                  SSL_LIB="quictls"   ;;
                "boringssl")                SSL_LIB="boringssl" ;;
                "libressl")                 SSL_LIB="libressl"  ;;
                "")
                    panic "--ssl= is empty!"
                    ;;
                *)
                    panic "Vaild values for --ssl are -> quictls, boringssl, libressl"
                    ;;
            esac
            ;;
        --type=* )
            BUILD_TYPE="${1#*=}"
            BUILD_TYPE="${BUILD_TYPE,,}"
            case $BUILD_TYPE in
                "nginx")                    BUILD_TYPE="nginx"      ;;
                "freenginx")                BUILD_TYPE="freenginx"  ;;
                "")
                    panic "--type= is empty!"
                    ;;
                *)
                    panic "Vaild values for --type are -> nginx, freenginx"
                    ;;
            esac
            ;;
        --nginx-tag=* )
            NGINX_TAG="${1#*=}"             # Specify Nginx/freenginx Tag
            check_empty "$NGINX_TAG" "NGINX_TAG"
            ;;
        *)
            ;;
    esac
    shift
done

# DEFAULT VARIABLES
SSL_LIB=${SSL_LIB:-"boringssl"}
BUILD_TYPE=${BUILD_TYPE:-"nginx"}

WITH_MODSECURITY=${WITH_MODSECURITY:-false}
WITH_LUA=${WITH_LUA:-false}

# 2025 default path suggestions:
# - LUAJIT_BASE_PATH=/usr
# - LUA_BASE_PATH=/usr/local/share/lua/5.1
# - MODSEC_BASE_PATH=/usr
#
# The current configuration will be reserved for compatiblity purposes.
LUAJIT_BASE_PATH=${LUAJIT_BASE_PATH:-"/opt/nginx-lua-module/luajit2"}
LUA_BASE_PATH=${LUA_BASE_PATH:-"/usr/local/lua"}
MODSEC_BASE_PATH=${MODSEC_BASE_PATH:-"/usr/local/modsecurity"}

if [ "${PRESERVE}" == true ]; then
    if "${WITH_MODSECURITY}" == true && ! find "${MODSEC_BASE_PATH}/lib/" -name 'libmodsec*' > /dev/null; then
        panic "Cannot find libmodsec Library at %s" "$MODSEC_BASE_PATH"
    fi
    if "${WITH_LUA}" == true && ! find "${LUAJIT_BASE_PATH}/lib/" -name 'libluajit*' > /dev/null; then
        panic "Cannot find libluajit Library at %s" "$LUAJIT_BASE_PATH"
    fi
fi

#################################
##                             ##
##    Dependencies Setup       ##
##                             ##
#################################

# Get Dependencies

# Detect OS
os=$(grep '^ID=' /etc/os-release | cut -d'=' -f2)
case $os in
    "debian" | "ubuntu" )
        sudo apt update
        sudo apt install -y \
            mercurial \
            libunwind-dev \
            libpcre3 \
            libpcre3-dev \
            libpcre2 \
            libpcre2-dev \
            zlib1g-dev \
            cmake \
            make \
            libxslt1-dev \
            libgd-dev \
            libssl-dev \
            libperl-dev \
            libgeoip-dev \
            git \
            g++ \
            apt-utils \
            autoconf \
            automake \
            build-essential \
            libcurl4-openssl-dev \
            liblmdb-dev \
            libtool \
            libxml2-dev \
            libyajl-dev \
            pkgconf \
            wget \
            ninja-build
        ;;
    "alpine" )
        apk update
        apk add \
            mercurial \
            libunwind \
            pcre-dev \
            pcre2-dev \
            zlib-dev \
            cmake \
            make \
            libxslt-dev \
            gd-dev \
            openssl-dev \
            perl-dev \
            geoip-dev \
            git \
            g++ \
            build-base \
            autoconf \
            automake \
            curl-dev \
            lmdb-dev \
            libtool \
            libxml2-dev \
            yajl-dev \
            pkgconf \
            wget \
            ninja \
            linux-headers \
            sudo
        ;;
    * )
        error "the os detected is not supported. The script will run as is!"
        ;;
esac

HOMEDIRECTORY=~/nginx_scriptbox

# Remove old build directory
rm -rf $HOMEDIRECTORY

mkdir $HOMEDIRECTORY && cd $HOMEDIRECTORY

#Setup Nginx/freenginx repository
case $BUILD_TYPE in
    "nginx")
        cd $HOMEDIRECTORY
        git clone https://github.com/nginx/nginx $HOMEDIRECTORY/nginx
        cd $HOMEDIRECTORY/nginx

        # Check if the tag exists
        if [[ -n $NGINX_TAG ]]
        then
            if git show-ref $NGINX_TAG --quiet;  then
                info "Switching Nginx Branch to %s" "${NGINX_TAG}"
                git checkout $NGINX_TAG
            else
                panic "NGINX_TAG specified is not existed. aborting..."
            fi
        else
            git checkout master
        fi
        ;;
    "freenginx")
        cd $HOMEDIRECTORY
        hg clone https://freenginx.org/hg/nginx $HOMEDIRECTORY/nginx

        cd $HOMEDIRECTORY/nginx
        # Check if the tag exists
        if [[ -n $NGINX_TAG ]]
        then
            if hg tags | grep -q "^${NGINX_TAG}\>"; then
                info "Switching Nginx Branch to %s" "${NGINX_TAG}"
                hg checkout $NGINX_TAG
            else
                panic "NGINX_TAG specified is not existed. aborting..."
            fi
        else
            hg checkout default
        fi
        ;;
esac

# Build SSL Library
case $SSL_LIB in
    "quictls")
        git clone --depth=1 https://github.com/quictls/openssl $HOMEDIRECTORY/openssl
        cd $HOMEDIRECTORY/openssl
        ./Configure --prefix=/opt/quictls
        make
        sudo make install
        sudo mkdir -p /opt/quictls/.openssl
        sudo cp -r /opt/quictls/include /opt/quictls/.openssl/include
        sudo cp -r /opt/quictls/lib64 /opt/quictls/.openssl/lib
        ;;
    "boringssl")
        # Golang
        GO_VERSION=1.23.1

        wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz -O $HOMEDIRECTORY/go$GO_VERSION.linux-amd64.tar.gz
        tar -C $HOMEDIRECTORY -xzf $HOMEDIRECTORY/go$GO_VERSION.linux-amd64.tar.gz
        export PATH=$PATH:$HOMEDIRECTORY/go/bin

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
        ninja -C build install
        export -n DESTDIR   # unset to avoid problems with Luajit2/Lua*

        sudo mkdir -p /opt/libressl/.openssl
        sudo cp -r $HOMEDIRECTORY/libressl/libressl-build/usr/local/include /opt/libressl/.openssl
        sudo cp -r $HOMEDIRECTORY/libressl/libressl-build/usr/local/lib /opt/libressl/.openssl
        ;;
esac

# ModSecurity
if [[ "${WITH_MODSECURITY}" == true && ! "${PRESERVE}" == true ]]; then
    git clone --depth=1 https://github.com/owasp-modsecurity/ModSecurity $HOMEDIRECTORY/ModSecurity
    cd $HOMEDIRECTORY/ModSecurity
    git submodule init
    git submodule update
    ./build.sh
    ./configure --prefix=${MODSEC_BASE_PATH}
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
git clone https://github.com/openresty/echo-nginx-module $HOMEDIRECTORY/nginx/mosc/echo-nginx-module

if [ "${WITH_MODSECURITY}" == true ]; then
    git clone https://github.com/owasp-modsecurity/ModSecurity-nginx $HOMEDIRECTORY/nginx/mosc/ModSecurity-nginx
fi

if [ "${WITH_LUA}" == true ]; then
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

if [[ "${WITH_LUA}" == true && ! "${PRESERVE}" == true ]]; then
    sudo mkdir -p ${LUAJIT_BASE_PATH}
    git clone https://github.com/openresty/luajit2 $HOMEDIRECTORY/nginx-lua/luajit2
    cd $HOMEDIRECTORY/nginx-lua/luajit2 && make && sudo make install PREFIX=${LUAJIT_BASE_PATH}
fi

if [ "${WITH_LUA}" == true ]; then
    mkdir -p $HOMEDIRECTORY/nginx-lua && cd $HOMEDIRECTORY/nginx-lua
    git clone https://github.com/openresty/lua-resty-core $HOMEDIRECTORY/nginx-lua/lua-resty-core
    git clone https://github.com/openresty/lua-resty-lrucache $HOMEDIRECTORY/nginx-lua/lua-resty-lrucache
    git clone https://github.com/openresty/lua-resty-string $HOMEDIRECTORY/nginx-lua/lua-resty-string

    cd $HOMEDIRECTORY/nginx-lua/lua-resty-core && sudo make install PREFIX=${LUA_BASE_PATH} LUA_LIB_DIR=${LUA_BASE_PATH}
    cd $HOMEDIRECTORY/nginx-lua/lua-resty-lrucache && sudo make install PREFIX=${LUA_BASE_PATH} LUA_LIB_DIR=${LUA_BASE_PATH}
    cd $HOMEDIRECTORY/nginx-lua/lua-resty-string && sudo make install PREFIX=${LUA_BASE_PATH} LUA_LIB_DIR=${LUA_BASE_PATH}

    export LUAJIT_LIB=${LUAJIT_BASE_PATH}/lib
    export LUAJIT_INC=${LUAJIT_BASE_PATH}/include/luajit-2.1
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

if [ "${WITH_MODSECURITY}" == true ]; then
    NGINX_CONFIG_PARAMS+=(
        --add-dynamic-module=mosc/ModSecurity-nginx
    )
fi

# SomeHow, Nginx is broken when compiling as dynamic module with BoringSSL. 
# Compiling as module seems to fix this.
if [ "${WITH_LUA}" == true ]; then
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
    sudo touch /opt/quictls/.openssl/include/openssl/ssl.h
elif [ $SSL_LIB == "libressl" ]; then
    sudo touch /opt/libressl/.openssl/include/openssl/ssl.h
fi

make
exit_code=$?

#################################
##                             ##
##   Install Nginx(optional)   ##
##                             ##
#################################

if [[ "$Nginx_Install" == "yes" || "$INSTALL" == true ]] && [ "$exit_code" -eq 0 ]; then
    mkdir -p /lib/nginx/ && mkdir -p /lib/nginx/modules
    mkdir -p /etc/nginx && mkdir -p /etc/nginx/sites-enabled && mkdir -p /etc/nginx/modules-enabled
    cp $HOMEDIRECTORY/nginx/objs/*.so /lib/nginx/modules
    cp $HOMEDIRECTORY/nginx/objs/nginx /usr/sbin/nginx

    cat >modules.conf <<EOL
load_module /lib/nginx/modules/ngx_http_echo_module.so;
load_module /lib/nginx/modules/ngx_http_headers_more_filter_module.so;
load_module /lib/nginx/modules/ngx_http_brotli_filter_module.so;
load_module /lib/nginx/modules/ngx_http_brotli_static_module.so;
EOL

    if [ "${WITH_MODSECURITY}" == true ]; then
        cat >>modules.conf <<EOL
load_module /lib/nginx/modules/ngx_http_modsecurity_module.so;
EOL
    fi

    cp modules.conf /etc/nginx/modules-enabled
elif [[ ! $exit_code -eq 0 ]]; then
    panic "Nginx Build Failed..."
else
    info "Nginx_Install variable isn't set/vaild. Your Nginx assets location is : '%s'/nginx/objs" $HOMEDIRECTORY
fi