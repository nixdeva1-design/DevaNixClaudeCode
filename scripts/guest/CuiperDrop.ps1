# drop.ps1 — Windows entry point voor gastcomputer
# Gebruik: powershell -ExecutionPolicy Bypass -File drop.ps1 <hoofdnode-ip>
# Alle output gelogd — niets weggegooid

param(
  [Parameter(Mandatory=$true)]
  [string]$HoofdnodeIP
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = "$ScriptDir\..\..\logs\trail"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$TS = [int][double]::Parse((Get-Date -UFormat %s))
$LogFile = "$LogDir\$TS-windows-diagnose.log"

function Log {
  param([string]$msg)
  Write-Host $msg
  Add-Content -Path $LogFile -Value $msg
}

Log "╔══════════════════════════════════════════════════════════╗"
Log "║              CuiperHive Reparatie Systeem                ║"
Log "║                     Windows Gast                        ║"
Log "╚══════════════════════════════════════════════════════════╝"
Log ""

# Toestemming
Log "=== Toestemmingsformulier ==="
Log ""
Log "De reparateur vraagt toestemming om op afstand te werken."
$Naam = Read-Host "Uw volledige naam"
$Akkoord = Read-Host "Geeft u toestemming? (ja/nee)"

if ($Akkoord -ne "ja") {
  Log "Geen toestemming. Script stopt."
  exit 1
}

$Hash = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes("$Naam$TS"))) -Algorithm SHA256).Hash.Substring(0,16)
Log "Toestemming geregistreerd. Hash: $Hash"

# Diagnose
Log ""
Log "=== Diagnose ==="

Log "── OS ──"
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsArchitecture | Tee-Object -FilePath $LogFile -Append

Log "── CPU ──"
Get-WmiObject Win32_Processor | Select-Object Name, NumberOfCores, MaxClockSpeed | Tee-Object -FilePath $LogFile -Append

Log "── Geheugen ──"
Get-WmiObject Win32_PhysicalMemory | Select-Object Capacity, Speed | Tee-Object -FilePath $LogFile -Append

Log "── Schijven ──"
Get-WmiObject Win32_DiskDrive | Select-Object Model, Size, Status | Tee-Object -FilePath $LogFile -Append
Get-PSDrive -PSProvider FileSystem | Tee-Object -FilePath $LogFile -Append

Log "── Netwerk ──"
Get-NetIPAddress | Select-Object InterfaceAlias, IPAddress | Tee-Object -FilePath $LogFile -Append

Log ""
Log "Diagnose klaar. Log: $LogFile"
Log "Hoofdnode: $HoofdnodeIP"
Log ""
Log "Verbinding wordt opgezet via SSH..."

# SSH verbinding (Windows 10+ heeft OpenSSH ingebouwd)
ssh -N -R "7447:localhost:7447" "reparateur@$HoofdnodeIP"

Log "Sessie klaar."
