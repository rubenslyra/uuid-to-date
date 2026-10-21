# run_tests.ps1 — Golden master dos vetores conhecidos (RFC 9562) para Windows.
# Testa o bootstrap main.ps1 (subcomandos decode e batch).
# Vetores:
#   A 018f43a5-9280-7000-8000-000000000000 -> v7, 2024-05-04T12:47:55.520Z
#   B 017f22e2-79b0-7cc3-98c4-dc0c0c07398f -> v7, 2022-02-22T19:22:22.000Z
#   C 8426a8c8-3ca8-414f-ad50-f6147b9ceab2 -> v4 (nao e timestamp)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Main = Join-Path $Root 'main.ps1'
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("uuidtest_" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

$script:Pass = 0
$script:Fail = 0

function Check {
    param([string]$Name, $Expected, $Actual)
    if ("$Expected" -eq "$Actual") {
        $script:Pass++; Write-Host "PASS: $Name"
    } else {
        $script:Fail++
        Write-Host "FAIL: $Name"
        Write-Host "  esperado: $Expected"
        Write-Host "  obtido  : $Actual"
    }
}

function Contains {
    param([string]$Name, [string]$Needle, [string]$Haystack)
    if ($Haystack -like "*$Needle*") {
        $script:Pass++; Write-Host "PASS: $Name"
    } else {
        $script:Fail++
        Write-Host "FAIL: $Name"
        Write-Host "  padrao ausente: $Needle"
    }
}

function NotContains {
    param([string]$Name, [string]$Needle, [string]$Haystack)
    if ($Haystack -notlike "*$Needle*") {
        $script:Pass++; Write-Host "PASS: $Name"
    } else {
        $script:Fail++
        Write-Host "FAIL: $Name"
        Write-Host "  padrao nao deveria aparecer: $Needle"
    }
}

# Executa main.ps1 capturando stdout, stderr e exit code.
function Invoke-Main {
    param([string[]]$Arguments)
    $outFile = Join-Path $Tmp ("out_" + [Guid]::NewGuid().ToString('N') + ".txt")
    $errFile = Join-Path $Tmp ("err_" + [Guid]::NewGuid().ToString('N') + ".txt")
    $env:NO_COLOR = '1'
    $p = Start-Process -FilePath 'powershell' `
        -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Main) + $Arguments) `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    [PSCustomObject]@{
        Exit   = $p.ExitCode
        Stdout = (Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue)
        Stderr = (Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue)
    }
}

$VA = '018f43a5-9280-7000-8000-000000000000'
$VB = '017f22e2-79b0-7cc3-98c4-dc0c0c07398f'
$VC = '8426a8c8-3ca8-414f-ad50-f6147b9ceab2'

# --- 1. UNIDADE: v7 valido (vetor A) -----------------------------------------
$r = Invoke-Main @('decode', '-Uuid', $VA)
Check "A: exit code 0" 0 $r.Exit
Contains "A: identidade v7" "v7" $r.Stdout
Contains "A: variante RFC 9562" "RFC 9562" $r.Stdout
Contains "A: UTC golden" "2024-05-04T12:47:55.520Z" $r.Stdout
Contains "A: ms golden" "1714826875520" $r.Stdout

# --- 2. UNIDADE: v7 valido (vetor B) -----------------------------------------
$r = Invoke-Main @('decode', '-Uuid', $VB)
Check "B: exit code 0" 0 $r.Exit
Contains "B: UTC golden" "2022-02-22T19:22:22.000Z" $r.Stdout
Contains "B: ms golden" "1645557742000" $r.Stdout

# --- 3. UNIDADE: v4 (vetor C) e recusado --------------------------------------
$r = Invoke-Main @('decode', '-Uuid', $VC)
Check "C: exit code 3 (sem ts confiavel)" 3 $r.Exit
Contains "C: identifica v4" "v4" $r.Stdout
Contains "C: aviso em stderr" "nao e UUIDv7" $r.Stderr
NotContains "C: nao imprime Data UTC" "Data UTC" $r.Stdout

# --- 4. Entradas invalidas / uso ----------------------------------------------
$r = Invoke-Main @('decode', '-Uuid', 'xyz')
Check "entrada invalida -> exit 1" 1 $r.Exit
$r = Invoke-Main @('decode')
Check "sem -Uuid -> exit 2" 2 $r.Exit
$r = Invoke-Main @('frobnicate')
Check "comando desconhecido -> exit 2" 2 $r.Exit

# --- 5. Canal de dados: -DataFile ---------------------------------------------
$csvA = Join-Path $Tmp 'o.csv'
$r = Invoke-Main @('decode', '-Uuid', $VA, '-DataFile', $csvA, '-Quiet')
$line = (Get-Content -LiteralPath $csvA -Raw).Trim()
Contains "CSV via -DataFile: uuid" "\"$VA\",\"v7\",\"RFC 9562\"" $line
Contains "CSV via -DataFile: UTC" "2024-05-04T12:47:55.520Z" $line

# --- 6. NO_COLOR remove ANSI ---------------------------------------------------
$r = Invoke-Main @('decode', '-Uuid', $VA)
NotContains "NO_COLOR: sem ESC" ([char]27) $r.Stdout

# --- 7. LOTE -------------------------------------------------------------------
$loteCsv = Join-Path $Tmp 'lote.csv'
$r = Invoke-Main @('batch', '-InputFile', (Join-Path $Root 'data\lista_uuid.txt'), '-OutputFile', $loteCsv)
Check "lote: exit code 0" 0 $r.Exit
$csv = Get-Content -LiteralPath $loteCsv -Raw
Contains "lote: header CSV" '"UUID_Original","Versao"' $csv
Contains "lote: vetor A" "\"$VA\",\"v7\",\"RFC 9562\"" $csv
Contains "lote: vetor B" "\"$VB\",\"v7\",\"RFC 9562\"" $csv
Contains "lote: vetor C marcado v4" "\"$VC\",\"v4\"" $csv
NotContains "lote: linha invalida nao vaza p/ CSV" "linha-quebrada" $csv
Contains "lote: resumo total" "Linhas lidas ............... : 4" $r.Stdout
Contains "lote: aviso stderr v4" "v4" $r.Stderr

# --- 8. help -------------------------------------------------------------------
$r = Invoke-Main @('help')
Check "help: exit code 0" 0 $r.Exit
Contains "help: mostra comandos" "decode" $r.Stdout

Remove-Item -LiteralPath $Tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==============================="
Write-Host ("Resultado: {0} PASS / {1} FAIL" -f $script:Pass, $script:Fail)
Write-Host "==============================="
if ($script:Fail -ne 0) { exit 1 }
exit 0
