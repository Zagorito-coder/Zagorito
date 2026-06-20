# Lance l'app Flutter sur le téléphone SM S918B en Wi-Fi
$ErrorActionPreference = "Stop"

$device = "192.168.1.10:5555"

Write-Host "[ADB] Connexion à $device..."
& adb connect "$device"

Write-Host ""
Write-Host "[Flutter] Lancement sur SM S918B..."
& flutter run -d "$device" --hot @args
