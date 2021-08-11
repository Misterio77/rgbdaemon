#!/usr/bin/env bash

source ${XDG_CONFIG_HOME:-$HOME/.config}/rgbdaemon.conf

PASTEL_BIN=${PASTEL_BIN:-/usr/bin/pastel}
PACTL_BIN=${PACTL_BIN:-/usr/bin/pactl}
PLAYERCTL_BIN=${PLAYERCTL_BIN:-/usr/bin/playerctl}
SWAYMSG_BIN=${SWAYMSG_BIN:-/usr/bin/swaymsg}
DAEMON_INTERVAL=${DAEMON_INTERVAL:-0.8}
KEYBOARD_DEVICE=${KEYBOARD_DEVICE:-/dev/input/ckb1/cmd}
MOUSE_DEVICE=${MOUSE_DEVICE:-/dev/input/ckb2/cmd}

base_colors() {
    echo "rgb $1" > $KEYBOARD_DEVICE
    echo "rgb $1" > $MOUSE_DEVICE
    echo "rgb $KEYBOARD_HIGHLIGHTED:$2" > $KEYBOARD_DEVICE
    echo "rgb $MOUSE_HIGHLIGHTED:$2" > $MOUSE_DEVICE
}

setcolor() {
    echo "rgb $1:$2" > $3
}

daemon_mute() {
    audio_input=$($PACTL_BIN info | grep "Default Source" | cut -f3 -d " ")
    audio_output=$($PACTL_BIN info | grep "Default Sink" | cut -f3 -d " ")
    input_muted=$($PACTL_BIN list sources | grep -A 10 "${audio_input}" | grep "Mute" | cut -d ":" -f2 | xargs)
    output_muted=$($PACTL_BIN list sinks | grep -A 10 "${audio_output}" | grep "Mute" | cut -d ":" -f2 | xargs)

    if [[ "$output_muted" == "yes" ]] && [[ "$input_muted" == "yes" ]]; then
        setcolor "mute" "$4" $KEYBOARD_DEVICE
    elif [[ "$input_muted" == "yes" ]]; then
        setcolor "mute" $3 $KEYBOARD_DEVICE
    elif [[ "$output_muted" == "yes" ]]; then
        setcolor "mute" $2 $KEYBOARD_DEVICE
    else
        setcolor "mute" $1 $KEYBOARD_DEVICE
    fi
}
daemon_tty() {
    for n in 1 2 3 4 5 6; do
        if ttystatus=$(w | grep tty$n) && ! echo $ttystatus | grep -q "agetty" ; then
            if echo $ttystatus | grep -q "way"; then
                setcolor "f$n" $1 $KEYBOARD_DEVICE
            else
                setcolor "f$n" $2 $KEYBOARD_DEVICE
            fi
        else
            setcolor "f$n" $3 $KEYBOARD_DEVICE
        fi
    done
}

daemon_workspaces() {
    declare -a workspaces=()
    while read line; do
        num=$(echo $line | awk '{printf $2}')
        if echo $line | grep "focused" -q; then
            workspaces[$num]=$1
        elif echo $line | grep "off-screen" -q; then
            workspaces[$num]=$3
        else
            workspaces[$num]=$2
        fi
    done <<<$($SWAYMSG_BIN -t get_workspaces -p | grep Workspace)
    for num in $(seq 0 9); do
        color=${workspaces[$num]}
        if [ -z "$color" ]; then
            color=$5
        fi
        setcolor $num $color $KEYBOARD_DEVICE
    done
}
daemon_player() {
    status=$($PLAYERCTL_BIN status 2>/dev/null | head -n 1)
    if [[ $status == "Playing" ]]; then
        setcolor "play" $1 $KEYBOARD_DEVICE
    elif [[ $status == "Paused" ]]; then
        setcolor "play" $2 $KEYBOARD_DEVICE
    else
        setcolor "play" $3 $KEYBOARD_DEVICE
    fi
}
daemon_lock() {
    if pgrep -x swaylock > /dev/null; then
        setcolor "lock" $1 $KEYBOARD_DEVICE
    else
        setcolor "lock" $2 $KEYBOARD_DEVICE
    fi
}
bindings() {
    echo "bind profswitch:f13" > $KEYBOARD_DEVICE
    echo "bind lock:f14" > $KEYBOARD_DEVICE
    echo "bind light:f15" > $KEYBOARD_DEVICE
    echo "bind thumb1:1" > $MOUSE_DEVICE
    echo "bind thumb2:2" > $MOUSE_DEVICE
    echo "bind thumb3:3" > $MOUSE_DEVICE
    echo "bind thumb4:4" > $MOUSE_DEVICE
    echo "bind thumb5:5" > $MOUSE_DEVICE
    echo "bind thumb6:6" > $MOUSE_DEVICE
    echo "bind thumb7:7" > $MOUSE_DEVICE
    echo "bind thumb8:8" > $MOUSE_DEVICE
    echo "bind thumb9:9" > $MOUSE_DEVICE
    echo "bind thumb10:0" > $MOUSE_DEVICE
    echo "bind thumb11:minus" > $MOUSE_DEVICE
    echo "bind thumb12:equal" > $MOUSE_DEVICE
    echo "bind dpiup:mouse4" > $MOUSE_DEVICE
    echo "bind dpidn:mouse5" > $MOUSE_DEVICE
}

startup() {
    if [ -n "${rgb_pid}" ]; then
        kill "${rgb_pid}"
    fi

    export color_primary=$($PASTEL_BIN mix $COLOR_BACKGROUND --fraction 0.7 $COLOR_FOREGROUND | $PASTEL_BIN darken 0.1 | $PASTEL_BIN saturate 0.5 | $PASTEL_BIN format hex | cut -d '#' -f2)
    export color_secondary=$($PASTEL_BIN darken 0.1 $COLOR_SECONDARY | $PASTEL_BIN saturate 0.8 | $PASTEL_BIN format hex | cut -d '#' -f2)
    export color_tertiary=$($PASTEL_BIN saturate 0.1 $COLOR_TERTIARY | $PASTEL_BIN format hex | cut -d '#' -f2)
    export color_quaternary=$($PASTEL_BIN lighten 0.1 $COLOR_QUATERNARY | $PASTEL_BIN format hex | cut -d '#' -f2)

    echo "dpi 1:$MOUSE_DPI dpisel 1" > $MOUSE_DEVICE
    base_colors $color_primary $color_secondary & \
    #openrgb --client --device 0 --color $color_primary --mode static & \
    rgb_daemon & rgb_pid=$!
    wait
}

off() {
    echo "rgb 000000" > $MOUSE_DEVICE & \
    echo "rgb 000000" > $KEYBOARD_DEVICE
    exit
}

rgb_daemon() {
    while sleep $DAEMON_INTERVAL; do
        [[ "$ENABLE_WORKSPACES" == 1 ]] && \
            daemon_workspaces $color_secondary $color_tertiary $color_quaternary $color_primary & \
        [[ "$ENABLE_MUTE" == 1 ]] && \
            daemon_mute "000000" $color_primary $color_tertiary $color_secondary & \
        [[ "$ENABLE_TTY" == 1 ]] && \
            daemon_tty $color_secondary $color_tertiary $color_primary & \
        [[ "$ENABLE_LOCK" == 1 ]] && \
            daemon_lock $color_secondary $color_primary & \
        [[ "$ENABLE_PLAYER" == 1 ]] && \
            daemon_player $color_secondary $color_tertiary $color_primary & \
    done
}

trap startup SIGHUP
trap off SIGTERM

# Activate devices
echo active > $KEYBOARD_DEVICE || exit -1
echo active > $MOUSE_DEVICE || exit -1

# Set up bindings
bindings
# Run daemon
startup
