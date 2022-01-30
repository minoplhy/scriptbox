cd ~/
curl -sSL packages.sh | bash
mkdir nginquic && cd nginquic
hg clone -b quic https://hg.nginx.org/nginx-quic
git clone https://github.com/google/boringssl
cd boringssl
mkdir build && cd build && cmake .. && make
cd .. && cd ..
cd nginx-quic
mkdir mosc && cd mosc && curl dependency.sh | bash && cd ..
curl -sSL configure.sh | bash && make
cd objs cp *.so /lib/nginx/modules
cp nginx /usr/sbin/nginx
curl modules.conf > modules.conf
cp modules.conf /etc/nginx/modules-enabled