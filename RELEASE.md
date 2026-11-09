# Nexus Client v2026.11.9.1

Optymalizacja pamięci grafik bez zmian protokołu, kolejności pakietów, limitu FPS ani działania bota.

- Rozpakowane arkusze grafik mają teraz cache LRU z budżetem 64 MiB. Najdawniej używane arkusze są zwalniane; dane aktualnie odczytywane pozostają chronione. Budżet dotyczy arkuszy, nie całego procesu, i może być chwilowo przekroczony przez aktywnych czytelników.
- Gotowe tekstury pozostają dostępne do renderowania. Usunięty arkusz jest ponownie odczytywany z lokalnych zasobów, gdy jest potrzebny.
- Naprawiono wyścig ładowania, który mógł powodować uznanie kończącej się operacji za brakującą grafikę.
- Zmiana profilu zwalnia stare strumienie zasobów; wyładowanie usuwa także metadane CWM i resetuje stan załadowania.

Kompilacja OpenGL x64 oraz osobny test cache zakończyły się poprawnie. Test obejmował limit, ochronę aktywnego odczytu, ponowne użycie i odtworzenie usuniętego arkusza. Nie wykonywano testów rozgrywki po tej zmianie. Docelowe 500–700 MB całego klienta nie jest potwierdzonym wynikiem pomiaru.

## Aktualizacja

Wyloguj postać i uruchom ponownie Nexus Client.exe. Wbudowany aktualizator pobierze wydanie; jeżeli wyświetli przyciski Update oraz Restart and install, użyj ich kolejno. Po instalacji uruchom klienta normalnie.

Profile serwerów, assets, zapisane konta i ustawienia gracza pozostają lokalne. Ta paczka aktualizuje EXE; zachowuje poprzednie wydane moduły i bot. Nexus Studio Sync jest dołączone w dotychczasowej wersji.

Po aktualizacji sprawdź pamięć podczas dłuższego biegania, powrotów do odwiedzonych miejsc, teleportów i pracy bota, a także kompletność grafik i płynność.