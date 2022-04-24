STOPDAEMON=`which start-stop-daemon`

$STOPDAEMON --quiet --stop --retry QUIT/5 --pidfile ~/nginx-settings/run/nginx.pid