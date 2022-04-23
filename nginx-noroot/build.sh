Build_directory=~/nginx_build
User_home=~

rm -rf ~/nginx_build
mkdir ~/nginx_build && cd ~/nginx_build

# Get zlib
cd ~/nginx_build
if [[ -f "/usr/bin/curl" ]]; then
    curl -L https://zlib.net/zlib-1.2.12.tar.gz --output zlib-1.2.12.tar.gz
elif [[ -f "/usr/bin/wget" ]]; then
    wget https://zlib.net/zlib-1.2.12.tar.gz -O zlib-1.2.12.tar.gz
else
    echo "Required Dependencies for download zlib doesn't exist"
fi
tar xzf zlib-1.2.12.tar.gz

# Get pcre
cd ~/nginx_build
if [[ -f "/usr/bin/curl" ]]; then
    curl -L https://downloads.sourceforge.net/project/pcre/pcre/8.45/pcre-8.45.tar.gz --output pcre-8.45.tar.gz
elif [[ -f "/usr/bin/wget" ]]; then
    wget https://downloads.sourceforge.net/project/pcre/pcre/8.45/pcre-8.45.tar.gz -O pcre-8.45.tar.gz
else
    echo "Required Dependencies for download pcre doesn't exist"
fi
tar xzf pcre-8.45.tar.gz

# Build Nginx
cd ~/nginx_build
if [[ -f "/usr/bin/curl" ]]; then
    curl -L https://nginx.org/download/nginx-1.21.6.tar.gz --output nginx-1.21.6.tar.gz
elif [[ -f "/usr/bin/wget" ]]; then
    wget https://nginx.org/download/nginx-1.21.6.tar.gz -O nginx-1.21.6.tar.gz
else
    echo "Required Dependencies for download Nginx doesn't exist"
fi

tar xzf nginx-1.21.6.tar.gz && cd nginx-1.21.6

if [[ -f "/usr/bin/curl" ]]; then
    curl https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx-noroot/configure.sh | bash
elif [[ -f "/usr/bin/wget" ]]; then
    wget https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx-noroot/configure.sh | ./configure.sh
else
    echo "Required Dependencies for download configure script doesn't exist"
fi

make && make install

##
##
## Additional Part.
##
##

mkdir -p ~/nginx-settings/temp