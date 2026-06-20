@echo off
chcp 65001 >nul
:: Connecte le téléphone et lance flutter run en hot reload

set IP=192.168.1.10
set PORT=5555

echo [ADB] Connexion à %IP%:%PORT%...
adb connect %IP%:%PORT%

echo.
echo [Flutter] Lancement sur SM S918B...
flutter run -d %IP%:%PORT% --hot
