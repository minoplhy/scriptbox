# nginx_build_script is spin-off from [minoplhy/nginquic](https://github.com/minoplhy/nginquic)@ModSecurity_incl branch.

The script here is entirely copied from [minoplhy/nginquic](https://github.com/minoplhy/nginquic)@ModSecurity_incl. Which included ModSecurity for my own using.

```bash
export Nginx_Install=yes  # This variable is required if you want Nginx to be installed scriptibly (on Debian-based systems).
curl https://raw.githubusercontent.com/minoplhy/scriptbox/main/nginx_build_script/build.sh > ~/nginx_scriptbox.sh
bash ~/nginx_scriptbox.sh
```

# Arguments
```bash
while [ ${#} -gt 0 ]; do
    case "$1" in
        --no-modsecurity | -nm )
            DISABLE_MODSECURITY=true        # Not include ModSecurity in building
            ;;
        --no-lua | -nl )
            DISABLE_LUA=true                # Not include Lua in building
            ;;
        *)
            ;;
    esac
    shift
done
```

#### Note :  don't forgot to add necessary `lua_package_path` directive to `nginx.conf`, in the http context. else Nginx won't run.
```lua
lua_package_path "/usr/local/lua/?.lua;;';
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
