git clone https://github.com/openresty/headers-more-nginx-module
git clone https://github.com/sto/ngx_http_auth_pam_module
git clone https://github.com/arut/nginx-dav-ext-module/
git clone https://github.com/openresty/echo-nginx-module
git clone https://github.com/nginx-modules/ngx_cache_purge
git clone https://github.com/SpiderLabs/ModSecurity-nginx
# git clone https://github.com/openresty/lua-nginx-module
# git clone https://github.com/vision5/ngx_devel_kit

# Lurking with ngx_brotli
# The step will be a lot diffirent from another modules, as it a requirement from upstream repository. Not ME!

git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli
cd ngx_brotli/deps/brotli
mkdir out && cd out
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..
cmake --build . --config Release --target brotlienc
cd ../../../..