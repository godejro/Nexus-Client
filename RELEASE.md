# Nexus Client v2026.10.23.2

Poprawiona zgodność aktualizatora ze starszym launcherem v2026.10.22.2: nowe tryby działają w istniejących plikach Start-Nexus.ps1 / Update-Library.ps1, bez nowej niedozwolonej ścieżki. Pozostałe poprawki są takie same jak w v2026.10.23.1.

- Aktualizator w oknie klienta: Update, postęp pobierania/sprawdzania plików, Restart and install. Instalacja dopiero po wylogowaniu i zamknięciu procesu; backup i SHA256 pozostają aktywne.
- 16 nowych czarów z tabeli 15.25, poprawiona obsługa łańcuchowych Forked Glacier/Thorns, czarów wokół celu oraz dosłownego Custom Spell.
- CaveBot: wybrane miejsce wstawienia waypointa, zachowany scroll, current position, Supply/Position check, Use z opóźnieniem, Depot/Inbox withdraw all, Sell po ID, Auto navigate. Błąd akcji nie wyłącza kategorii.
- Targeting: edycja bez OFF, Stand/Chase/Keep distance, dokładny dystans, otwieranie pobliskich ciał podczas walki przed ruchem.
- Combo bez dodatkowego oczekiwania na timer; bez Avoid players. Extras: Kill target z własnym priorytetem przed Magic Shooterem.
- Przywracanie ustawień podfunkcji, ID, czarów i delayów; główne kategorie startują OFF. Usunięte przyciski kłódki/menu plecaków.

Testy: 13 zestawów LuaJIT, natywne offline UI, komunikacja klient–pomocnik aktualizacji, instalacja 2795 plików w izolowanym katalogu, SHA256/ochrona prywatnych plików/rollback. Bez logowania i testu walki na serwerze.

Ograniczenia: nowe czary bez potwierdzonego indeksu atlasu mają pustą ikonę. Maski i ID protokołu nowych czarów są referencyjne — customowe serwery mogą je zmieniać. Rzeczywiste obszary na Vantorii, dialog bankiera i Combo dwóch graczy wymagają testu użytkownika. Ping i cooldowny serwera nadal obowiązują.

Wymagana istniejąca instalacja z assetami serwera. Paczka nie zawiera kont, ustawień graczy, prywatnych skryptów ani assetów. Nie zmienia EXE ani silnika synchronizacji. U starszej instalacji uruchom launcher raz, aby otrzymać aktualizator wbudowany w klienta.
