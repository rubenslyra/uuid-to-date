# uuid_core.ps1 — Biblioteca pura de analise de UUID conforme RFC 9562.
# Espelha src/uuid_core.sh. Dot-source: . "$PSScriptRoot/uuid_core.ps1"
# Layout do UUID (128 bits):
#   [0..47]   unix_ts_ms  (big-endian, 6 bytes)  — apenas na versao 7
#   [48..63]  ver (4 bits) + var (2 bits)
#   [64..127] rand_a / rand_b

$script:UuidMinMs = 1640995200000        # 2022-01-01T00:00:00Z
$script:UuidMaxSkewMs = 86400000         # tolerancia de relogio: +24h

function Get-UuidNormalized {
    param([string]$Raw)
    $clean = ($Raw -replace '-', '').Trim()
    if ($clean -notmatch '^[0-9A-Fa-f]{32}$') { return $null }
    return $clean.ToLower()
}

function Get-UuidVersion {
    param([string]$Clean)
    return [Convert]::ToInt32($Clean.Substring(12, 1), 16)
}

function Get-UuidVersionName {
    param([int]$Version)
    switch ($Version) {
        0 { 'unspecified' }
        1 { 'time-based (MAC)' }
        2 { 'DCE security' }
        3 { 'MD5 namespace' }
        4 { 'random' }
        5 { 'SHA-1 namespace' }
        6 { 'Microsoft (SID)' }
        7 { 'Unix epoch milliseconds' }
        8 { 'custom' }
        default { 'future/unknown' }
    }
}

function Get-UuidVariant {
    param([string]$Clean)
    $nibble = $Clean.Substring(16, 1)
    switch -Regex ($nibble) {
        '^[0-7]$'      { 'NCS (backward compatible)' }
        '^[89abAB]$'   { 'RFC 9562' }
        '^[cdCD]$'     { 'Reserved (Microsoft)' }
        default        { 'Reserved (future)' }
    }
}

function Get-UuidTsHex {
    param([string]$Clean)
    return $Clean.Substring(0, 12)
}

function Get-UuidTsMs {
    param([string]$Clean)
    return [Convert]::ToInt64($Clean.Substring(0, 12), 16)
}

function Test-UuidTsPlausible {
    param([long]$Ms)
    $max = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + $script:UuidMaxSkewMs
    return ($Ms -ge $script:UuidMinMs -and $Ms -le $max)
}

function Convert-UuidMsToUtcIso {
    param([long]$Ms)
    $dto = [DateTimeOffset]::FromUnixTimeMilliseconds($Ms)
    return $dto.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

function Convert-UuidMsToLocalIso {
    param([long]$Ms)
    $dto = [DateTimeOffset]::FromUnixTimeMilliseconds($Ms)
    $local = [System.TimeZoneInfo]::ConvertTime($dto, [System.TimeZoneInfo]::Local)
    return $local.ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
}
