#!/usr/bin/env bash
# main.sh — Bootstrap da aplicacao (Unix/WSL/Git Bash).
# Orquestra os modulos em src/ e expoe os subcomandos decode e batch.
#
# Uso:
#   ./main.sh decode -u <uuid> [-o <arquivo.csv>] [-q]
#   ./main.sh batch  -i <entrada> -o <saida.csv>
#   ./main.sh help
#
# Canais customizaveis (FD 3 = dados de maquina):
#   ./main.sh decode -u <uuid> 3>linha.csv
#   NO_COLOR=1 ./main.sh decode -u <uuid>
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LIB="$ROOT/lib"
DATA="$ROOT/data"

source "$LIB/output.sh"
source "$LIB/uuid_core.sh"

usage() {
    cat <<EOF
UUID to Date — engenharia reversa de UUID (RFC 9562)

Uso: $0 <comando> [opcoes]

Comandos:
  decode -u <uuid> [-o <csv>] [-q]   Processa UNIDADE (um UUID)
  batch  -i <entrada> -o <saida.csv> Processa LOTE (arquivo -> CSV)
  help                               Mostra esta ajuda

Exemplos:
  $0 decode -u 018f43a5-9280-7000-8000-000000000000
  $0 decode -u 8426a8c8-3ca8-414f-ad50-f6147b9ceab2 -o data/linha.csv
  $0 batch  -i data/lista_uuid.txt -o data/relatorio_datas.csv
  $0 decode -u <uuid> 3>linha.csv    # CSV no FD 3
EOF
}

cmd_decode() {
    local UUID="" OUT_FILE="" QUIET=0
    while getopts ":u:o:qh" opt; do
        case "$opt" in
            u) UUID=$OPTARG ;;
            o) OUT_FILE=$OPTARG ;;
            q) QUIET=1 ;;
            h) usage; return 0 ;;
            \?) err "opcao invalida: -$OPTARG"; return 2 ;;
            :) err "opcao -$OPTARG exige argumento"; return 2 ;;
        esac
    done

    if [[ -z "$UUID" ]]; then
        err "informe um UUID com -u <uuid>"
        return 2
    fi

    output_init
    ensure_data_channel "$OUT_FILE"

    if ! CLEAN=$(uuid_normalize "$UUID"); then
        err "entrada invalida: '$UUID' nao e um UUID (esperado 32 hex ou 8-4-4-4-12)"
        return 1
    fi

    local VER VAR TS_HEX MS CSV_TS_HEX DATE_UTC="" DATE_LOCAL="" PLAUSIBLE
    VER=$(uuid_version "$CLEAN")
    VAR=$(uuid_variant "$CLEAN")
    TS_HEX=$(uuid_ts_hex "$CLEAN")
    MS=$(uuid_ts_ms "$CLEAN")
    CSV_TS_HEX="0x$TS_HEX"

    if [[ "$QUIET" -eq 0 ]]; then
        echo ""
        hdr "--- ENGENHARIA REVERSA DE UUID (RFC 9562) ---"
        say "UUID Analisado  : $UUID"
        acc "Identidade      : v$VER ($(uuid_version_name "$VER")) · variante $VAR"
    fi

    if [[ "$VER" -ne 7 ]]; then
        warn "nao e UUIDv7: os 48 bits iniciais (0x$TS_HEX) NAO sao timestamp — dado aleatório; data nao calculada"
        if [[ "$QUIET" -eq 0 ]]; then
            dim "unix_ts_ms (hex): $TS_HEX  (48 bits iniciais, sem significado de tempo)"
            hdr "--------------------------------------------------"
            echo ""
        fi
        data "\"$UUID\",\"v$VER\",\"$VAR\",\"$CSV_TS_HEX\",\"$MS\",\"\",\"\",\"nao (v$VER)\""
        return 3
    fi

    PLAUSIBLE="sim"
    if uuid_ts_plausible "$MS"; then
        DATE_UTC=$(uuid_to_utc_iso "$MS")
        DATE_LOCAL=$(uuid_to_local_iso "$MS")
    else
        PLAUSIBLE="nao (fora de faixa)"
        DATE_UTC=$(uuid_to_utc_iso "$MS" 2>/dev/null || echo "")
        DATE_LOCAL=$(uuid_to_local_iso "$MS" 2>/dev/null || echo "")
    fi

    if [[ "$QUIET" -eq 0 ]]; then
        dim "unix_ts_ms (hex): $TS_HEX  (48 bits, big-endian)"
        dim "unix_ts_ms (dec): $MS ms"
        if [[ "$PLAUSIBLE" == "sim" ]]; then
            ok  "Data UTC        : $DATE_UTC"
            ok  "Data Local      : $DATE_LOCAL"
        else
            warn "timestamp fora da faixa plausivel ($MS ms) — data nao confiavel"
            say "Data UTC        : $DATE_UTC  [NAO CONFIABEL]"
            say "Data Local      : $DATE_LOCAL  [NAO CONFIABEL]"
        fi
        hdr "--------------------------------------------------"
        echo ""
    fi

    data "\"$UUID\",\"v$VER\",\"$VAR\",\"$CSV_TS_HEX\",\"$MS\",\"$DATE_UTC\",\"$DATE_LOCAL\",\"$PLAUSIBLE\""
    [[ "$PLAUSIBLE" == "sim" ]] || return 3
    return 0
}

cmd_batch() {
    local INPUT="" OUTPUT=""
    while getopts ":i:o:h" opt; do
        case "$opt" in
            i) INPUT=$OPTARG ;;
            o) OUTPUT=$OPTARG ;;
            h) usage; return 0 ;;
            \?) err "opcao invalida: -$OPTARG"; return 2 ;;
            :) err "opcao -$OPTARG exige argumento"; return 2 ;;
        esac
    done

    if [[ -z "$INPUT" || -z "$OUTPUT" ]]; then
        err "informe -i <arquivo_entrada> e -o <arquivo_saida.csv>"
        return 2
    fi
    if [[ ! -f "$INPUT" ]]; then
        err "arquivo de entrada nao encontrado: $INPUT"
        return 2
    fi

    output_init
    if [[ "$OUTPUT" == "-" ]]; then
        exec 3>&1
        exec 1>&2
    else
        exec 3>"$OUTPUT"
    fi

    data '"UUID_Original","Versao","Variante","Timestamp_Hex_48b","Epoch_Milissegundos","Data_UTC_ISO8601","Data_Local_Maquina","Timestamp_Plausivel"'

    local total=0 ok_count=0 not_v7=0 out_of_range=0 invalid=0
    local line uuid CLEAN VER VAR TS_HEX MS PLAUSIBLE DATE_UTC DATE_LOCAL

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -z "${line// /}" ]]; then continue; fi
        total=$((total + 1))
        uuid="$line"

        if ! CLEAN=$(uuid_normalize "$uuid"); then
            warn "[$total] entrada invalida ignorada: '$uuid'"
            invalid=$((invalid + 1))
            continue
        fi

        VER=$(uuid_version "$CLEAN")
        VAR=$(uuid_variant "$CLEAN")
        TS_HEX=$(uuid_ts_hex "$CLEAN")
        MS=$(uuid_ts_ms "$CLEAN")

        if [[ "$VER" -ne 7 ]]; then
            warn "[$total] '$uuid' e v$VER (nao v7) — 48 bits iniciais nao sao timestamp"
            data "\"$uuid\",\"v$VER\",\"$VAR\",\"0x$TS_HEX\",\"$MS\",\"\",\"\",\"nao (v$VER)\""
            not_v7=$((not_v7 + 1))
            continue
        fi

        if uuid_ts_plausible "$MS"; then
            PLAUSIBLE="sim"
            ok_count=$((ok_count + 1))
        else
            PLAUSIBLE="nao (fora de faixa)"
            warn "[$total] '$uuid' v7 com timestamp fora da faixa plausivel ($MS ms)"
            out_of_range=$((out_of_range + 1))
        fi

        DATE_UTC=$(uuid_to_utc_iso "$MS" 2>/dev/null || echo "")
        DATE_LOCAL=$(uuid_to_local_iso "$MS" 2>/dev/null || echo "")
        data "\"$uuid\",\"v$VER\",\"$VAR\",\"0x$TS_HEX\",\"$MS\",\"$DATE_UTC\",\"$DATE_LOCAL\",\"$PLAUSIBLE\""
    done <"$INPUT"

    echo ""
    hdr "=== Resumo do lote ==="
    say  "Linhas lidas ............... : $total"
    ok   "UUIDv7 decodificados ....... : $ok_count"
    if (( not_v7 > 0 ));       then warn "Nao-v7 (sem timestamp) ..... : $not_v7"; fi
    if (( out_of_range > 0 )); then warn "v7 fora de faixa ........... : $out_of_range"; fi
    if (( invalid > 0 ));      then warn "Entradas invalidas ......... : $invalid"; fi
    if [[ "$OUTPUT" != "-" ]]; then
        acc "Relatorio CSV gerado em .... : $OUTPUT"
    fi
    echo ""

    (( total > 0 && (ok_count + not_v7 + out_of_range) > 0 )) || return 1
    return 0
}

main() {
    local cmd="${1:-help}"
    [[ $# -gt 0 ]] && shift || true
    case "$cmd" in
        decode) cmd_decode "$@" ;;
        batch)  cmd_batch "$@" ;;
        help|-h|--help) usage ;;
        *) err "comando desconhecido: '$cmd'"; usage >&2; return 2 ;;
    esac
}

main "$@"
