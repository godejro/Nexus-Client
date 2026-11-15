# Nexus Client v2026.11.15.4

Naprawiono rozłączenie ERROR 134 podczas pojawienia się potworów raidu Echo, m.in. Crawlera, oraz ponownego logowania w ich pobliżu.

Klient odrzucał niepustą dodatkową listę oznaczeń potwora w opisie mapy. Nie odczytywał również aktualizacji tej listy (0x8B, typ 15), więc jej bajty stawały się nieprawidłowymi opcode'ami. Obie ścieżki korzystają teraz z jednego parsera listy identyfikatorów. Stan oznaczeń jest przechowywany niezależnie od głównych ikon; pusta lista usuwa poprzedni stan. Usunięte/nieznane stworzenie nie zaburza odczytu następnego pakietu. Nie zastosowano pomijania błędów ani zgadywania granicy kolejnego opcode'u.

Zmiana jest sterowana istniejącą funkcją profilu GameCreatureIconV2, bez zależności od nazwy serwera lub potwora. Starszy format pozostaje niezmieniony. Nie zmieniono assets, bota, renderowania, cache ani mechanizmów ruchu.

## Weryfikacja

Kompilacja Windows x64 OpenGL zakończona poprawnie. Testy produkcyjnych funkcji parsera obejmują fragmenty zapisane przy błędzie Echo, zachowanie granicy następnego pakietu, pustą/wieloelementową/maksymalną listę, ucięte dane, usunięte stworzenie, rozdzielenie list ikon oraz kontrolę starszego profilu. Testy przeszły. Na prośbę użytkownika nie wykonywano ponownych testów rozgrywki; odtworzenie całego raidu pozostaje do weryfikacji przez gracza.

Zachowano poprawki logowania, pamięci grafiki i aktualizatora z v2026.11.15.3. Paczka programu nie zawiera haseł, kont, profili ani assets serwerów.

## Aktualizacja

Wyloguj się i zamknij klienta. Uruchom ponownie Nexus Client.exe — aktualizator pobierze wydanie i uruchomi klienta ponownie. Profile i ustawienia bota pozostają lokalne. Po aktualizacji sprawdź wejście do obszaru raidu Echo i ponowne logowanie obok tych potworów.
