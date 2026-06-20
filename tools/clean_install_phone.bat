@echo off
chcp 65001 >nul
:: Désinstalle proprement l'ancienne APK puis relance flutter run

set IP=192.168.1.10
set PORT=5555
set PACKAGE=com.zagorito.spots_app

echo [ADB] Connexion à %IP%:%PORT%...
adb connect %IP%:%PORT%

echo.
echo [ADB] Désinstallation de l'ancienne APK (%PACKAGE%)...
adb -s %IP%:%PORT% uninstall %PACKAGE%

echo.
echo [Flutter] Lancement sur SM S918B...
flutter run -d %IP%:%PORT% --hot
