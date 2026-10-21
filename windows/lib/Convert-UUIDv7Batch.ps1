param(
    [string]$InputFile,
    [string]$OutputFile
)

if ([string]::IsNullOrWhiteSpace($InputFile) -or [string]::IsNullOrWhiteSpace($OutputFile)) {
    Write-Host "Erro: Voce deve especificar os parametros -InputFile e -OutputFile." -ForegroundColor Red
    Write-Host "Exemplo: .\Convert-UUIDv7Batch.ps1 -InputFile .\lista.txt -OutputFile .\relatorio.csv" -ForegroundColor Yellow
    return
}

if (-not (Test-Path $InputFile)) {
    Write-Host "Erro: Arquivo de entrada nao encontrado: $InputFile" -ForegroundColor Red
    return
}

Write-Host "Iniciando processamento em lote de UUIDs..." -ForegroundColor Cyan

$resultados = @()
$linhas = Get-Content -Path $InputFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$total = $linhas.Count
$contador = 0
$okCount = 0
$notV7 = 0
$invalid = 0

$minMs = 1640995200000
$maxMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + 86400000

foreach ($uuidRaw in $linhas) {
    $contador++
    $uuid = $uuidRaw.Trim()
    $clean = $uuid.Replace("-", "")

    if ($clean.Length -ne 32 -or $clean -notmatch '^[0-9A-Fa-f]{32}$') {
        Write-Host "[$contador/$total] Aviso: entrada invalida ignorada: $uuid" -ForegroundColor Yellow
        $invalid++
        continue
    }

    $version = [Convert]::ToInt32($clean.Substring(12, 1), 16)
    $variantNibble = $clean.Substring(16, 1)
    $variant = switch -Regex ($variantNibble) {
        '^[0-7]$' { "NCS (backward compatible)" }
        '^[89abAB]$' { "RFC 9562" }
        '^[cdCD]$' { "Reserved (Microsoft)" }
        default { "Reserved (future)" }
    }

    $hex = $clean.Substring(0, 12)
    $ms = [Convert]::ToInt64($hex, 16)

    if ($version -ne 7) {
        Write-Host "[$contador/$total] Aviso: '$uuid' e v$version (nao v7) - 48 bits iniciais nao sao timestamp" -ForegroundColor Yellow
        $resultados += [PSCustomObject]@{
            "UUID_Original"        = $uuid
            "Versao"               = "v$version"
            "Variante"             = $variant
            "Timestamp_Hex_48b"    = "0x$hex"
            "Epoch_Milissegundos"  = $ms
            "Data_UTC_ISO8601"     = ""
            "Data_Local_Maquina"   = ""
            "Timestamp_Plausivel"  = "nao (v$version)"
        }
        $notV7++
        continue
    }

    $plausible = ($ms -ge $minMs -and $ms -le $maxMs)
    $utc = [DateTimeOffset]::FromUnixTimeMilliseconds($ms)
    $local = [System.TimeZoneInfo]::ConvertTime($utc, [System.TimeZoneInfo]::Local)

    if ($plausible) {
        $okCount++
        $plausibleTxt = "sim"
    } else {
        Write-Host "[$contador/$total] Aviso: '$uuid' v7 com timestamp fora da faixa plausivel ($ms ms)" -ForegroundColor Yellow
        $plausibleTxt = "nao (fora de faixa)"
    }

    $resultados += [PSCustomObject]@{
        "UUID_Original"        = $uuid
        "Versao"               = "v$version"
        "Variante"             = $variant
        "Timestamp_Hex_48b"    = "0x$hex"
        "Epoch_Milissegundos"  = $ms
        "Data_UTC_ISO8601"     = $utc.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        "Data_Local_Maquina"   = $local.ToString("yyyy-MM-dd HH:mm:ss.fff (zzz)")
        "Timestamp_Plausivel"  = $plausibleTxt
    }
}

if ($resultados.Count -gt 0) {
    $resultados | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
    Write-Host ""
    Write-Host "Sucesso! $($resultados.Count) registros processados." -ForegroundColor Green
    Write-Host "  UUIDv7 decodificados : $okCount" -ForegroundColor Green
    if ($notV7 -gt 0)   { Write-Host "  Nao-v7 (sem ts)      : $notV7" -ForegroundColor Yellow }
    if ($invalid -gt 0) { Write-Host "  Entradas invalidas   : $invalid" -ForegroundColor Yellow }
    Write-Host "Relatorio gerado em: $OutputFile" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "Nenhum registro valido foi convertido para o relatorio." -ForegroundColor Yellow
}
