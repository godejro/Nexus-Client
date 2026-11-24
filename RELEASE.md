# Nexus Client v2026.11.24.5

Okno handlu z NPC otwiera się i odświeża płynniej. Lista sprzedaży liczy ilości jednym przebiegiem zamiast tysięcy odczytów ekwipunku przy każdym sortowaniu. Gdy przychodzi aktualizacja przedmiotów, a lista się nie zmieniła, klient tylko przekolorowuje wiersze zamiast budować je od nowa. Zmiana samego złota nie przebudowuje listy.

Nowy moduł client_memlog co minutę zapisuje zużycie pamięci klienta, stron atlasu tekstur, pamięci Lua i liczby stworzeń. Plik nexus_memlog.csv w katalogu zapisu klienta zawiera ostatnie 12 godzin i pozwala ustalić, co rośnie w długiej sesji.
