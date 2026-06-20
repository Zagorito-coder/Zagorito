@echo off
chcp 65001 >nul
:: Lanceur cmd pour lancer l'app Flutter sur le téléphone
:: Usage : tools\run-phone.bat [-Clean]

if "%~1"=="-Clean" (
    call "%~dp0clean_install_phone.bat"
) else (
    powershell -File "%~dp0run_phone.ps1"
)
