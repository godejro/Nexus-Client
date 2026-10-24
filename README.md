# Nexus Client updates

This repository distributes program updates for an existing Nexus Client installation.
It contains no server assets, login credentials or player setups.

## Instalacja aktualizatora u kolegi

1. Pobierz `nexus-launcher.zip` z najnowszego wydania (Releases).
2. Rozpakuj do istniejącego folderu gry obok `Nexus Client.exe`, zachowując podfolder `updater`.
3. W starszej instalacji uruchom raz `URUCHOM_NEXUS.cmd`, aby pobrać wersję z wbudowanym aktualizatorem.
4. Od v2026.10.23.1 możesz uruchamiać samo `Nexus Client.exe`. Okno aktualizacji pokaże **Update**, postęp pobierania (MB), sprawdzania plików (liczba/nazwa) i **Restart and install**. Restart wymaga wylogowania. Przycisk Nexus updates w górnym menu pozwala ponownie otworzyć okno.

To aktualizacja istniejącej instalacji, nie kompletny klient z assetami serwera.
Nie wypakowuj plików w nowym pustym folderze i nie kopiuj tokenów GitHub.

The old launcher bootstraps installations without the new module. Once present, the
in-client updater owns checking, downloading and explicit restart, including direct EXE starts.
It never replaces the running EXE. An offline client can still be used when GitHub is unavailable.
Do not distribute a GitHub token with the client.
Public releases are required for anonymous downloading; a private repository needs a
different authenticated distribution solution.

Update package: `nexus-update.zip` plus `update.json` (SHA256 for ZIP and every file).
The launcher validates allowed paths and all hashes before installing, rejects traversal
and junctions, preserves private folders and backs up replaced files. Trust is based on
HTTPS and this GitHub account, not an independent code-signing certificate. Protect the
account with 2FA. Backups are under updater/backups. Old game_bot is archived there.

Maintainer: copy only reviewed program files into client/, bump VERSION to a new tag,
commit and push main. The workflow runs updater tests, packages an allowlist, then
publishes a GitHub Release. Changing a local file without publishing is NOT an update.

Client-derived code retains its existing copyright notices and client/LICENSE.
Nexus updater scripts are provided under the MIT license in LICENSE.

GitHub API: https://docs.github.com/en/rest/releases/releases#get-the-latest-release
Actions permissions: https://docs.github.com/en/actions/tutorials/authenticate-with-github_token
