cd ~/
curl -sSL https://raw.githubusercontent.com/minoplhy/script/main/nginquic/packages.sh | bash
mkdir nginquic && cd nginquic
hg clone -b quic https://hg.nginx.org/nginx-quic
git clone https://github.com/google/boringssl
cd boringssl
mkdir build && cd build && cmake .. && make
cd .. && cd ..
cd nginx-quic
mkdir mosc && cd mosc && curl -sSL https://raw.githubusercontent.com/minoplhy/script/main/nginquic/modules.sh | bash && cd ..
curl -sSL https://raw.githubusercontent.com/minoplhy/script/main/nginquic/configure.sh | bash && make
cd objs && cp *.so /lib/nginx/modules
cp nginx /usr/sbin/nginx
curl -sSL https://raw.githubusercontent.com/minoplhy/script/main/nginquic/modules.conf > modules.conf
cp modules.conf /etc/nginx/modules-enabled