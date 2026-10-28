# Nexus Client v2026.10.28.1

Aktualizacja programu i CWEL BOT do istniejącej instalacji. Zamknij klienta i uruchom Nexus Client.exe ponownie; wydanie 26.10 pobierze aktualizację przed logowaniem. W starszym oknie aktualizatora kliknij Update, następnie Restart and install.

## Klient

- Naprawione przywracanie minimapy po ukryciu panelu i przejściu przez ekran logowania.
- Naprawiony crash loadera grafik przy pustej puli SPR; protokół ustawiany przed ładowaniem assetów. Dodatkowa walidacja geometrii tekstur i animacji.
- Magical Archive: poprawione kodowanie tekstu, pojedyncze zaznaczenie, szczegóły filtrów, grafika zakładki i animowany podgląd dostępnych efektów na siatce 3x3.
- Poprawiona obsługa kliknięcia Login dla profili serwerów, pustego loginUrl oraz błędów zastosowania profilu.
- Zoom od 3x3 do 21x15 z zachowaniem paneli bocznych.
- Tryby walki po prawej stronie ekwipunku. Usunięte Manage control buttons i osobny przycisk Spell List w klientach 15.x.
- Niebieski efekt tła logowania bez pomarańczowych cząsteczek.
- Ikona Nexus osadzona w EXE we wszystkich dziewięciu rozmiarach od 16 do 256 px.

## CWEL BOT

- Pogrubiona czcionka, pełne kółka przełączników, jednolite odstępy okien, brak X głównego GUI. Dwuklik kategorii nie włącza modułu.
- Alarms: listy na dole i dopasowanie wysokości. Usunięte wyszukiwarki reguł Targeting/Magic Shooter/Equipment Manager.
- Heal Friends pokazuje pole czaru albo przedmiotu zgodnie z metodą.
- MW/WG Timers wyżej w Extras; dopasowany edytor, format 20 / 20.0 / 20.00 i kolory. Rzeczywisty czas jest używany tylko, gdy serwer przesyła per-item duration. Bez niego licznik 20 s jest oszacowaniem od zauważenia walla, nie rzeczywistym losowym czasem wygaśnięcia. Nie wymuszamy flag protokołu.
- Magic Shooter/Combo respektuje znany cooldown po wysłaniu czaru, a cooldown serwera zastępuje przewidywanie. Wylogowanie czyści stan.
- Debug Cave: półprzezroczysta nakładka nie zastępuje już rysowania zawartości kratki; poprawiony rozmiar przy skalowaniu. Niebieski nagłówek WAYPOINTS.
- BOT CONFIG: wybór ikony nad HP/Maną albo ruchomej zaokrąglonej ikony z zapisem pozycji.

## Weryfikacja i zakres

Przeszły testy składni zmienionych Lua, 9 zestawów testów logiki bota, 45 istniejących testów C++ oraz testy natywnego UI i ponownej inicjalizacji. Odtworzony crash pustej puli SPR nie występuje po poprawce; wizualnie sprawdzono animację Forked Glacier. Wdrożone pliki zweryfikowano SHA256.

Logowanie na Igłę/Feru, timery oraz Debug Cave podczas rzeczywistej gry wymagają testu na serwerze. Nie wszystkie czary mają metadane efektów; podgląd nie zgaduje brakujących animacji. Testy offline nie są gwarancją działania każdego niestandardowego serwera.

Paczka nie zawiera kont, konfiguracji graczy, prywatnych skryptów ani assetów serwerów. Zachowuje istniejące dane użytkownika. Dla instalacji bez aktualizatora użyj nexus-launcher.zip zgodnie z README.
