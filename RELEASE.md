# Nexus Client v2026.11.3.1

Naprawione odswiezanie ekwipunku oraz obsluga logowania Season IglaOTS przez profil importowany w Nexus Studio Sync.

## Ekwipunek

- Zdarzenie zmiany slotu nie zapamietuje juz braku odbiorcy przed inicjalizacja interfejsu. Zmiany otrzymane po zalogowaniu trafiaja do aktualnych odbiorcow.
- Poprzedni przedmiot jest przekazywany poprawnie do callbackow. Kontrolka przedmiotu zleca odrysowanie po zmianie.
- Rzeczywisty test na Season: trzy cykle zdejmowania/zakladania butow, zamiana luku na wlocznie, kolczana na tarcze i przywrocenie wyposazenia. Stan wszystkich 10 slotow zgadzal sie z kontrolkami; grafika tarczy zostala sprawdzona w oknie gry. Nie trzeba zwijac ekwipunku.

## Season IglaOTS i Studio

- Obsluga transportu launchera przez profil, natywnego HTTP logowania, RSA i wersji klienta zapisanych w profilu oraz wymaganych pol protokolu 15.30.
- Poprawki parsowania anulowania ataku i trybow walki; zachowanie Stand nie wymusza follow.
- Studio wykrywa zagniezdzony katalog klienta w folderze launchera, wypelnia wersje i ustawienia polaczenia oraz jasno opisuje bledy manifestu.
- Osobna paczka nexus-studio-sync.zip zawiera aktualne Studio i instrukcje dla znajomego.

## Jak zaktualizowac i wejsc na Season

1. Uruchom dotychczasowy Nexus Client.exe i poczekaj na aktualizacje oraz restart. W starszym aktualizatorze wybierz Update, potem Restart and install.
2. Pobierz nexus-studio-sync.zip z tego wydania i wypakuj. Uruchom Nexus Studio Sync.exe i wskaz swoj folder Nexusa.
3. Przygotuj kompletny oficjalny klient SEASON IglaOTS, po aktualizacji jego launcherem. Zamknij klienty.
4. W Studio / Synchronizacja wskaz folder Season_Launcher albo jego IglaOTS/bin. Kliknij Rozpoznaj klienta, potem Dodaj serwer automatycznie.
5. Gdy Studio wykryje lokalne modyfikacje plikow OTS, dla kompletnego klienta pobranego z serwera zaznacz Import lokalnych modyfikacji assets i ponow import. Nie uzywaj tej opcji do pomijania brakujacych plikow.
6. Uruchom Nexus Client.exe, wybierz login.iglaots.net i zaloguj sie swoim kontem. loginlowrate.iglaots.net jest osobnym serwerem Low Rate.

Stara instalacja bez aktualizatora: wypakuj nexus-launcher.zip obok Nexus Client.exe i uruchom URUCHOM_NEXUS.cmd raz.

Paczka programu nie zawiera kont, ustawien graczy ani zasobow serwera. Assets importowane przez Studio pozostaja w data/things/<wersja>/<profil>/ i data/sounds/<wersja>/<profil>/; kontrola SHA256 jest zachowana. Testy ekwipunku i logowania nie oznaczaja zakonczonego audytu wszystkich funkcji serwera ani testow Feru/JustRL.
