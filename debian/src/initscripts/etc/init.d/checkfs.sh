#! /bin/sh
### BEGIN INIT INFO
# Provides:          checkfs
# Required-Start:    checkroot
# Required-Stop:
# Should-Start:      mdadm-raid
# Default-Start:     S
# Default-Stop:
# X-Interactive:     true
# Short-Description: Check all filesystems.
### END INIT INFO

PATH=/sbin:/bin
FSCK_LOGFILE=/var/log/fsck/checkfs
[ "$FSCKFIX" ] || FSCKFIX=no
. /lib/init/vars.sh

. /lib/lsb/init-functions
. /lib/init/mount-functions.sh

if command -v setterm >/dev/null 2>&1; then
	setterm=setterm
else
	setterm='true -- '
fi

do_start() {
	# Trap SIGINT so that we can handle user interupt of fsck.
	trap "" INT

	fscheck="yes"

	if is_fastboot_active; then
		[ "$fscheck" = yes ] && log_warning_msg "Fast boot enabled, so skipping file system check."
		fscheck=no
	fi

	#
	# Check the rest of the file systems.
	#
	if [ "$fscheck" = yes ] && [ "$FSCKTYPES" != "none" ]; then
		if [ -f /forcefsck ] || grep -q -s -w -i "forcefsck" /proc/cmdline; then
			log_warning_msg "forcefsck is DEPRECATED and will be removed. Ext[2,3,4] can be forcibly checked by using the tune2fs(8) -E force_fsck option"
			force="-f"
		else
			force=""
		fi
		if [ "$FSCKFIX" = yes ]; then
			fix="-y"
		else
			fix="-a"
		fi
		spinner="-C"
		case "$TERM" in
			dumb | network | unknown | "")
				spinner=""
				;;
		esac
		[ "$(uname -m)" = s390x ] && spinner="" # This should go away
		FSCKTYPES_OPT=""
		[ "$FSCKTYPES" ] && FSCKTYPES_OPT="-t $FSCKTYPES"
		handle_failed_fsck() {
			log_failure_msg "File system check failed. 
A log is being saved in ${FSCK_LOGFILE} if that location is writable. 
Please repair the file system manually."
			log_warning_msg "A maintenance shell will now be started. 
CONTROL-D will terminate this shell and resume system boot."
			# Start a single user shell on the console
			if ! sulogin --force $CONSOLE; then
				log_failure_msg "Attempt to start maintenance shell failed. 
Continuing with system boot in 5 seconds."
				sleep 5
			fi
		}
		if [ "$VERBOSE" = no ]; then
			log_action_begin_msg "Checking file systems"
			$setterm --msg off
			logsave_best_effort fsck $spinner -T -M -A $fix $force $FSCKTYPES_OPT
			FSCKCODE=$?
			$setterm --msg on

			if [ "$FSCKCODE" -eq 32 ]; then
				log_action_end_msg 1 "code $FSCKCODE"
				log_warning_msg "File system check was interrupted by user"
			elif [ "$FSCKCODE" -gt 1 ]; then
				log_action_end_msg 1 "code $FSCKCODE"
				handle_failed_fsck
			else
				log_action_end_msg 0
			fi
		else
			if [ "$FSCKTYPES" ]; then
				log_action_msg "Will now check all file systems of types $FSCKTYPES"
			else
				log_action_msg "Will now check all file systems"
			fi
			logsave_best_effort fsck $spinner -V -T -M -A $fix $force $FSCKTYPES_OPT
			FSCKCODE=$?
			if [ "$FSCKCODE" -eq 32 ]; then
				log_warning_msg "File system check was interrupted by user"
			elif [ "$FSCKCODE" -gt 1 ]; then
				handle_failed_fsck
			else
				log_success_msg 'Done checking file systems'
				log_success_msg "Log is being saved in ${FSCK_LOGFILE} if that location is writable"
			fi
		fi
	fi
	rm -f /fastboot /forcefsck 2>/dev/null
}

case "$1" in
	start | "")
		do_start
		;;
	restart | reload | force-reload)
		echo "Error: argument '$1' not supported" >&2
		exit 3
		;;
	stop | status)
		# No-op
		;;
	*)
		echo "Usage: checkfs.sh [start|stop]" >&2
		exit 3
		;;
esac

:
