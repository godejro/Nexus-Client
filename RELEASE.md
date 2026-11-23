# Nexus Client v2026.11.23.1

Na Thornii profil natywnego klienta 15.32 odczytuje pełny komunikat o zadanych obrażeniach. W poprzednim wydaniu trafienie potwora mogło przerwać sesję z błędem 134. Analizator uwzględnia teraz oba składniki trafienia. Profile ze starszym formatem nadal korzystają z dotychczasowego odczytu.

Przed logowaniem Nexus sprawdza obecność przedmiotów wymaganych przez znane katalogi Season IgłaOTS i Vantorii. Gdy brakuje wpisu, pobiera pasujący katalog wydawcy, sprawdza SHA256 i zapisuje go w osobnym folderze profilu. Przy nierozpoznanym przyszłym katalogu nadal można użyć importu aktualnego klienta w Nexus Studio.

Sprawdzono na żywo na Thornii wejście do świata, leczenie i obrażenia obszarowe w walce ze szczurami. Test lokalny potwierdził ponowne wczytanie naprawionych katalogów podczas przełączania profili.

Zamknij klienta i uruchom ponownie Nexus Client.exe, aby pobrać aktualizację.
