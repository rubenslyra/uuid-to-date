#!/usr/bin/env bash
# tests/run_tests.sh — Golden master dos vetores conhecidos (RFC 9562).
# Testa o bootstrap main.sh (subcomandos decode e batch).
# Vetores:
#   A 018f43a5-9280-7000-8000-000000000000 -> v7, 2024-05-04T12:47:55.520Z
#   B 017f22e2-79b0-7cc3-98c4-dc0c0c07398f -> v7, 2022-02-22T19:22:22.000Z
#   C 8426a8c8-3ca8-414f-ad50-f6147b9ceab2 -> v4 (nao e timestamp)
set -u

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MAIN="$ROOT/main.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0 fail=0

check() {
    if [[ "$2" == "$3" ]]; then
        pass=$((pass + 1)); printf 'PASS: %s\n' "$1"
    else
        fail=$((fail + 1))
        printf 'FAIL: %s\n  esperado: %s\n  obtido : %s\n' "$1" "$2" "$3"
    fi
}

contains() {
    if [[ "$3" == *"$2"* ]]; then
        pass=$((pass + 1)); printf 'PASS: %s\n' "$1"
    else
        fail=$((fail + 1)); printf 'FAIL: %s\n  padrao ausente: %s\n' "$1" "$2"
    fi
}

not_contains() {
    if [[ "$3" != *"$2"* ]]; then
        pass=$((pass + 1)); printf 'PASS: %s\n' "$1"
    else
        fail=$((fail + 1)); printf 'FAIL: %s\n  padrao nao deveria aparecer: %s\n' "$1" "$2"
    fi
}

VA="018f43a5-9280-7000-8000-000000000000"
VB="017f22e2-79b0-7cc3-98c4-dc0c0c07398f"
VC="8426a8c8-3ca8-414f-ad50-f6147b9ceab2"

# --- 1. UNIDADE: v7 valido (vetor A) -----------------------------------------
rc=0
outA=$(NO_COLOR=1 bash "$MAIN" decode -u "$VA" 2>"$TMP/a.err") || rc=$?
check "A: exit code 0" 0 "$rc"
contains "A: identidade v7" "v7" "$outA"
contains "A: variante RFC 9562" "RFC 9562" "$outA"
contains "A: UTC golden" "2024-05-04T12:47:55.520Z" "$outA"
contains "A: ms golden" "1714826875520" "$outA"

# --- 2. UNIDADE: v7 valido (vetor B) -----------------------------------------
rc=0
outB=$(NO_COLOR=1 bash "$MAIN" decode -u "$VB" 2>"$TMP/b.err") || rc=$?
check "B: exit code 0" 0 "$rc"
contains "B: UTC golden" "2022-02-22T19:22:22.000Z" "$outB"
contains "B: ms golden" "1645557742000" "$outB"

# --- 3. UNIDADE: v4 (vetor C) e recusado --------------------------------------
rc=0
outC=$(NO_COLOR=1 bash "$MAIN" decode -u "$VC" 2>"$TMP/c.err") || rc=$?
check "C: exit code 3 (sem ts confiavel)" 3 "$rc"
contains "C: identifica v4" "v4" "$outC"
contains "C: aviso em stderr" "nao e UUIDv7" "$(cat "$TMP/c.err")"
not_contains "C: nao imprime Data UTC" "Data UTC" "$outC"

# --- 4. Entradas invalidas / uso ----------------------------------------------
rc=0
NO_COLOR=1 bash "$MAIN" decode -u "xyz" >/dev/null 2>&1 || rc=$?
check "entrada invalida -> exit 1" 1 "$rc"
rc=0
NO_COLOR=1 bash "$MAIN" decode >/dev/null 2>&1 || rc=$?
check "sem -u -> exit 2" 2 "$rc"
rc=0
NO_COLOR=1 bash "$MAIN" frobnicate >/dev/null 2>&1 || rc=$?
check "comando desconhecido -> exit 2" 2 "$rc"

# --- 5. Canal de dados (FD 3): -o (TZ=UTC para expectativa exata) -------------
NO_COLOR=1 TZ=UTC bash "$MAIN" decode -u "$VA" -o "$TMP/o.csv" -q >/dev/null 2>&1
check "CSV via -o: linha exata" \
    "\"$VA\",\"v7\",\"RFC 9562\",\"0x018f43a59280\",\"1714826875520\",\"2024-05-04T12:47:55.520Z\",\"2024-05-04T12:47:55.520+00:00\",\"sim\"" \
    "$(cat "$TMP/o.csv")"

# --- 6. Canal de dados (FD 3): 3> externo -------------------------------------
NO_COLOR=1 bash "$MAIN" decode -u "$VA" -q 3>"$TMP/ext.csv" >/dev/null 2>&1
contains "CSV via 3> externo" "\"$VA\"" "$(cat "$TMP/ext.csv")"

# --- 7. -o tem precedencia sobre 3> externo -----------------------------------
NO_COLOR=1 bash "$MAIN" decode -u "$VA" -q -o "$TMP/win.csv" 3>"$TMP/lose.csv" >/dev/null 2>&1
check "-o vence 3> externo (lose.csv vazio)" "" "$(cat "$TMP/lose.csv")"
contains "-o vence 3> externo (win.csv com dado)" "\"$VA\"" "$(cat "$TMP/win.csv")"

# --- 8. NO_COLOR remove ANSI ---------------------------------------------------
esc=$'\033'
outEsc=$(NO_COLOR=1 bash "$MAIN" decode -u "$VA" 2>/dev/null)
not_contains "NO_COLOR: sem ESC" "$esc" "$outEsc"

# --- 9. LOTE -------------------------------------------------------------------
rc=0
NO_COLOR=1 bash "$MAIN" batch -i "$ROOT/data/lista_uuid.txt" -o "$TMP/lote.csv" \
    >"$TMP/lote.out" 2>"$TMP/lote.err" || rc=$?
check "lote: exit code 0" 0 "$rc"
csv=$(cat "$TMP/lote.csv")
contains "lote: header CSV" '"UUID_Original","Versao"' "$csv"
contains "lote: vetor A" "\"$VA\",\"v7\",\"RFC 9562\"" "$csv"
contains "lote: vetor B" "\"$VB\",\"v7\",\"RFC 9562\"" "$csv"
contains "lote: vetor C marcado v4" "\"$VC\",\"v4\"" "$csv"
contains "lote: linha invalida nao vaza p/ CSV" "nao" "$(
    if grep -q "linha-quebrada" "$TMP/lote.csv"; then echo present; else echo nao; fi
)"
contains "lote: resumo total" "Linhas lidas ............... : 4" "$(cat "$TMP/lote.out")"
contains "lote: aviso stderr v4" "v4" "$(cat "$TMP/lote.err")"

# --- 10. help ------------------------------------------------------------------
rc=0
outH=$(NO_COLOR=1 bash "$MAIN" help 2>&1) || rc=$?
check "help: exit code 0" 0 "$rc"
contains "help: mostra comandos" "decode" "$outH"

echo ""
echo "==============================="
printf 'Resultado: %d PASS / %d FAIL\n' "$pass" "$fail"
echo "==============================="
(( fail == 0 )) || exit 1
exit 0
