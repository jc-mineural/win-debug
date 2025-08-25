# UTF-8 propre
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$ErrorActionPreference = 'Stop'
$env:WINGET_DISABLE_INTERACTIVITY = "1"

function Header($m){ Write-Output "`n=== $m ===" }
function Ok($m){ Write-Output "[OK] $m" }
function Info($m){ Write-Output "[INFO] $m" }
function Err($m){ Write-Output "[ERREUR] $m" }

# ---- Détecteurs locaux (sans winget) ----
function Has-Git {
  $cmd = Get-Command git -ErrorAction SilentlyContinue
  if($cmd){ return $true }
  return Test-Path "C:\Program Files\Git\cmd\git.exe"
}

function Has-Python313 {
  try{ & py -3.13 -V | Out-Null; return $true } catch {}
  try{ & python3.13 -V | Out-Null; return $true } catch {}
  return (Test-Path "C:\Users\*\AppData\Local\Programs\Python\Python313\python.exe") -or
         (Test-Path "C:\Program Files\Python313\python.exe")
}

function Has-DockerDesktop {
  return (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") -or
         (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" `
            -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "Docker Desktop*" })
}

function Has-Chrome {
  return (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") -or
         (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" `
            -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "Google Chrome*" })
}

function WSL-Ready {
  try{ wsl --status | Out-Null; return $true } catch { return $false }
}

# ---- Wrapper winget (avec logs + timeouts) ----
function Run-Winget {
  param([string[]]$Args,[int]$TimeoutSec=1800)
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "winget"
  $psi.Arguments = ($Args -join " ")
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()
  if(-not $p.WaitForExit($TimeoutSec*1000)){ try{$p.Kill()}catch{}; throw "Timeout ($TimeoutSec s): winget $($Args -join ' ')" }
  [pscustomobject]@{ StdOut=$p.StandardOutput.ReadToEnd(); StdErr=$p.StandardError.ReadToEnd(); ExitCode=$p.ExitCode }
}

function Winget-Install($id,$name){
  Header "Installation de $name ($id)"
  $r = Run-Winget @(
    "install","--id",$id,"-e","--source","winget",
    "--accept-package-agreements","--accept-source-agreements",
    "--scope","machine","--disable-interactivity"
  )
  if($r.ExitCode -ne 0){ Err "$name: ExitCode=$($r.ExitCode)"; if($r.StdErr){Info "stderr:`n$($r.StdErr.Trim())"} }
}

function Winget-Upgrade($id,$name){
  Header "Mise à niveau de $name (si dispo)"
  $r = Run-Winget @(
    "upgrade","--id",$id,"-e","--source","winget",
    "--accept-package-agreements","--accept-source-agreements",
    "--include-unknown","--silent"
  ) 900
  if($r.ExitCode -eq 0){ Ok "$name vérifié/mis à jour." }
  else { Info "$name: aucune MAJ ou mapping winget indisponible." }
}

# ---- Go ----
Header "Mise à jour source winget"
try{ Run-Winget @("source","update") | Out-Null } catch { Info "source update: $($_.Exception.Message)" }

# Git
if(Has-Git){ Ok "Git détecté."; Winget-Upgrade "Git.Git" "Git" }
else       { Winget-Install "Git.Git" "Git" }

# Python 3.13 (ou fallback)
if(Has-Python313){ Ok "Python 3.13 détecté."; Winget-Upgrade "Python.Python.3.13" "Python 3.13" }
else{
  Winget-Install "Python.Python.3.13" "Python 3.13"
  if(-not (Has-Python313)){ Info "Fallback vers Python 3.x"; Winget-Install "Python.Python.3" "Python 3.x" }
}

# Docker Desktop
if(Has-DockerDesktop){ Ok "Docker Desktop détecté."; Winget-Upgrade "Docker.DockerDesktop" "Docker Desktop" }
else                  { Winget-Install "Docker.DockerDesktop" "Docker Desktop" }

# Chrome
if(Has-Chrome){ Ok "Chrome détecté."; Winget-Upgrade "Google.Chrome" "Google Chrome" }
else           { Winget-Install "Google.Chrome" "Google Chrome" }

# WSL
Header "WSL"
if(WSL-Ready){ Ok "WSL déjà prêt." }
else{
  Write-Output "[INFO] Activation des features WSL (pas de redémarrage immédiat)…"
  try{
    dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
    dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
    Write-Output "[INFO] Installation d’Ubuntu-24.04…"
    wsl --install -d Ubuntu-24.04
    Write-Output "[INFO] Un redémarrage Windows peut être requis."
  }catch{
    Err "WSL: $($_.Exception.Message)"
  }
}

Header "Terminé"
Write-Output "Relance PowerShell; redémarre Windows si Docker/WSL viennent d’être installés."
