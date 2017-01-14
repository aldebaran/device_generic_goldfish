#!/system/bin/sh

# Setup networking when boot starts
ifconfig eth0 10.0.2.15 netmask 255.255.255.0 up
route add default gw 10.0.2.2 dev eth0

# ro.kernel.android.qemud is normally set when we
# want the RIL (radio interface layer) to talk to
# the emulated modem through qemud.
#
# However, this will be undefined in two cases:
#
# - When we want the RIL to talk directly to a guest
#   serial device that is connected to a host serial
#   device by the emulator.
#
# - We don't want to use the RIL but the VM-based
#   modem emulation that runs inside the guest system
#   instead.
#
# The following detects the latter case and sets up the
# system for it.
#
qemud=`getprop ro.kernel.android.qemud`
case "$qemud" in
    "")
    radio_ril=`getprop ro.kernel.android.ril`
    case "$radio_ril" in
        "")
        # no need for the radio interface daemon
        # telephony is entirely emulated in Java
        setprop ro.radio.noril yes
        stop ril-daemon
        ;;
    esac
    ;;
esac

# Setup additionnal DNS servers if needed
num_dns=`getprop ro.kernel.ndns`
case "$num_dns" in
    2) setprop net.eth0.dns2 10.0.2.4
       ;;
    3) setprop net.eth0.dns2 10.0.2.4
       setprop net.eth0.dns3 10.0.2.5
       ;;
    4) setprop net.eth0.dns2 10.0.2.4
       setprop net.eth0.dns3 10.0.2.5
       setprop net.eth0.dns4 10.0.2.6
       ;;
esac

# disable boot animation for a faster boot sequence when needed
boot_anim=`getprop ro.kernel.android.bootanim`
case "$boot_anim" in
    0)  setprop debug.sf.nobootanimation 1
    ;;
esac

# set up the second interface (for inter-emulator connections)
# if required
my_ip=`getprop net.shared_net_ip`
case "$my_ip" in
    "")
    ;;
    *) ifconfig eth1 "$my_ip" netmask 255.255.255.0 up
    ;;
esac

#
# Houdini integration (Native Bridge)
#
houdini_bin=0
dest_dir=/system/lib$1/arm$1
binfmt_misc_dir=/proc/sys/fs/binfmt_misc

# if you don't see the files 'register' and 'status' in /proc/sys/fs/binfmt_misc
# then run the following command:
# mount -t binfmt_misc none /proc/sys/fs/binfmt_misc

# this is to add the supported binary formats via binfmt_misc

if [ ! -e $binfmt_misc_dir/register ]; then
	mount -t binfmt_misc none $binfmt_misc_dir
fi

cd $binfmt_misc_dir
if [ -e register ]; then
	# register Houdini for arm binaries
	if [ -z "$1" ]; then
		echo ':arm_exe:M::\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x28::'"$dest_dir/houdini:P" > register
		echo ':arm_dyn:M::\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x03\\x00\\x28::'"$dest_dir/houdini:P" > register
	else
		echo ':arm64_exe:M::\\x7f\\x45\\x4c\\x46\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\xb7::'"$dest_dir/houdini64:P" > register
		echo ':arm64_dyn:M::\\x7f\\x45\\x4c\\x46\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x03\\x00\\xb7::'"$dest_dir/houdini64:P" > register
	fi
	if [ -e arm${1}_exe ]; then
		houdini_bin=1
	fi
else
	log -pe -thoudini "No binfmt_misc support"
fi

if [ $houdini_bin -eq 0 ]; then
	log -pe -thoudini "houdini$1 enabling failed!"
else
	log -pi -thoudini "houdini$1 enabled"
fi

[ "$(getprop ro.zygote)" = "zygote64_32" -a -z "$1" ] && exec $0 64

