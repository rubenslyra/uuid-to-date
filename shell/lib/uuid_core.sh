#!/usr/bin/env bash
# uuid_core.sh — Biblioteca pura de analise de UUID conforme RFC 9562.
# Sourced library: sem efeitos colaterais, apenas funcoes e constantes.
# Layout do UUID (128 bits):
#   [0..47]   unix_ts_ms  (big-endian, 6 bytes)  — apenas na versao 7
#   [48..63]  ver (4 bits) + var (2 bits)
#   [64..127] rand_a / rand_b

# Janela de plausibilidade do unix_ts_ms (era RFC 9562).
UUID_MIN_MS=1640995200000        # 2022-01-01T00:00:00Z (UUIDv7 existe desde o draft uuidrev, jan/2022)
UUID_MAX_SKEW_MS=86400000        # tolerancia de relogio: +24h

uuid_normalize() {
    local raw="${1//-/}"
    raw="${raw// /}"
    [[ "$raw" =~ ^[0-9A-Fa-f]{32}$ ]] || return 1
    printf '%s\n' "${raw,,}"
}

uuid_version() {
    printf '%d\n' "$((16#${1:12:1}))"
}

uuid_version_name() {
    case "$1" in
        0) printf 'unspecified\n' ;;
        1) printf 'time-based (MAC)\n' ;;
        2) printf 'DCE security\n' ;;
        3) printf 'MD5 namespace\n' ;;
        4) printf 'random\n' ;;
        5) printf 'SHA-1 namespace\n' ;;
        6) printf 'Microsoft (SID)\n' ;;
        7) printf 'Unix epoch milliseconds\n' ;;
        8) printf 'custom\n' ;;
        *) printf 'future/unknown\n' ;;
    esac
}

uuid_variant() {
    case "${1:16:1}" in
        [0-7])  printf 'NCS (backward compatible)\n' ;;
        [89ab]) printf 'RFC 9562\n' ;;
        [cd])   printf 'Reserved (Microsoft)\n' ;;
        *)      printf 'Reserved (future)\n' ;;
    esac
}

uuid_ts_hex() {
    printf '%s\n' "${1:0:12}"
}

uuid_ts_ms() {
    printf '%d\n' "$((16#${1:0:12}))"
}

uuid_ts_plausible() {
    local ms=$1
    (( ms >= UUID_MIN_MS )) || return 1
    (( ms <= $(($(date +%s) * 1000 + UUID_MAX_SKEW_MS)) )) || return 1
    return 0
}

uuid_to_utc_iso() {
    local ms=$1
    local sec=$((ms / 1000)) msec=$((ms % 1000))
    printf '%s.%03dZ\n' "$(date -u -d "@$sec" +'%Y-%m-%dT%H:%M:%S')" "$msec"
}

uuid_to_local_iso() {
    local ms=$1
    local sec=$((ms / 1000)) msec=$((ms % 1000))
    printf '%s.%03d%s\n' \
        "$(date -d "@$sec" +'%Y-%m-%dT%H:%M:%S')" \
        "$msec" \
        "$(date -d "@$sec" +'%:z')"
}
