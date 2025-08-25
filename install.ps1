# Requires: PowerShell en Administrateur
$ErrorActionPreference = 'Stop'

function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        throw "Ce script doit être lancé en Administrateur."
    }
}
Assert-Admin

function Write-Step($m){ Write-Output "`n=== $m ===" }
function Write-Ok($m){ Write-Output "[OK] $m" }
function Write-Info($m){ Write-Output "[INFO] $m" }
function Write-Err($m){ Write-Output "[ERREUR] $m" }

# Exécute winget avec un timeout (watchdog) et retourne StdOut
function Invoke-Winget {
    param(
        [Parameter(Mandatory=$true)][string[]]$Args,
        [int]$TimeoutSec = 180
    )
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

    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch {}
        throw "Timeout ($TimeoutSec s) sur: winget $($Args -join ' ')"
    }
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    if ($p.ExitCode -ne 0 -and $err) { Write-Info $err }
    return $out
}

# Test installation via sortie JSON, en forçant la source 'winget'
function Is-Installed($id) {
    try {
        $o = Invoke-Winget @(
            "list","--id",$id,"-e",
            "--source","winget",
            "--disable-interactivity",
            "--accept-source-agreements",
            "--output","json"
        ) -TimeoutSec 90
        if (-not $o) { return $false }
        $data = $o | ConvertFrom-Json
        return ($data | Where-Object { $_.Id -eq $id }).Count -gt 0
    } catch { return $false }
}

function Ensure-Package($id, $name) {
    if (Is-Installed $id) { Write-Ok "$name déjà installé."; return }
    Write-Step "Installation de $name ($id)"
    try {
        $null = Invoke-Winget @(
            "install","--id",$id,"-e",
            "--source","winget",
            "--accept-package-agreements",
            "--accept-source-agreements",
            "--disable-interactivity"
        ) -TimeoutSec 600
        if (Is-Installed $id) { Write-Ok "$name installé." }
        else { Write-Err "$name semble ne pas être installé après exécution." }
    } catch {
        Write-Err "Échec installation $name : $($_.Exception.Message)"
        throw
    }
}

# --- Préambule: mettre à jour la source winget uniquement ---
Write-Step "Mise à jour de la source winget"
try { $null = Invoke-Winget @("source","update") -TimeoutSec 60 } catch { Write-Info "source update: $($_.Exception.Message)" }

# --- Installations via la source 'winget' ---
Ensure-Package "Git.Git"              "Git"

if (Is-Installed "Python.Python.3.13") {
    Write-Ok "Python 3.13 déjà installé."
} else {
    try {
        Ensure-Package "Python.Python.3.13" "Python 3.13"
    } catch {
        Write-Info "Fallback vers Python 3.x"
        Ensure-Package "Python.Python.3" "Python 3.x"
    }
}

Ensure-Package "Docker.DockerDesktop" "Docker Desktop"
Ensure-Package "Google.Chrome"        "Google Chrome"

# --- WSL: activer features puis installer Ubuntu ---
function Is-WSLInstalled {
    try { wsl --version | Out-Null; return $true } catch { return $false }
}

Write-Step "Activation des fonctionnalités WSL (DISM, pas de redémarrage immédiat)"
try {
    dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
    dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
    Write-Ok "Fonctionnalités WSL/VMP activées."
} catch { Write-Info "DISM a échoué: $($_.Exception.Message) (on continue)" }

if (Is-WSLInstalled) {
    Write-Ok "WSL déjà installé."
} else {
    Write-Step "Installation WSL + Ubuntu-24.04"
    try {
        # Évite l’interactivité et choisit explicitement la distro
        wsl --install -d Ubuntu-24.04
        Write-Info "Un redémarrage Windows peut être requis pour finaliser WSL."
    } catch {
        Write-Err "wsl --install a échoué: $($_.Exception.Message)"
        Write-Info "Après redémarrage, exécute: wsl --install -d Ubuntu-24.04"
    }
}

Write-Step "Terminé"
Write-Output "Redémarre la session PowerShell (et Windows si Docker/WSL viennent d'être installés)."
