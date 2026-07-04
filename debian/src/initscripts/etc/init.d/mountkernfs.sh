#! /bin/sh
### BEGIN INIT INFO
# Provides:          mountkernfs
# Required-Start:
# Required-Stop:
# Should-Start:      glibc
# Default-Start:     S
# Default-Stop:
# Short-Description: Mount kernel virtual file systems.
# Description:       Mount initial set of virtual filesystems the kernel
#                    provides and that are required by everything.
### END INIT INFO

PATH=/sbin:/bin
. /lib/init/vars.sh
. /lib/init/tmpfs.sh

. /lib/lsb/init-functions
. /lib/init/mount-functions.sh

# May be run several times, so must be idempotent.
# $1: Mount mode, to allow for remounting
mount_filesystems() {
	MNTMODE="$1"

	#
	# Mount tmpfs on /run and/or /run/lock
	#
	mount_run "$MNTMODE"
	mount_lock "$MNTMODE"

	#
	# Mount proc filesystem on /proc
	#
	domount "$MNTMODE" proc "" /proc proc "-onodev,noexec,nosuid"

	if grep -E -qs 'securityfs$' /proc/filesystems; then
		domount "$MNTMODE" securityfs "" /sys/kernel/security securityfs
	fi

	#
	# Mount sysfs on /sys
	#
	# Only mount sysfs if it is supported (kernel >= 2.6)
	if grep -E -qs 'sysfs$' /proc/filesystems; then
		domount "$MNTMODE" sysfs "" /sys sysfs "-onodev,noexec,nosuid"
	fi

	if [ -d /sys/fs/pstore ]; then
		domount "$MNTMODE" pstore "" /sys/fs/pstore pstore ""
	fi

	#
	# Mount efivarfs on /sys/firmware/efi/efivars if necessary
	#
	efivarsmnt=/sys/firmware/efi/efivars
	if [ -d $efivarsmnt ]; then
		# domount is a no-op if already mounted
		domount "$MNTMODE" efivarfs "" $efivarsmnt none ""
	fi

	#
	# Mount specific additional requests
	#
	for fs in $EXTRAKERNELFS; do
		case $fs in
			debugfs)
				if grep -wqs 'debugfs$' /proc/filesystems && [ -d /sys/kernel/debug ]; then
					domount "$MNTMODE" debugfs "" /sys/kernel/debug debugfs -onodev,noexec,nosuid
				else
					echo "Warning: ignoring unavailable debugfs" >&2
				fi
				;;
			cgroup2)
				if grep -wqs 'cgroup2$' /proc/filesystems && [ -e /proc/cgroups ]; then
					domount "$MNTMOUDE" cgroup2 "" /sys/fs/cgroup cgroup2 -onodev,noexec,nosuid
				else
					echo "Warning: ignoring unavailable cgroup2" >&2
				fi
				;;
			*) echo "Warning: ignoring unsupported kernel filesystem $fs" >&2 ;;
		esac
	done
}

case "$1" in
	"")
		echo "Warning: mountkernfs should be called with the 'start' argument." >&2
		mount_filesystems mount_noupdate
		;;
	start)
		mount_filesystems mount_noupdate
		;;
	restart | reload | force-reload)
		mount_filesystems remount
		;;
	stop | status)
		# No-op
		;;
	*)
		echo "Usage: mountkernfs [start|stop]" >&2
		exit 3
		;;
esac
