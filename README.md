# Nexus Client updates

This repository distributes program updates for an existing Nexus Client installation.
It contains no server assets, login credentials or player setups.

## Instalacja aktualizatora u kolegi

1. Pobierz `nexus-launcher.zip` z najnowszego wydania (Releases).
2. Rozpakuj do istniejÄ…cego folderu gry obok `Nexus Client.exe`, zachowujÄ…c podfolder `updater`.
3. W starszej instalacji uruchom raz `URUCHOM_NEXUS.cmd`, aby pobraÄ‡ wersjÄ™ z wbudowanym aktualizatorem.
4. Uruchom `Nexus Client.exe`. Od v2026.10.26.1 klient przed logowaniem automatycznie sprawdza, pobiera, weryfikuje i instaluje aktualizacjÄ™, nastÄ™pnie uruchamia siÄ™ ponownie. Poczekaj na powrĂłt okna logowania. W wydaniu v2026.10.23.1 uĹĽyj przyciskĂłw **Update**, a potem **Restart and install**. Przycisk Nexus updates w gĂłrnym menu pozwala sprawdziÄ‡ aktualizacje rÄ™cznie; instalacja wymaga wylogowania.

To aktualizacja istniejÄ…cej instalacji, nie kompletny klient z assetami serwera.
Nie wypakowuj plikĂłw w nowym pustym folderze i nie kopiuj tokenĂłw GitHub.

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

## Season IglaOTS (od v2026.11.3.1)

Zaktualizuj klienta, pobierz z tego samego wydania `nexus-studio-sync.zip` i postepuj wedlug dolaczonego `SEASON - instrukcja.txt`. Studio importuje profil i zasoby z kompletnego oficjalnego klienta Season. Profil Season to `login.iglaots.net`; Low Rate to `loginlowrate.iglaots.net`. Paczka programu nie zawiera zasobow serwera.
