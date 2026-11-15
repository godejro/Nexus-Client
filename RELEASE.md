# Nexus Client v2026.11.15.1

Naprawa logowania IgłaOTS oraz dalsze ograniczenie pamięci grafiki. Zmiany silnika działają wspólnie dla profili serwerów.

- Poprawiono odczyt danych profesji: nowy format zawiera listę identyfikatorów U16. Jej niepełny odczyt powodował rozłączenie Igły po załadowaniu mapy (ERROR 134). Wspólny parser obsługuje format przez GameVocationSpellList; starszy format pozostaje dostępny przez wyłączenie tej funkcji w profilu. Usunięto osobne przechwytywanie tej listy tylko dla Vantorii.
- Automatyczny rozmiar strony atlasu mapy wynosi teraz 4096×4096 zamiast maksymalnego rozmiaru GPU. Strona RGBA zajmuje 64 MiB zamiast 256 MiB przy 8192×8192. Jawne ustawienia użytkownika są respektowane.
- Usunięto niewykorzystywane mipmapy generowanych tekstur obiektów i ich podwójne przechowywanie po przesłaniu do atlasu. Cztery maski outfitu są pakowane w kanały jednej maski z zachowaniem kolejności i sposobu kolorowania.
- Nieaktywne, całkowicie puste strony atlasu zwalniają się po okresie ochronnym; pozostaje zapasowa strona. Aktywne zasoby i kolejki renderowania zachowują własność. Preload oraz retencja zasobów podczas zmiany piętra pozostają.
- Nieobecne identyfikatory w rzadkim katalogu assets są teraz odrzucane od razu. Błąd odczytu protokołu ma osobny komunikat zamiast sugerowania wyłącznie awarii sieci.
- Naprawiono pętlę zamykania mapy, która mogła pozostawić proces Nexusa po zamknięciu okna.

## Weryfikacja

Kompilacja Windows x64 OpenGL: poprawna. Testy parsera obejmują przechwycony format Igły, granice następnego pakietu, pustą/wieloelementową listę, ucięte dane i starszy format. Testy cache, masek i czasu życia atlasów przeszły. Zweryfikowano też testy aktualizatora: SHA256, dozwolone ścieżki, kopię zapasową i cofnięcie częściowej instalacji.

Rzeczywisty test 15.11: logowanie Igła → Vantoria → Igła w jednym procesie, bez podmiany plików, z ruchem i przejściami między piętrami. W pierwszym zapisie Private Working Set wyniósł 784–1281 MiB, Private Bytes 875–1349 MiB; zakres obejmuje logowanie i zmianę profilu. Nie jest to gwarancja limitu pamięci podczas każdej długiej sesji. W powtórnej próbie schodów w Thais pierwsze trzy przejścia miały maksymalne czasy klatki 12,6–12,9 ms w oknach ±2 s. Nie potwierdzamy celu 500–700 MB ani uniwersalnego limitu 1 GB.

## Instalacja

Wyloguj postać i uruchom ponownie Nexus Client.exe. Wbudowany aktualizator pobierze nowe wydanie. W starszej instalacji uruchom URUCHOM_NEXUS.cmd; jeśli pojawią się Update oraz Restart and install, użyj ich kolejno.

Paczka zawiera program, nie assets serwerów, konta ani ustawienia gracza. Profile i konfiguracja bota pozostają lokalne. Vantoria wymaga aktualnych zasobów ze swojego launchera; sam stary publiczny ZIP Vantoria15_25 może nie zawierać nowych przedmiotów. Studio Sync jest dołączone w dotychczasowej wersji.

Po aktualizacji sprawdź dłuższą sesję, powroty między profilami, outfity i efekty oraz pamięć po ustabilizowaniu. Optymalizacja nie ogranicza FPS, jakości grafiki ani częstotliwości akcji bota.
