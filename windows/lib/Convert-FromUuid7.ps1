param(
    [string]$Uuid
)

if ([string]::IsNullOrWhiteSpace($Uuid)) {
    Write-Host "Erro: Voce precisa passar um UUID como argumento." -ForegroundColor Red
    return
}

$clean = $Uuid.Replace("-", "").Trim()

if ($clean.Length -ne 32 -or $clean -notmatch '^[0-9A-Fa-f]{32}$') {
    Write-Host "Erro: Entrada invalida. Esperado 32 hexadecimais (8-4-4-4-12)." -ForegroundColor Red
    return
}

$version = [Convert]::ToInt32($clean.Substring(12, 1), 16)
$versionName = switch ($version) {
    0 { "unspecified" }
    1 { "time-based (MAC)" }
    2 { "DCE security" }
    3 { "MD5 namespace" }
    4 { "random" }
    5 { "SHA-1 namespace" }
    6 { "Microsoft (SID)" }
    7 { "Unix epoch milliseconds" }
    8 { "custom" }
    default { "future/unknown" }
}

$variantNibble = $clean.Substring(16, 1)
$variant = switch -Regex ($variantNibble) {
    '^[0-7]$' { "NCS (backward compatible)" }
    '^[89abAB]$' { "RFC 9562" }
    '^[cdCD]$' { "Reserved (Microsoft)" }
    default { "Reserved (future)" }
}

$hex = $clean.Substring(0, 12)
$ms = [Convert]::ToInt64($hex, 16)

Write-Host ""
Write-Host "--- ENGENHARIA REVERSA DE UUID (RFC 9562) ---" -ForegroundColor Cyan
Write-Host "UUID Analisado  : $Uuid" -ForegroundColor Yellow
Write-Host "Identidade      : v$version ($versionName) - variante $variant" -ForegroundColor Magenta

if ($version -ne 7) {
    Write-Host "AVISO: nao e UUIDv7 - os 48 bits iniciais (0x$hex) NAO sao timestamp (dado aleatorio)." -ForegroundColor Yellow
    Write-Host "       Data nao calculada." -ForegroundColor Yellow
    Write-Host "--------------------------------------------------"
    Write-Host ""
    return
}

$minMs = 1640995200000
$maxMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + 86400000
$plausible = ($ms -ge $minMs -and $ms -le $maxMs)

Write-Host "Bloco Hex (48b) : 0x$hex" -ForegroundColor DarkGray
Write-Host "Milissegundos   : $ms" -ForegroundColor DarkGray

if ($plausible) {
    $utc = [DateTimeOffset]::FromUnixTimeMilliseconds($ms)
    $local = [System.TimeZoneInfo]::ConvertTime($utc, [System.TimeZoneInfo]::Local)
    Write-Host "Padrao UTC      : $($utc.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))" -ForegroundColor Green
    Write-Host "Fuso Local      : $($local.ToString('yyyy-MM-dd HH:mm:ss.fff (zzz)'))" -ForegroundColor Green
} else {
    Write-Host "AVISO: timestamp fora da faixa plausivel - data nao confiavel." -ForegroundColor Yellow
}
Write-Host "--------------------------------------------------"
Write-Host ""
