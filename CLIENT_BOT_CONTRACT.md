# Kontrakt klient ↔ bot (CWELBOT)

Funkcje, które Nexus Client gwarantuje botowi. Klient nie zmienia ich nazw ani
zachowania bez nowej wersji kontraktu. Bot zawsze sprawdza, czy funkcja istnieje
(np. `if modules.game_things.setItemLook then ... end`), bo gracz może mieć
starszego klienta.

## Locked Items (blokada sprzedaży)

Moduł `game_npctrade`, obiekt `controllerNpcTrader`:

| Funkcja | Wynik |
|---|---|
| `controllerNpcTrader:getLockedItemIds()` | lista ID zablokowanych przedmiotów |
| `controllerNpcTrader:setLockedItemIds(ids)` | zapisuje całą listę |
| `controllerNpcTrader:isSellBlocked(id)` | `true`, gdy przedmiot jest na liście |
| `controllerNpcTrader:setSellBlocked(id, state)` | dodaje lub usuwa jeden przedmiot |
| `controllerNpcTrader:getSellAllDelay()` | opóźnienie między sprzedażami w ms (0–2000), ustawione przez gracza w oknie Sell All |

## Wygląd przedmiotów (item looks)

Moduł `game_things`. Lokalna zmiana tylko tego, co jest rysowane: przedmiot
`fromItemId` wygląda jak `toItemId` (z animacją). ID przedmiotu zostaje bez
zmian dla `getId()`, pakietów, stackpos, use, skryptów, `Tile:setTimer` i
tekstów na kratce. Nic nie jest wysyłane do serwera ani zapisywane; po
zamknięciu klienta lista znika, a po wczytaniu innych assets (inny serwer)
zostaje zastosowana ponownie tylko tam, gdzie wygląd istnieje.

| Funkcja | Wynik |
|---|---|
| `modules.game_things.setItemLook(fromItemId, toItemId)` | `true`, gdy ustawione; `false`, gdy któregoś ID nie ma w assets klienta albo wygląd `toItemId` nie ma sprite'ów (wtedy nic się nie zmienia). `setItemLook(id, id)` usuwa wygląd. |
| `modules.game_things.clearItemLook(fromItemId)` | przywraca oryginał jednego ID |
| `modules.game_things.clearItemLooks()` | przywraca wszystkie oryginały od razu |
| `modules.game_things.getItemLooks()` | `{ [fromId] = toId, ... }` |
| `modules.game_things.hasLook(itemId)` | `true`, gdy klient potrafi narysować ten wygląd |
| `modules.game_things.getCosmeticLooks()` | `{ {id=56816, name='Turquoise nebula'}, ... }`: kosmetyki wbudowane w klienta |

Kosmetyki wbudowane w klienta (rysują się na każdym serwerze, także gdy
serwer nie ma tych przedmiotów w swoich assets; widzi je tylko ten gracz):
56816 Turquoise nebula, 56817 Yellow-green nebula, 56819 Purple nebula,
56821 Red-gold nebula, 56823 Navy nebula, 56825 Blue lightning,
56843 Bronze cube, 56844 Blue cube, 56845 Purple cube, 56846 Red cube,
oraz bliźniaki 56815, 56818, 56820, 56822, 56824, 56826 (te same klatki).

Przykład (magic wall jako „Turquoise nebula”):

```lua
local things = modules.game_things
if things and things.setItemLook and things.hasLook(56816) then
  things.setItemLook(2128, 56816)
  things.setItemLook(2129, 56816)
end
```

Gdy wyglądu nie da się narysować, przedmiot zawsze rysuje się w oryginale.
