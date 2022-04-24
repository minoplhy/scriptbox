STOPDAEMON=`which start-stop-daemon`

if [ "$STOPDAEMON" == "" ]; then
    if [[ "$STARTSTOPLOCATE" != "" ]]; then
        STOPDAEMON=$STARTSTOPLOCATE
    elif [[ -f "/usr/sbin/start-stop-daemon" ]]; then
        STOPDAEMON=/usr/sbin/start-stop-daemon
    elif [[ -f "/usr/bin/start-stop-daemon" ]]; then
	    STOPDAEMON=/usr/bin/start-stop-daemon
	elif [[ -f "/sbin/start-stop-daemon" ]]; then
	    STOPDAEMON=/sbin/start-stop-daemon
	elif [[ -f "/usr/local/sbin/start-stop-daemon" ]]; then
	    STOPDAEMON=/usr/local/sbin/start-stop-daemon
	elif [[ -f "/usr/local/bin/start-stop-daemon" ]]; then
	    STOPDAEMON=/usr/local/bin/start-stop-daemon
	else
	    echo "Script Can't find the location of start-stop-daemon"
		exit
	fi
else
    echo ""
fi

$STOPDAEMON --quiet --stop --retry QUIT/5 --pidfile ~/nginx-settings/run/nginx.pid