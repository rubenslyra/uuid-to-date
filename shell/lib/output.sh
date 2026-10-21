#!/usr/bin/env bash
# output.sh — Paleta corporativa Slate & Slate-Blue + canais de E/S.
#
# Canais (Standard Streams / File Descriptors — POSIX):
#   FD 0 (stdin)  : entrada (nao utilizado aqui)
#   FD 1 (stdout) : relatorio humano (colorido)
#   FD 2 (stderr) : avisos e erros (nunca colore o dado)
#   FD 3 (custom) : dados de maquina (CSV) — canais 3..9 sao customizaveis
#
# Formas de customizar os canais na chamada:
#   ./uuid_decode.sh -u <uuid> 3>relatorio.csv     # CSV no FD 3
#   ./uuid_decode.sh -u <uuid> 1>/dev/null         # soo CSV (via 3>&1)
#   ./uuid_decode.sh -u <uuid> 2>erros.log         # diagnostico em arquivo
#   NO_COLOR=1 ./uuid_decode.sh -u <uuid>          # saida sem ANSI
#   -o arquivo  (nos CLIs) tem precedencia sobre 3> externo

OUT_DATA_FD=3

# Cores com default vazio: seguras mesmo antes de output_init (set -u safe)
C_HEAD='' C_ACC='' C_OK='' C_WARN='' C_ERR='' C_DIM='' C_OFF=''

output_init() {
    if [[ -n "${NO_COLOR:-}" || ! -t 1 || "${TERM:-dumb}" == "dumb" ]]; then
        C_HEAD='' C_ACC='' C_OK='' C_WARN='' C_ERR='' C_DIM='' C_OFF=''
    else
        C_HEAD=$'\033[38;5;60m'   # Slate
        C_ACC=$'\033[38;5;67m'    # Slate-Blue
        C_OK=$'\033[32m'
        C_WARN=$'\033[33m'
        C_ERR=$'\033[31m'
        C_DIM=$'\033[90m'
        C_OFF=$'\033[0m'
    fi
}

say()   { printf '%s\n' "$*"; }
hdr()   { printf '%s%s%s\n' "$C_HEAD" "$*" "$C_OFF"; }
acc()   { printf '%s%s%s\n' "$C_ACC" "$*" "$C_OFF"; }
ok()    { printf '%s%s%s\n' "$C_OK" "$*" "$C_OFF"; }
warn()  { printf '%sAVISO: %s%s\n' "$C_WARN" "$*" "$C_OFF" >&2; }
err()   { printf '%sERRO: %s%s\n' "$C_ERR" "$*" "$C_OFF" >&2; }
dim()   { printf '%s%s%s\n' "$C_DIM" "$*" "$C_OFF"; }

data() {
    printf '%s\n' "$*" >&"$OUT_DATA_FD"
}

# Garante o canal de dados (FD 3):
#   1) -o arquivo      -> abre FD 3 no arquivo (precedencia maxima)
#   2) 3>externo       -> aproveita o FD 3 ja aberto pelo chamado
#   3) default         -> FD 3 em /dev/null (nao polui a saida humana)
ensure_data_channel() {
    local outfile="${1:-}"
    if [[ -n "$outfile" ]]; then
        exec 3>"$outfile"
        return
    fi
    if ! ( : >&3 ) 2>/dev/null; then
        exec 3>/dev/null
    fi
}
