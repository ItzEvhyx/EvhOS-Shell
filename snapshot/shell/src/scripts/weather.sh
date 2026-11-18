#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/config.sh"
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/i18n.sh"

qs_ensure_cache "weather"

export LC_ALL=C

cache_dir="$QS_CACHE_WEATHER"
json_file="${cache_dir}/weather.json"
view_file="${cache_dir}/view_id"

VERBOSE=false
ACTION=""
DIRECTION=""
LOC_ARG=""
UNIT_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --location)
            LOC_ARG="$2"
            shift 2
            ;;
        --unit)
            UNIT_ARG="$2"
            shift 2
            ;;
        --getdata|--json|--view-listener|--icon|--temp|--hex|--current-icon|--current-temp|--current-hex)
            ACTION="$1"
            shift
            ;;
        --nav)
            ACTION="$1"
            DIRECTION="$2"
            shift 2
            ;;
        *)
            if [[ -z "$ACTION" ]]; then
                ACTION="$1"
            fi
            shift
            ;;
    esac
done

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\e[1;34m[WEATHER-DEBUG]\e[0m $1" >&2
    fi
}

UNIT="${UNIT_ARG:-${WEATHER_UNIT:-${OPENWEATHER_UNIT:-metric}}}"
log_debug "Using weather unit profile: $UNIT"

case "$UNIT" in
    "imperial") UNIT_SYM="°F" ;;
    "standard") UNIT_SYM="K" ;;
    *) UNIT_SYM="°C" ;;
esac

mkdir -p "${cache_dir}"

STALE_LIMIT=86400

get_weather_i18n_json() {
    jq -n \
        --arg sunny "$(t "weather.desc.sunny")" \
        --arg clear "$(t "weather.desc.clear")" \
        --arg cloudy "$(t "weather.desc.cloudy")" \
        --arg mist "$(t "weather.desc.mist")" \
        --arg rainy "$(t "weather.desc.rainy")" \
        --arg snow "$(t "weather.desc.snow")" \
        --arg storm "$(t "weather.desc.storm")" \
        --arg unknown "$(t "weather.desc.unknown")" \
        '{
            sunny: $sunny,
            clear: $clear,
            cloudy: $cloudy,
            mist: $mist,
            rainy: $rainy,
            snow: $snow,
            storm: $storm,
            unknown: $unknown
        }'
}

get_location() {
    if [[ -n "$LOC_ARG" && "$LOC_ARG" != "null" && "$LOC_ARG" != "{}" ]]; then
        echo "$LOC_ARG"
        return
    fi
    local gen_json loc_json
    gen_json="$(get_setting "general" '{}')"
    loc_json="$(echo "$gen_json" | jq -c '.location // empty' 2>/dev/null)"

    if [[ -z "$loc_json" || "$loc_json" == "null" ]]; then
        script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
        if [[ "$VERBOSE" == "true" ]]; then
            loc_json="$("${script_dir}/location.sh" --verbose)"
        else
            loc_json="$("${script_dir}/location.sh")"
        fi
    fi
    echo "$loc_json"
}

write_dummy_data() {
    log_debug "Writing fallback dummy data to $json_file"
    local desc_offline
    desc_offline="$(t "weather.desc.offline")"
    final_json="["
    for i in {0..4}; do
        future_date=$(date -d "+$i days")
        f_day_raw=$(date -d "$future_date" "+%a")
        f_full_day_raw=$(date -d "$future_date" "+%A")
        f_m_raw=$(date -d "$future_date" "+%b")
        f_d_raw=$(date -d "$future_date" "+%d")

        f_day="$(t "weather.days.${f_day_raw,,}")"
        f_full_day="$(t "weather.days.${f_full_day_raw,,}")"
        f_month="$(t "weather.months.${f_m_raw,,}")"
        f_date_num="${f_d_raw} ${f_month}"

        final_json="${final_json} {
            \"id\": \"${i}\",
            \"day\": \"${f_day}\",
            \"day_full\": \"${f_full_day}\",
            \"date\": \"${f_date_num}\",
            \"icon\": \"\",
            \"hex\": \"#cdd6f4\",
            \"desc\": \"${desc_offline}\",
            \"hourly\": []
        },"
    done
    final_json="${final_json%,}]"
    echo "{ \"latitude\": 0.0, \"longitude\": 0.0, \"location_updated_at\": 0, \"unit\": \"${UNIT}\", \"unit_sym\": \"${UNIT_SYM}\", \"offline\": true, \"current_icon\": \"\", \"current_hex\": \"#cdd6f4\", \"forecast\": ${final_json} }" > "${json_file}"
}

mark_offline_if_stale() {
    if [ ! -f "$json_file" ]; then
        write_dummy_data
        return
    fi
    local fetched_at age
    fetched_at=$(jq -r '.fetched_at // 0' "$json_file" 2>/dev/null)
    [[ -z "$fetched_at" || "$fetched_at" == "null" ]] && fetched_at=0
    age=$(( $(date +%s) - fetched_at ))
    if [ $age -ge $STALE_LIMIT ]; then
        log_debug "Cached forecast is older than $STALE_LIMIT seconds. Switching to offline data."
        write_dummy_data
    fi
}

get_data() {
    local loc_json i18n_json script_dir
    loc_json=$(get_location)
    i18n_json=$(get_weather_i18n_json)
    script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
    # evhos-weather-met-v1: keep the CLI and cache schema shared by all widgets.
    python3 "${script_dir}/weather-met.py" \
        --location "$loc_json" --unit "$UNIT" --i18n "$i18n_json" \
        --cache-dir "$cache_dir"
}

if [[ "$ACTION" == "--getdata" ]]; then
    get_data || true

elif [[ "$ACTION" == "--json" ]]; then
    # The adapter handles provider HTTP caching, atomic publication and retries.
    # QML runs this asynchronously; don't orphan background fetches on each read.
    get_data
    cat "$json_file"

elif [[ "$ACTION" == "--view-listener" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    tail -F "$view_file"

elif [[ "$ACTION" == "--nav" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    current=$(cat "$view_file")
    direction="$DIRECTION"
    max_idx=4
    if [[ "$direction" == "next" ]]; then
        if [ "$current" -lt "$max_idx" ]; then
            new=$((current + 1))
            echo "$new" > "$view_file"
        fi
    elif [[ "$direction" == "prev" ]]; then
        if [ "$current" -gt 0 ]; then
            new=$((current - 1))
            echo "$new" > "$view_file"
        fi
    fi

elif [[ "$ACTION" == "--icon" ]]; then
    cat "$json_file" | jq -r '.forecast[0].icon'

elif [[ "$ACTION" == "--temp" ]]; then 
    t=$(cat "$json_file" | jq -r '.forecast[0].max // empty' 2>/dev/null)
    echo "${t:---}${UNIT_SYM}"

elif [[ "$ACTION" == "--hex" ]]; then 
    cat "$json_file" | jq -r '.forecast[0].hex'

elif [[ "$ACTION" == "--current-icon" ]]; then
    icon=$(cat "$json_file" | jq -r '.current_icon // empty' 2>/dev/null)
    if [[ -z "$icon" || "$icon" == "null" ]]; then 
        get_data
        icon=$(cat "$json_file" | jq -r '.current_icon')
    fi
    echo "$icon"

elif [[ "$ACTION" == "--current-temp" ]]; then 
    t=$(cat "$json_file" | jq -r '.current_temp // empty' 2>/dev/null)
    if [[ -z "$t" || "$t" == "null" ]]; then 
        get_data
        t=$(cat "$json_file" | jq -r '.current_temp // "--"')
    fi
    echo "${t}${UNIT_SYM}"

elif [[ "$ACTION" == "--current-hex" ]]; then
    hex=$(cat "$json_file" | jq -r '.current_hex // empty' 2>/dev/null)
    if [[ -z "$hex" || "$hex" == "null" ]]; then 
        get_data
        hex=$(cat "$json_file" | jq -r '.current_hex')
    fi
    echo "$hex"
fi
