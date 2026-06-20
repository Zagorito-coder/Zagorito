# Installe un raccourci PowerShell persistant : run-phone
# Usage : .\tools\install_phone_alias.ps1

# Autorise l'execution des profils et scripts locaux
try {
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($policy -eq "Restricted" -or $policy -eq "AllSigned") {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        Write-Host "Politique d'execution PowerShell ajustee pour l'utilisateur courant."
    }
} catch {
    Write-Warning "Impossible de modifier la politique d'execution : $_"
}

$profileFile = $PROFILE
$scriptPath = "C:\src\spots_app\tools\run_phone.ps1"
$cleanBatPath = "C:\src\spots_app\tools\clean_install_phone.bat"

if (!(Test-Path $profileFile)) {
    New-Item -ItemType File -Path $profileFile -Force | Out-Null
}

$profileContent = Get-Content $profileFile -Raw -ErrorAction SilentlyContinue

# Nettoie les anciennes definitions
$profileContent = $profileContent -replace "Set-Alias -Name run-phone.*\r?\n?", ""
$profileContent = $profileContent -replace "function run-phone \{[^}]*\}\r?\n?", ""
$profileContent = $profileContent -replace "function Run-Phone \{[^}]*\}\r?\n?", ""

$functionBlock = @"
function Run-Phone {
    param([switch]`$Clean)
    if (`$Clean) {
        & '$cleanBatPath'
    } else {
        & '$scriptPath' @args
    }
}

Set-Alias -Name run-phone -Value Run-Phone
"@

$profileContent = ($profileContent.TrimEnd() + "`r`n`r`n" + $functionBlock).TrimStart()
Set-Content -Path $profileFile -Value $profileContent -Encoding UTF8

Write-Host "Fonction 'Run-Phone' + alias 'run-phone' installes dans le profil. Rechargez PowerShell ou executez : . `$PROFILE"
