<#
.SYNOPSIS
    Converte e faz a engenharia reversa de UUIDv7 (48-bit timestamp) para Data/Hora.
.DESCRIPTION
    Extrai o campo unix_ts_ms (primeiros 48 bits) conforme a norma RFC 9562 / ISO 8601.
    Identifica versao e variante; recusa decodificar UUIDs que nao sejam v7.
.PARAMETER Uuid
    String contendo o UUID (com ou sem hifens).
.PARAMETER TimeZoneId
    Identificador do fuso horario de destino (Padrao: fuso local da maquina).
.EXAMPLE
    .\Decode-UUIDv7.ps1 -Uuid "018f43a5-9280-7000-8000-000000000000"
.EXAMPLE
    .\Decode-UUIDv7.ps1 -Uuid "017F22E2-79B0-7CC3-98C4-DC0C0C07398F" -TimeZoneId "E. South America Standard Time"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Uuid,

    [Parameter(Mandatory = $false)]
    [string]$TimeZoneId = [System.TimeZoneInfo]::Local.Id
)

$cleanUuid = $Uuid.Replace("-", "").Trim()

if ($cleanUuid.Length -ne 32 -or $cleanUuid -notmatch '^[0-9A-Fa-f]{32}$') {
    Write-Error "Entrada invalida. Esperado 32 hexadecimais (8-4-4-4-12)."
    return
}

$version = [Convert]::ToInt32($cleanUuid.Substring(12, 1), 16)
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

$variantNibble = $cleanUuid.Substring(16, 1)
$variant = switch -Regex ($variantNibble) {
    '^[0-7]$' { "NCS (backward compatible)" }
    '^[89abAB]$' { "RFC 9562" }
    '^[cdCD]$' { "Reserved (Microsoft)" }
    default { "Reserved (future)" }
}

$hexMs = $cleanUuid.Substring(0, 12)
$epochMs = [Convert]::ToInt64($hexMs, 16)

$identity = "v$version ($versionName) - variante $variant"

if ($version -ne 7) {
    [PSCustomObject]@{
        "UUID de Entrada"    = $Uuid
        "Identidade"         = $identity
        "Hexadecimal (48b)"  = "0x$hexMs"
        "Timestamp Unix (ms)"= $epochMs
        "Status"             = "NAO e UUIDv7 - 48 bits iniciais nao sao timestamp; data nao calculada"
    } | Format-List
    return
}

$minMs = 1640995200000
$maxMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + 86400000
$plausible = ($epochMs -ge $minMs -and $epochMs -le $maxMs)

$dtoUtc = [DateTimeOffset]::FromUnixTimeMilliseconds($epochMs)
$localTz  = [System.TimeZoneInfo]::Local
$customTz = try { [System.TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId) } catch { $localTz }

$dtLocal  = [System.TimeZoneInfo]::ConvertTime($dtoUtc, $localTz)
$dtCustom = [System.TimeZoneInfo]::ConvertTime($dtoUtc, $customTz)

$status = if ($plausible) { "OK" } else { "AVISO: timestamp fora da faixa plausivel - data nao confiavel" }

[PSCustomObject]@{
    "UUID de Entrada"    = $Uuid
    "Identidade"         = $identity
    "Hexadecimal (48b)"  = "0x$hexMs"
    "Timestamp Unix (ms)"= $epochMs
    "Data UTC (ISO 8601)"= $dtoUtc.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    "Data Local"         = $dtLocal.ToString("yyyy-MM-dd HH:mm:ss.fff (zzz)")
    "Fuso Escolhido"     = "$($customTz.DisplayName) -> $($dtCustom.ToString('yyyy-MM-dd HH:mm:ss.fff (zzz)'))"
    "Status"             = $status
} | Format-List
