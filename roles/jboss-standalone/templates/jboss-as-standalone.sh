#!/bin/sh
#
# JBoss standalone control script
#
# Provided in JBoss AS 7.1.1
# Modified for Ubuntu Server
#
# chkconfig: - 80 20
# processname: standalone
# pidfile: /var/run/jboss/jboss.pid
#
### BEGIN INIT INFO
# Provides:          jboss
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start/Stop JBoss AS 7
### END INIT INFO

DESC="JBoss 7.1.1"

# Source function library.
. /lib/lsb/init-functions


# Set defaults.

export JBOSS_HOME={{ jbossBase }}
export JBOSS_USER={{ jbossUser }}
export JBOSS_PIDFILE=/var/run/{{ jbossServiceName }}/{{ jbossServiceName }}.pid
export JBOSS_LOG_DIR={{ jbossBase }}/log

# We need this to be set to get a pidfile !
if [ -z "$LAUNCH_JBOSS_IN_BACKGROUND" ]; then
  LAUNCH_JBOSS_IN_BACKGROUND=true
fi
export LAUNCH_JBOSS_IN_BACKGROUND

if [ -z "$STARTUP_WAIT" ]; then
  STARTUP_WAIT=120
fi

if [ -z "$SHUTDOWN_WAIT" ]; then
  SHUTDOWN_WAIT=120
fi

JBOSS_SCRIPT=$JBOSS_HOME/bin/standalone.sh

prog='{{ jbossServiceName }}'


start() {
  log_daemon_msg "Starting $DESC"
  id $JBOSS_USER > /dev/null 2>&1
  if [ $? -ne 0 -o -z "$JBOSS_USER" ]; then
    log_failure_msg "User $JBOSS_USER does not exist..."
    log_end_msg 1
    exit 1
  fi
  if [ -f $JBOSS_PIDFILE ]; then
    read ppid < $JBOSS_PIDFILE
    if [ `ps --pid $ppid 2> /dev/null | grep -c $ppid 2> /dev/null` -eq '1' ]; then
      log_progress_msg "$prog is already running"
      log_end_msg 0
      exit 0
    else
      rm -f $JBOSS_PIDFILE
    fi
  fi
  mkdir -p $JBOSS_LOG_DIR
  # not sure: clear boot.log ... dunno if good, dunno if hardcoding boot.log good
  cat /dev/null > ${JBOSS_LOG_DIR}"/boot.log"
  # same as for boot.log, but we need to clear server.log to get proper launch detection (grepping later)
  cat /dev/null > ${JBOSS_LOG_DIR}"/server.log"
  chown -R ${JBOSS_USER}: $JBOSS_LOG_DIR

  mkdir -p $(dirname $JBOSS_PIDFILE)
  chown ${JBOSS_USER}: $(dirname $JBOSS_PIDFILE) || true

  if [ ! -z "$JBOSS_USER" ]; then
    start-stop-daemon --start -b -u "$JBOSS_USER" -c "$JBOSS_USER" -d "$JBOSS_HOME" -p "$JBOSS_PIDFILE" -x ${JBOSS_HOME}/"bin/standalone.sh" -- -Djboss.server.log.dir="$JBOSS_LOG_DIR"
  else
    log_failure_msg "Error: Environment variable JBOSS_USER not set or empty."
    log_end_msg 1
    exit 1
  fi

  count=0
  launched=false

  until [ $count -gt $STARTUP_WAIT ]
  do
    grep 'JBoss AS.*started in' ${JBOSS_LOG_DIR}"/server.log" > /dev/null 
    if [ $? -eq 0 ] ; then
      launched=true
      break
    fi
    sleep 1
    count=$((count+1));
  done

  if [ $launched=true ]; then
    if [ -f $JBOSS_PIDFILE ] && [ -s $JBOSS_PIDFILE ]; then
      log_progress_msg "Successfully started $DESC."
    else
      log_progress_msg "Successfully started $DESC, but problems with pidfile."
    fi
  else
    log_failure_msg "Launching $DESC failed."
    # If the pidfile exists, try to kill the process
    if [ -f $JBOSS_PIDFILE ] && [ -s $JBOSS_PIDFILE ]; then
      read kpid < $JBOSS_PIDFILE
      log_progress_msg "Pidfile detected. Please take care of process $kpid manually."
    fi
    log_end_msg 1
    exit 1
  fi

  # success
  log_end_msg 0
  return 0
}

stop() {
  log_daemon_msg "Stopping $DESC"
  count=0;

  if [ -f $JBOSS_PIDFILE ]; then
    read kpid < $JBOSS_PIDFILE
    kwait=$SHUTDOWN_WAIT

    # Try issuing SIGTERM

    kill -15 $kpid
    until [ `ps --pid $kpid 2> /dev/null | grep -c $kpid 2> /dev/null` -eq '0' ] || [ $count -gt $kwait ]
    do
      sleep 1
      count=$((count+1));
    done

    if [ $count -gt $kwait ]; then
      kill -9 $kpid
    fi
  fi
  rm -f $JBOSS_PIDFILE
  log_end_msg 0
  return 0
}

status() {
  if [ -f $JBOSS_PIDFILE ]; then
    read ppid < $JBOSS_PIDFILE
    if [ `ps --pid $ppid 2> /dev/null | grep -c $ppid 2> /dev/null` -eq '1' ]; then
      log_success_msg "$prog is running (pid $ppid)"
      exit 0
    else
      log_success_msg "$prog dead but pid file exists"
      exit 1
    fi
  fi
  log_success_msg "$prog is not running"
  exit 3
}

reload() {
  log_begin_msg "Reloading $prog ..."
  start-stop-daemon --start --quiet --background --chuid jboss --exec ${JBOSS_HOME}/bin/jboss-cli.sh -- --connect command=:reload
  log_end_msg $?
  exit $?
}

case "$1" in
  start)
      start
      ;;
  stop)
      stop
      ;;
  restart)
      $0 stop
      $0 start
      ;;
  status)
      status
      ;;
  reload)
      reload
      ;;
  *)
      ## If no parameters are given, print which are avaiable.
      echo "Usage: $0 {start|stop|status|restart|reload}"
      exit 1
      ;;
esac
