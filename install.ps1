# Requires PowerShell running as Administrator

# --- FUNCTIONS ---

# Vérifie si un package est installé via winget
function Is-Installed($id) {
    return (winget list --id $id | Select-String $id) -ne $null
}

# Vérifie si WSL est installé
function Is-WSLInstalled {
    return (wsl --version 2>$null) -ne $null
}

# --- INSTALLATIONS ---

# Git
if (Is-Installed "Git.Git") {
    Write-Output "Git est déjà installé."
} else {
    Write-Output "Installation de Git..."
    winget install --id Git.Git -e --source winget
}

# Python 3.13
if (Is-Installed "Python.Python.3.13") {
    Write-Output "Python 3.13 est déjà installé."
} else {
    Write-Output "Installation de Python 3.13..."
    winget install --id Python.Python.3.13 -e --source winget
}

# Docker Desktop
if (Is-Installed "Docker.DockerDesktop") {
    Write-Output "Docker Desktop est déjà installé."
} else {
    Write-Output "Installation de Docker Desktop..."
    winget install --id Docker.DockerDesktop -e --source winget
}

# Google Chrome
if (Is-Installed "Google.Chrome") {
    Write-Output "Google Chrome est déjà installé."
} else {
    Write-Output "Installation de Google Chrome..."
    winget install --id Google.Chrome -e --source winget
}

# WSL (Windows Subsystem for Linux)
if (Is-WSLInstalled) {
    Write-Output "WSL est déjà installé."
} else {
    Write-Output "Installation de WSL et d'Ubuntu par défaut..."
    wsl --install
}

Write-Output "Toutes les installations sont vérifiées/terminées. Redémarrez votre terminal (et votre PC si Docker Desktop vient d'être installé)."
