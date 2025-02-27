# nginx_build_script is spin-off from [minoplhy/nginquic](https://github.com/minoplhy/nginquic)@ModSecurity_incl branch.

The script here is entirely copied from [minoplhy/nginquic](https://github.com/minoplhy/nginquic)@ModSecurity_incl. Which included ModSecurity for my own using.

```bash
export Nginx_Install=yes  # This variable is required if you want Nginx to be installed scriptibly (on Debian-based systems).
curl https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/build.sh > ~/nginx_scriptbox.sh
bash ~/nginx_scriptbox.sh
```
new way to run! :
```bash
# With install Nginx
curl https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/build.sh | bash -s -- --install
```

# Arguments
```bash
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

```

#### Note :  
* don't forgot to add necessary `lua_package_path` directive to `nginx.conf`, in the http context. else Nginx won't run.
```lua
lua_package_path "/usr/local/lua/?.lua;;";
```

* LibreSSL is broken when compile with Nginx Lua
taken from compiler:
```
error: implicit declaration of function ‘SSL_client_hello_get0_ext’ [-Werror=implicit-function-declaration]
```

systemd Template:
`Location : /lib/systemd/system/nginx.service`

```
# Stop dance for nginx
# =======================
#
# ExecStop sends SIGSTOP (graceful stop) to the nginx process.
# If, after 5s (--retry QUIT/5) nginx is still running, systemd takes control
# and sends SIGTERM (fast shutdown) to the main process.
# After another 5s (TimeoutStopSec=5), and if nginx is alive, systemd sends
# SIGKILL to all the remaining processes in the process group (KillMode=mixed).
#
# nginx signals reference doc:
# http://nginx.org/en/docs/control.html
#
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target

```

Nginx init.d

```initd
#!/sbin/openrc-run

description="Nginx http and reverse proxy server"
extra_commands="checkconfig"
extra_started_commands="reload reopen upgrade"

cfgfile=${cfgfile:-/etc/nginx/nginx.conf}
pidfile=/run/nginx.pid
command=${command:-/usr/sbin/nginx}
command_args="-c $cfgfile"
required_files="$cfgfile"

depend() {
        need net
        use dns logger netmount
}

start_pre() {
        checkpath --directory --owner www-data:www-data ${pidfile%/*}
        $command $command_args -t -q
}

checkconfig() {
        ebegin "Checking $RC_SVCNAME configuration"
        start_pre
        eend $?
}

reload() {
        ebegin "Reloading $RC_SVCNAME configuration"
        start_pre && start-stop-daemon --signal HUP --pidfile $pidfile
        eend $?
}

reopen() {
        ebegin "Reopening $RC_SVCNAME log files"
        start-stop-daemon --signal USR1 --pidfile $pidfile
        eend $?
}

upgrade() {
        start_pre || return 1

        ebegin "Upgrading $RC_SVCNAME binary"

        einfo "Sending USR2 to old binary"
        start-stop-daemon --signal USR2 --pidfile $pidfile

        einfo "Sleeping 3 seconds before pid-files checking"
        sleep 3

        if [ ! -f $pidfile.oldbin ]; then
                eerror "File with old pid ($pidfile.oldbin) not found"
                return 1
        fi

        if [ ! -f $pidfile ]; then
                eerror "New binary failed to start"
                return 1
        fi

        einfo "Sleeping 3 seconds before WINCH"
        sleep 3 ; start-stop-daemon --signal 28 --pidfile $pidfile.oldbin

        einfo "Sending QUIT to old binary"
        start-stop-daemon --signal QUIT --pidfile $pidfile.oldbin

        einfo "Upgrade completed"

        eend $? "Upgrade failed"
}

# modified from https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/main/nginx/nginx.initd
```
