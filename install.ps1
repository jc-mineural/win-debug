# Requires PowerShell running as Administrator

# Function to check if a package is installed via winget
function Is-Installed($id) {
    return (winget list --id $id | Select-String $id) -ne $null
}

# Install Git
if (Is-Installed "Git.Git") {
    Write-Host "Git is already installed."
} else {
    Write-Host "Installing Git..."
    winget install --id Git.Git -e --source winget
}

# Install Python 3.13
if (Is-Installed "Python.Python.3.13") {
    Write-Host "Python 3.13 is already installed."
} else {
    Write-Host "Installing Python 3.13..."
    winget install --id Python.Python.3.13 -e --source winget
}

# Install Docker Desktop
if (Is-Installed "Docker.DockerDesktop") {
    Write-Host "Docker Desktop is already installed."
} else {
    Write-Host "Installing Docker Desktop..."
    winget install --id Docker.DockerDesktop -e --source winget
}

Write-Host "All installations checked/completed. Restart terminal for changes to take effect."
