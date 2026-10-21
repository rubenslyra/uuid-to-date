# main.ps1 — Bootstrap da aplicacao (Windows/PowerShell).
# Orquestra os modulos em src/ e expoe os subcomandos decode e batch.
#
# Uso:
#   .\main.ps1 decode -Uuid <uuid> [-DataFile <csv>] [-Quiet]
#   .\main.ps1 batch  -InputFile <entrada> -OutputFile <saida.csv>
#   .\main.ps1 help
#
# Customizacao:
#   $env:NO_COLOR=1   -> desativa ANSI
#   -DataFile <csv>   -> CSV no arquivo (equivalente ao FD 3 do shell)

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = 'help',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Lib = Join-Path $Root 'lib'

. (Join-Path $Lib 'output.ps1')
. (Join-Path $Lib 'uuid_core.ps1')

function Show-Usage {
    @"
UUID to Date — engenharia reversa de UUID (RFC 9562)

Uso: main.ps1 <comando> [opcoes]

Comandos:
  decode -Uuid <uuid> [-DataFile <csv>] [-Quiet]   Processa UNIDADE (um UUID)
  batch  -InputFile <entrada> -OutputFile <saida>  Processa LOTE (arquivo -> CSV)
  help                                             Mostra esta ajuda

Exemplos:
  .\main.ps1 decode -Uuid 018f43a5-9280-7000-8000-000000000000
  .\main.ps1 decode -Uuid 8426a8c8-3ca8-414f-ad50-f6147b9ceab2 -DataFile data\linha.csv
  .\main.ps1 batch  -InputFile data\lista_uuid.txt -OutputFile data\relatorio_datas.csv
"@ | Write-Host
}

function Invoke-Decode {
    param([string[]]$Arguments)

    $Uuid = $null; $DataFile = $null; $Quiet = $false
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        switch ($Arguments[$i]) {
            '-Uuid'     { $Uuid = $Arguments[++$i] }
            '-DataFile' { $DataFile = $Arguments[++$i] }
            '-Quiet'    { $Quiet = $true }
            '-h'        { Show-Usage; return 0 }
            default     { Write-Err "opcao invalida: $($Arguments[$i])"; return 2 }
        }
    }

    if ([string]::IsNullOrWhiteSpace($Uuid)) {
        Write-Err "informe um UUID com -Uuid <uuid>"
        return 2
    }

    Initialize-Output

    $clean = Get-UuidNormalized $Uuid
    if (-not $clean) {
        Write-Err "entrada invalida: '$Uuid' nao e um UUID (esperado 32 hex ou 8-4-4-4-12)"
        return 1
    }

    $ver = Get-UuidVersion $clean
    $verName = Get-UuidVersionName $ver
    $variant = Get-UuidVariant $clean
    $tsHex = Get-UuidTsHex $clean
    $ms = Get-UuidTsMs $clean

    if (-not $Quiet) {
        Write-Host ""
        Write-Hdr "--- ENGENHARIA REVERSA DE UUID (RFC 9562) ---"
        Write-Say "UUID Analisado  : $Uuid"
        Write-Acc "Identidade      : v$ver ($verName) - variante $variant"
    }

    if ($ver -ne 7) {
        Write-Warn "nao e UUIDv7: os 48 bits iniciais (0x$tsHex) NAO sao timestamp - dado aleatorio; data nao calculada"
        if (-not $Quiet) {
            Write-Dim "unix_ts_ms (hex): $tsHex  (48 bits iniciais, sem significado de tempo)"
            Write-Hdr "--------------------------------------------------"
            Write-Host ""
        }
        Write-Data "`"$Uuid`",`"v$ver`",`"$variant`",`"0x$tsHex`",`"$ms`",`"`",`"`",`"nao (v$ver)`"" $DataFile
        return 3
    }

    $plausible = Test-UuidTsPlausible $ms
    $dateUtc = Convert-UuidMsToUtcIso $ms
    $dateLocal = Convert-UuidMsToLocalIso $ms
    $plausibleTxt = if ($plausible) { 'sim' } else { 'nao (fora de faixa)' }

    if (-not $Quiet) {
        Write-Dim "unix_ts_ms (hex): $tsHex  (48 bits, big-endian)"
        Write-Dim "unix_ts_ms (dec): $ms ms"
        if ($plausible) {
            Write-Ok "Data UTC        : $dateUtc"
            Write-Ok "Data Local      : $dateLocal"
        } else {
            Write-Warn "timestamp fora da faixa plausivel ($ms ms) - data nao confiavel"
            Write-Say "Data UTC        : $dateUtc  [NAO CONFIABEL]"
            Write-Say "Data Local      : $dateLocal  [NAO CONFIABEL]"
        }
        Write-Hdr "--------------------------------------------------"
        Write-Host ""
    }

    Write-Data "`"$Uuid`",`"v$ver`",`"$variant`",`"0x$tsHex`",`"$ms`",`"$dateUtc`",`"$dateLocal`",`"$plausibleTxt`"" $DataFile
    if ($plausible) { return 0 } else { return 3 }
}

function Invoke-Batch {
    param([string[]]$Arguments)

    $InputFile = $null; $OutputFile = $null
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        switch ($Arguments[$i]) {
            '-InputFile'  { $InputFile = $Arguments[++$i] }
            '-OutputFile' { $OutputFile = $Arguments[++$i] }
            '-h'          { Show-Usage; return 0 }
            default       { Write-Err "opcao invalida: $($Arguments[$i])"; return 2 }
        }
    }

    if ([string]::IsNullOrWhiteSpace($InputFile) -or [string]::IsNullOrWhiteSpace($OutputFile)) {
        Write-Err "informe -InputFile <entrada> e -OutputFile <saida.csv>"
        return 2
    }
    if (-not (Test-Path -LiteralPath $InputFile)) {
        Write-Err "arquivo de entrada nao encontrado: $InputFile"
        return 2
    }

    Initialize-Output
    if (Test-Path -LiteralPath $OutputFile) { Remove-Item -LiteralPath $OutputFile -Force }

    Write-Data '"UUID_Original","Versao","Variante","Timestamp_Hex_48b","Epoch_Milissegundos","Data_UTC_ISO8601","Data_Local_Maquina","Timestamp_Plausivel"' $OutputFile

    $total = 0; $okCount = 0; $notV7 = 0; $outOfRange = 0; $invalid = 0
    $lines = Get-Content -LiteralPath $InputFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($raw in $lines) {
        $total++
        $uuid = $raw.Trim()
        $clean = Get-UuidNormalized $uuid

        if (-not $clean) {
            Write-Warn "[$total] entrada invalida ignorada: '$uuid'"
            $invalid++
            continue
        }

        $ver = Get-UuidVersion $clean
        $variant = Get-UuidVariant $clean
        $tsHex = Get-UuidTsHex $clean
        $ms = Get-UuidTsMs $clean

        if ($ver -ne 7) {
            Write-Warn "[$total] '$uuid' e v$ver (nao v7) - 48 bits iniciais nao sao timestamp"
            Write-Data "`"$uuid`",`"v$ver`",`"$variant`",`"0x$tsHex`",`"$ms`",`"`",`"`",`"nao (v$ver)`"" $OutputFile
            $notV7++
            continue
        }

        $plausible = Test-UuidTsPlausible $ms
        if ($plausible) {
            $plausibleTxt = 'sim'; $okCount++
        } else {
            $plausibleTxt = 'nao (fora de faixa)'
            Write-Warn "[$total] '$uuid' v7 com timestamp fora da faixa plausivel ($ms ms)"
            $outOfRange++
        }

        $dateUtc = Convert-UuidMsToUtcIso $ms
        $dateLocal = Convert-UuidMsToLocalIso $ms
        Write-Data "`"$uuid`",`"v$ver`",`"$variant`",`"0x$tsHex`",`"$ms`",`"$dateUtc`",`"$dateLocal`",`"$plausibleTxt`"" $OutputFile
    }

    Write-Host ""
    Write-Hdr "=== Resumo do lote ==="
    Write-Say "Linhas lidas ............... : $total"
    Write-Ok  "UUIDv7 decodificados ....... : $okCount"
    if ($notV7 -gt 0)      { Write-Warn "Nao-v7 (sem timestamp) ..... : $notV7" }
    if ($outOfRange -gt 0) { Write-Warn "v7 fora de faixa ........... : $outOfRange" }
    if ($invalid -gt 0)    { Write-Warn "Entradas invalidas ......... : $invalid" }
    Write-Acc "Relatorio CSV gerado em .... : $OutputFile"
    Write-Host ""

    if ($total -gt 0 -and ($okCount + $notV7 + $outOfRange) -gt 0) { return 0 } else { return 1 }
}

switch ($Command) {
    'decode' { exit (Invoke-Decode $Args) }
    'batch'  { exit (Invoke-Batch $Args) }
    'help'   { Show-Usage; exit 0 }
    '-h'     { Show-Usage; exit 0 }
    '--help' { Show-Usage; exit 0 }
    default  { Write-Err "comando desconhecido: '$Command'"; Show-Usage; exit 2 }
}
