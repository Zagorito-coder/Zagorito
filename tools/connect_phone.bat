@echo off
chcp 65001 >nul
:: Connecte automatiquement le Samsung SM S918B en Wi-Fi debugging
:: Prérequis : le téléphone doit déjà avoir autorisé le débogage sur ce PC.
:: Si la connexion échoue après un redémarrage du téléphone, rebranchez-le en USB
:: et exécutez : adb tcpip 5555

set IP=192.168.1.10
set PORT=5555

echo [ADB] Connexion à %IP%:%PORT%...
adb connect %IP%:%PORT%

echo.
echo Appareils détectés :
adb devices
pause
