#!/usr/bin/env bash
# Low-battery alarm: sticky notification + looping sound.
# Modes: watch (daemon) | -test | stop | status

set -euo pipefail

BATTERY="${BATTERY:-/sys/class/power_supply/BAT1}"
AC="${AC:-/sys/class/power_supply/ACAD}"
ALARM="${ALARM:-$HOME/Downloads/alarm_sound.mp3}"
if [[ ! -r "$ALARM" && -r /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga ]]; then
    ALARM=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
fi
POLL_SECONDS="${POLL_SECONDS:-5}"
THRESHOLD="${THRESHOLD:-20}"
NOTIF_TITLE="${NOTIF_TITLE:-Low Battery}"
NOTIF_BODY="${NOTIF_BODY:-Battery Capacity is low, please plug in a charger.}"

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/low-battery-alarm"
LOG_FILE="$STATE_DIR/alarm.log"
mkdir -p "$STATE_DIR"

NOTIF_PID_FILE="$STATE_DIR/notif.pid"
ALARM_PID_FILE="$STATE_DIR/alarm.pid"
NOTIF_ID_FILE="$STATE_DIR/notif.id"
ACTIVE_FILE="$STATE_DIR/active"
DISMISSED_FILE="$STATE_DIR/dismissed"
TEST_FILE="$STATE_DIR/test"
REQUEST_TEST_FILE="$STATE_DIR/request-test"
REQUEST_STOP_FILE="$STATE_DIR/request-stop"

usage() {
    cat <<'EOFUSAGE'
Usage: low-alarm [command]

  (none) / watch   Run the battery watcher (used by systemd)
  -test, --test    Fire sticky notification + alarm now
  stop             Stop notification and alarm
  status           Show whether an alert is active

EOFUSAGE
}

read_file() {
    local path="$1"
    [[ -r "$path" ]] || return 1
    tr -d '[:space:]' <"$path"
}

is_plugged() {
    local online status
    online="$(read_file "$AC/online" 2>/dev/null || echo 0)"
    [[ "$online" == "1" ]] && return 0

    status="$(read_file "$BATTERY/status" 2>/dev/null || echo Unknown)"
    [[ "$status" == "Charging" || "$status" == "Full" ]]
}

is_low() {
    local capacity
    capacity="$(read_file "$BATTERY/capacity" 2>/dev/null || echo 100)"
    [[ "$capacity" =~ ^[0-9]+$ ]] || return 1
    (( capacity <= THRESHOLD ))
}

pid_alive() {
    local pid="$1"
    [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null
}

stop_alarm() {
    if [[ -f "$ALARM_PID_FILE" ]]; then
        local pid
        pid="$(<"$ALARM_PID_FILE")"
        if pid_alive "$pid"; then
            kill "$pid" 2>/dev/null || true
            kill -- "-$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
        rm -f "$ALARM_PID_FILE"
    fi
}

close_notification() {
    if [[ -f "$NOTIF_ID_FILE" ]]; then
        local id
        id="$(tr -d '[:space:]' <"$NOTIF_ID_FILE")"
        if [[ "$id" =~ ^[0-9]+$ ]]; then
            gdbus call --session \
                --dest org.freedesktop.Notifications \
                --object-path /org/freedesktop/Notifications \
                --method org.freedesktop.Notifications.CloseNotification \
                "$id" >/dev/null 2>&1 || true
        fi
        rm -f "$NOTIF_ID_FILE"
    fi

    if [[ -f "$NOTIF_PID_FILE" ]]; then
        local pid
        pid="$(<"$NOTIF_PID_FILE")"
        if pid_alive "$pid"; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
        rm -f "$NOTIF_PID_FILE"
    fi
}

stop_alert() {
    rm -f "$ACTIVE_FILE" "$TEST_FILE"
    stop_alarm
    close_notification
}

start_alarm() {
    stop_alarm
    if [[ ! -r "$ALARM" ]]; then
        echo "low-alarm: missing alarm file: $ALARM" >&2
        return 1
    fi

    : >"$LOG_FILE"
    setsid mpv \
        --no-video \
        --loop=inf \
        --ao=pipewire \
        --volume=100 \
        -- "$ALARM" >>"$LOG_FILE" 2>&1 &
    echo $! >"$ALARM_PID_FILE"

    sleep 0.3
    if ! pid_alive "$(<"$ALARM_PID_FILE")"; then
        echo "low-alarm: mpv failed to start — see $LOG_FILE" >&2
        [[ -s "$LOG_FILE" ]] && cat "$LOG_FILE" >&2
        return 1
    fi
}

start_notification() {
    local title="${1:-$NOTIF_TITLE}"
    local body="${2:-$NOTIF_BODY}"

    (
        notify-send \
            -p --id-fd=3 \
            --action="battery-dismiss=Dismiss" \
            -u critical \
            -t 0 \
            -a "Battery" \
            -i battery-caution \
            -c "device" \
            "$title" \
            "$body" 3>"$NOTIF_ID_FILE" >/dev/null || true

        stop_alarm
        # Action clicks can leave the notification in the center; close it too.
        if [[ -s "$NOTIF_ID_FILE" ]]; then
            id="$(<"$NOTIF_ID_FILE")"
            if [[ "$id" =~ ^[0-9]+$ ]]; then
                gdbus call --session --dest org.freedesktop.Notifications \
                    --object-path /org/freedesktop/Notifications \
                    --method org.freedesktop.Notifications.CloseNotification \
                    "$id" >/dev/null 2>&1 || true
            fi
        fi
        if [[ -f "$ACTIVE_FILE" && ! -f "$TEST_FILE" ]]; then
            touch "$DISMISSED_FILE"
        fi
        rm -f "$ACTIVE_FILE" "$TEST_FILE" "$NOTIF_PID_FILE"
    ) &
    echo $! >"$NOTIF_PID_FILE"

    for _ in $(seq 1 20); do
        [[ -s "$NOTIF_ID_FILE" ]] && break
        sleep 0.1
    done
}

start_alert() {
    local title="${1:-$NOTIF_TITLE}"
    local body="${2:-$NOTIF_BODY}"

    # Finish the old notification waiter before starting the new alert.
    close_notification
    stop_alarm
    touch "$ACTIVE_FILE"
    rm -f "$DISMISSED_FILE"
    start_alarm || echo "low-alarm: continuing without sound" >&2
    start_notification "$title" "$body"
}

service_running() {
    systemctl --user is-active --quiet low-battery-alarm.service 2>/dev/null
}

wait_for_flag_clear() {
    local flag="$1"
    local i
    for i in $(seq 1 50); do
        [[ ! -f "$flag" ]] && return 0
        sleep 0.1
    done
    return 1
}

cmd_stop() {
    if service_running; then
        touch "$REQUEST_STOP_FILE"
        if wait_for_flag_clear "$REQUEST_STOP_FILE"; then
            echo "low-alarm: stopped"
            return 0
        fi
    fi
    # Fallback if the daemon is not running
    stop_alert
    rm -f "$DISMISSED_FILE" "$REQUEST_TEST_FILE" "$REQUEST_STOP_FILE"
    echo "low-alarm: stopped"
}

cmd_status() {
    local cap ac status
    cap="$(read_file "$BATTERY/capacity" 2>/dev/null || echo "?")"
    ac="$(read_file "$AC/online" 2>/dev/null || echo "?")"
    status="$(read_file "$BATTERY/status" 2>/dev/null || echo "?")"

    echo "battery: ${cap}%  status: ${status}  ac: ${ac}  threshold: ${THRESHOLD}%"
    if [[ -f "$ACTIVE_FILE" ]] || [[ -f "$TEST_FILE" ]]; then
        echo "alert: active"
    elif [[ -f "$DISMISSED_FILE" ]]; then
        echo "alert: dismissed (waiting for charge / next cycle)"
    else
        echo "alert: idle"
    fi
    if [[ -f "$ALARM_PID_FILE" ]] && pid_alive "$(<"$ALARM_PID_FILE")"; then
        echo "sound: playing (pid $(<"$ALARM_PID_FILE"))"
    else
        echo "sound: off"
    fi
}

cmd_test() {
    if ! service_running; then
        echo "low-alarm: starting watcher service first..." >&2
        systemctl --user start low-battery-alarm.service
        sleep 0.5
    fi

    touch "$REQUEST_TEST_FILE"
    if wait_for_flag_clear "$REQUEST_TEST_FILE"; then
        echo "low-alarm: test started (notif + sound). Dismiss notif or run: low-alarm stop"
    else
        echo "low-alarm: test request timed out — is low-battery-alarm.service running?" >&2
        exit 1
    fi
}

cmd_watch() {
    cleanup() {
        trap - EXIT INT TERM
        stop_alert
        rm -f "$DISMISSED_FILE" "$REQUEST_TEST_FILE" "$REQUEST_STOP_FILE"
    }
    trap cleanup EXIT INT TERM

    for _ in $(seq 1 60); do
        if gdbus call --session \
            --dest org.freedesktop.Notifications \
            --object-path /org/freedesktop/Notifications \
            --method org.freedesktop.Notifications.GetCapabilities \
            >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    while true; do
        if [[ -f "$REQUEST_STOP_FILE" ]]; then
            stop_alert
            if ! is_plugged && is_low; then
                touch "$DISMISSED_FILE"
            fi
            rm -f "$REQUEST_STOP_FILE"
        fi

        if [[ -f "$REQUEST_TEST_FILE" ]]; then
            rm -f "$REQUEST_TEST_FILE" "$DISMISSED_FILE"
            touch "$TEST_FILE"
            start_alert \
                "Low Battery (test)" \
                "Test alarm — dismiss this notification or run: low-alarm stop"
        fi

        # Manual test owns the alert; skip battery logic until it ends
        if [[ -f "$TEST_FILE" ]]; then
            sleep 0.5
            continue
        fi

        if ! is_plugged && is_low; then
            if [[ ! -f "$ACTIVE_FILE" && ! -f "$DISMISSED_FILE" ]]; then
                start_alert
            fi
        elif is_plugged; then
            if [[ -f "$ACTIVE_FILE" || -f "$DISMISSED_FILE" || -f "$ALARM_PID_FILE" || -f "$NOTIF_PID_FILE" ]]; then
                stop_alert
                rm -f "$DISMISSED_FILE"
            fi
        else
            # Unplugged but above threshold
            if [[ -f "$ACTIVE_FILE" ]]; then
                stop_alert
            fi
            rm -f "$DISMISSED_FILE"
        fi

        sleep "$POLL_SECONDS"
    done
}

main() {
    local cmd="${1:-watch}"
    case "$cmd" in
        watch|daemon) cmd_watch ;;
        -test|--test|test) cmd_test ;;
        stop|-stop|--stop) cmd_stop ;;
        status|-status|--status) cmd_status ;;
        -h|--help|help) usage ;;
        *)
            echo "low-alarm: unknown command: $cmd" >&2
            usage >&2
            exit 1
            ;;
    esac
}

main "$@"
