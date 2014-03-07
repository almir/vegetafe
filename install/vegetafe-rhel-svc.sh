#!/bin/bash

# vegetafe     Start and stop Thin webserver.
#
# chkconfig: 235 99 05
# description: Start and stop Thin webserver.

### BEGIN INIT INFO
# Provides: vegetafe
# Required-Start: $local_fs $remote_fs $network $named
# Required-Stop: $local_fs $remote_fs $network
# Short-Description: Start and stop Thin webserver
# Description: Start and stop Thin webserver
### END INIT INFO

# Source function library
. /etc/rc.d/init.d/functions

# Source /usr/local/rvm/environments/default in order to get Ruby variables
. /usr/local/rvm/environments/default

# Vegeta Frontend global variables
CONFIG=/var/www/vegetafe/config.ru
PIDFILE=/var/run/vegetafe.pid
LOGFILE=/var/log/vegetafe.log

# SSL Certificate related variables
SSLKEY=/var/www/vegetafe/ssl/vegetafe.key
SSLCRT=/var/www/vegetafe/ssl/vegetafe.crt
 
case "$1" in
   start)
         echo -n $"Starting Thin webserver "
            thin start -R ${CONFIG} \
               --ssl --ssl-key-file ${SSLKEY} \
               --ssl-cert-file ${SSLCRT} \
               -P ${PIDFILE} -l ${LOGFILE} -t 1800 -p 9292 -d
         [ $? -eq 0 ] && success || \
            failure
         ;;
         
   stop)
         echo -n $"Stopping Thin webserver "
            thin stop -f -P ${PIDFILE} -l ${LOGFILE} 2> /dev/null
         [ $? -eq 0 ] && success || \
            failure
         ;;

   restart)
         $0 stop
         $0 start
         ;;
   
   *)
         echo $"Usage: "$0" {start|stop|restart}"
         exit 1
         ;;
esac

exit $?
