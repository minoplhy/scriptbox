# NGINX without Root
This is a mini project that I'll find any workaround for building NGINX without relies on Root Required Dependencies as much as possible

# Setup Script

### using Curl
```
curl https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx-noroot/build.sh | bash
```

### using Wget
```
wget https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx-noroot/build.sh | ./build.sh
```

# Root Required
I can't figure workaround for these dependencies

```
Openssl (unsuccessful build when using self compiled openssl)
  - libssl-dev
```