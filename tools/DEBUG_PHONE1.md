# Debug téléphone sans fil — raccourcis

## Commandes rapides

| Action | Commande |
|--------|----------|
| Connecter le téléphone | `tools\connect_phone.bat` |
| Lancer l'app (update) | `tools\run_phone.bat` |
| Lancer l'app (propre, désinstalle d'abord) | `tools\clean_install_phone.bat` |
| Alias PowerShell | `run-phone` |
| Alias PowerShell + clean install | `run-phone -Clean` |
| Lancer depuis VS Code | F5 → **Flutter: SM S918B (Wi-Fi)** |

## Installation de l'alias PowerShell

```powershell
.\tools\install_phone_alias.ps1
```

Puis rechargez PowerShell. La commande `run-phone` est disponible globalement.

## Si la connexion échoue

1. Branchez le téléphone en USB.
2. Exécutez : `adb tcpip 5555`
3. Débranchez le câble.
4. Relancez `tools\connect_phone.bat`.

## Si l'installation de l'APK échoue

Utilisez `run-phone -Clean` ou `tools\clean_install_phone.bat` pour forcer la désinstallation de l'ancienne APK avant réinstallation.

> L'IP est fixée à `192.168.1.10:5555`. Modifiez-la dans les fichiers `.bat`, `.ps1`, `.vscode/launch.json` et `.vscode/tasks.json` si elle change.
