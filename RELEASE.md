# Nexus Client v2026.11.23.4

Poprawiono rozłączenie na Thornii po odblokowaniu czaru. Czytnik wiadomości 0x75 obsługuje identyfikator czaru oraz zdarzenia zadań bounty i tygodniowych. Po zdarzeniu kontynuuje odczyt statystyk gracza i dalszych wiadomości.

Przy błędzie protokołu packet.log zapisuje czas, profil i wersję, funkcję odczytującą wiadomość, pozycję błędu oraz historię do ośmiu poprzednich wiadomości. Dla zdarzeń klienta podaje numer podtypu, a przy brakujących danych liczbę wymaganych i dostępnych bajtów. Po osiągnięciu 2 MiB zachowuje poprzedni log jako packet.log.1 i zapisuje kolejne zdarzenia w packet.log.
