# output.ps1 — Paleta corporativa Slate & Slate-Blue + canais de E/S (PowerShell).
# Espelha src/output.sh.
#
# Canais:
#   FD 1 (stdout) : relatorio humano (colorido)
#   FD 2 (stderr) : avisos e erros
#   FD 3 (custom) : dados de maquina (CSV) — via -DataFile ou stream externo
#
# Customizacao:
#   NO_COLOR=1            -> desativa ANSI
#   -DataFile <arquivo>   -> CSV no arquivo (equivalente ao FD 3 do shell)

$script:UseColor = -not ($env:NO_COLOR) -and -not ([Console]::IsOutputRedirected)

function Initialize-Output {
    if ($script:UseColor) {
        $script:C_HEAD = "`e[38;5;60m"   # Slate
        $script:C_ACC  = "`e[38;5;67m"   # Slate-Blue
        $script:C_OK   = "`e[32m"
        $script:C_WARN = "`e[33m"
        $script:C_ERR  = "`e[31m"
        $script:C_DIM  = "`e[90m"
        $script:C_OFF  = "`e[0m"
    } else {
        $script:C_HEAD = ''; $script:C_ACC = ''; $script:C_OK = ''
        $script:C_WARN = ''; $script:C_ERR = ''; $script:C_DIM = ''; $script:C_OFF = ''
    }
}

function Write-Say  { param([string]$Text) Write-Host $Text }
function Write-Hdr  { param([string]$Text) Write-Host "$($script:C_HEAD)$Text$($script:C_OFF)" }
function Write-Acc  { param([string]$Text) Write-Host "$($script:C_ACC)$Text$($script:C_OFF)" }
function Write-Ok   { param([string]$Text) Write-Host "$($script:C_OK)$Text$($script:C_OFF)" }
function Write-Dim  { param([string]$Text) Write-Host "$($script:C_DIM)$Text$($script:C_OFF)" }
function Write-Warn { param([string]$Text) [Console]::Error.WriteLine("$($script:C_WARN)AVISO: $Text$($script:C_OFF)") }
function Write-Err  { param([string]$Text) [Console]::Error.WriteLine("$($script:C_ERR)ERRO: $Text$($script:C_OFF)") }

function Write-Data {
    param([string]$Line, [string]$DataFile)
    if ($DataFile) {
        Add-Content -LiteralPath $DataFile -Value $Line -Encoding UTF8
    } else {
        [Console]::Out.WriteLine($Line)
    }
}
