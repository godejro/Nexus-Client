# Nexus Client v2026.10.26.1

- Natywny aktualizator: małe Checking for updates przy starcie, automatyczne pobieranie, MB/s, weryfikacja SHA256, instalacja i restart przed logowaniem. Nowy klient nie uruchamia CMD ani PowerShella. Starszy launcher pozostaje do migracji ze starszych wydań.
- 16 poprawnych ikon nowych czarów w kliencie, Action Bar i Magic Shooterze; nowe niebiesko-czarne tło logowania.
- Magical Archive: filtry profesji/grupy/poziomu, wyszukiwanie nazw i słów, Combat Stats/Additional, dane referencyjne 149 czarów i 133 efekty do podglądu z aktywnych assetów. Parametry własnego serwera mogą się różnić; nieznane pola pozostają puste.
- Sell All u NPC z zapisywanymi wykluczeniami ID. Cyclopedia uwzględnia nowe strzały, potiony i reward bags, jeżeli znajdują się w assetach serwera.
- Tryby walki po lewej stronie ekwipunku, węższy nagłówek minimapy i regulacja wysokości dolną krawędzią.
- Węższe główne okno CWEL BOT, animowane przełączniki kategorii, bez głównego ON. Alarms ze wspólnym repeat; nowe reguły Equipment z zakresem HP/MP 0–100%.
- Magic Shooter nie nalicza pełnego cooldownu za samo wysłanie odrzuconego czaru, gdy dostępne są potwierdzenia serwera. Jawne opóźnienia i prawdziwe cooldowny pozostają respektowane.
- Wall Keeper i Flower Block wykonują akcje po zakończeniu modyfikacji tile; poprawiona obsługa zajętych pól, odrzuconych użyć i wyłączenia funkcji. Smart Push nie kontynuuje po odrzuconej runie. Combo jako zwykłe ON/Edit w PvP.
- CaveBot: edycja supplies bez OFF, Auto Navigate po odkrytej mapie, środkowane etykiety waypointów i półprzezroczyste niebieskie pola trasy.
- Poprawiona granica wyjątków C++/LuaJIT; wyjątek zasobu nie rozwija stosu Lua wewnątrz aktywnego catch C++.

Testy: 45 testów C++, testy LuaJIT botów/updatera/NPC/cooldownów, natywny start i edytory bez logowania, 100 błędów zasobu C++/Lua, HTTP GitHub, instalacja prawdziwego nowego EXE nad poprzednim wraz z restartem, rollback przy zablokowanym pliku. Testy zachowują konfiguracje i assety w standardowych data/things/<wersja> i data/sounds/<wersja>.

Ważne: prawdziwy losowy timer MW/WG można pokazać tylko wtedy, gdy serwer przesyła czas danego przedmiotu. Nie potwierdzono tego dla Vantorii; klient nie zgaduje 20 sekund. Nie odtworzono dokładnego zgłoszonego crasha Wall Keeper podczas gry. Rzucanie czarów, PvP, wygląd animacji i trasy w rzeczywistej sesji wymagają testu na konkretnym serwerze. Magical Archive jest rozszerzonym widokiem referencyjnym, a nie pełną kopią serwerowego katalogu Tibii.

Aktualizacja zawiera program i CWEL BOT. Nie zawiera kont, ustawień graczy, prywatnych skryptów ani assetów serwerów. Wymagana istniejąca instalacja z assetami. Uruchamiaj Nexus Client.exe; ze starego wydania zaktualizuj program raz przez dotychczasowy updater/launcher.
