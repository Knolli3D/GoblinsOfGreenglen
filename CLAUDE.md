# Cloude Game

Ein 2D-Platformer in Godot 4.6, handgeschrieben in GDScript. Kein C#.

**Status:** Spiel läuft einwandfrei durch (alle Level, Combat, Coins, Win/Death-Flow). Der generierte Chiptune-Sound ist witzig und rundet das Ganze gut ab.

## Spielprinzip

Ritter springt durch 6 Level (Level 4+5 mit horizontalem Scrolling, Level 6 mit zufälliger
Gegner-/Coin-Platzierung), besiegt Goblins per Stomp und erreicht das rote Ziel-Flag.
- 3 Herzen (Health), Score +1 pro Kill, -1 pro Treffer/Fall
- Coins sammelbar (+1 pro Coin), werden im Win-Screen angezeigt
- Nach 6 Leveln: Gewinn-Screen mit Final Score + Coin-Count
- Stirbt der Spieler (0 HP): Freeze + "Ouch! Press R to retry"

## Steuerung

| Aktion | Taste |
|--------|-------|
| Bewegen | Pfeiltasten / A, D |
| Springen | Leertaste / Pfeil oben |
| Double-Jump | Leertaste zweimal (in der Luft) |
| Pause | Escape |
| Neustart | R |

## Dateistruktur

```
scripts/
  Game.gd         # Haupt-Controller: HUD, Menüs, Level laden, POW!-Effekt, Quests/Cases/Skins-UI
  Progression.gd  # Autoload-Singleton: Daily Quests, Keys-Währung, Case-Opening, Skin-Inventory
  Player.gd       # CharacterBody2D: Bewegung, Double-Jump, Stomp, Signals, apply_skin()
  Enemy.gd        # CharacterBody2D: Patrol (@export patrol_range), Kill-Logik
  Coin.gd         # Area2D: Coin-Pickup, ruft game.coin_collected()
  Goal.gd         # Area2D: add_to_group("goals"), _draw() Flag-Visual
  Platform.gd     # StaticBody2D: Sprite-Scale aus CollisionShape-Größe
  Level.gd        # Node2D Basis: _draw() Himmel + Berge Hintergrund, optionales randomize_level_spawns()

scenes/
  Main.tscn         # Einstieg → lädt Game.gd
  Player.tscn       # CharacterBody2D + CollisionShape2D + Sprite2D
  Enemy.tscn        # CharacterBody2D + CollisionShape2D + Sprite2D
  Coin.tscn         # Area2D + CircleShape2D
  Goal.tscn         # Area2D + RectangleShape2D
  Platform.tscn     # StaticBody2D + CollisionShape2D (Template)
  Level1-5.tscn     # Visuelle Level, komplett handplatziert (editierbar im 2D-Editor!)
  Level6.tscn       # Wie Level1-5, aber Gegner/Coins werden zur Laufzeit zufällig platziert

assets/
  sprite_knight.png   # Ritter-Sprite (788×1674, transparent)
  sprite_goblin.png   # Goblin-Sprite (923×1318, transparent)
  sprite_platform.png # Plattform-Textur (4128×496)
  sky.png             # Himmel-Hintergrund (Parallax)
  knight.png / goblin.png / platform.png  # Original-Uploads (Backup)
  audio/              # Generierte Chiptune-WAVs (SFX + music.wav Loop)

tools/
  generate_audio.py   # Erzeugt alle WAVs in assets/audio/ (Python-Stdlib)

default_bus_layout.tres  # Audio-Busse: Master → Music (-6 dB), SFX
```

## Architektur

- **Level als .tscn-Dateien** → im Godot 2D-Editor visuell editierbar
- **Game.gd** ist der zentrale Controller; lädt Level-Scenes via `load(LEVELS[idx]).instantiate()`
- **Player** wird von Game.gd per `find_child("PlayerSpawn")` im Level platziert
- **Kommunikation per Signals** (nicht get_parent().get_parent()):
  - `Player` emittiert: `stomped_enemy`, `hit_enemy`, `fell_off`, `reached_goal`, `jumped`, `double_jumped`
  - `Coin` ruft `game.coin_collected()` via `get_tree().get_first_node_in_group("game")`
- **Game.gd** ist in Gruppe `"game"`, Player in `"player"`, Enemies in `"enemies"`, Goals in `"goals"`
- **Progression.gd** ist der einzige Autoload/Singleton im Projekt (Ausnahme vom Group-Lookup-Pattern,
  da Meta-Progression session-übergreifend und auch im Hauptmenü ohne geladenes Level lesbar sein muss)

## Kollisionslayer

| Layer | Name   | Wer |
|-------|--------|-----|
| 1     | world  | Plattformen (StaticBody2D) |
| 2     | player | Spieler (CharacterBody2D) |
| 3     | enemy  | Gegner (CharacterBody2D) |
| 4     | goal   | Ziel-Area (Area2D, mask=2) |

## Physik-Konstanten (Player.gd)

| Konstante | Wert |
|-----------|------|
| Gravity | 1400 px/s² |
| Move Speed | 220 px/s |
| Jump Velocity | -520 px/s |
| Double-Jump Velocity | -460 px/s |
| Enemy Speed | 60 px/s |

## Level editieren

Level-Szenen (`scenes/Level1-5.tscn`, handplatziert) im Godot-Editor öffnen:
- **Plattform verschieben**: Node in Scene-Tree auswählen → Drag im 2D-View
- **Plattform-Größe**: `CollisionShape2D` auswählen → Inspector → `Shape → Size`
- **Gegner-Patrol**: Enemy-Instanz auswählen → Inspector → `Patrol Range`
- **Neuer Gegner**: `Enemy.tscn` aus FileSystem in Level-Scene ziehen
- **Neue Coin**: `Coin.tscn` aus FileSystem in Level-Scene ziehen
- **PlayerSpawn**: `Marker2D` namens `PlayerSpawn` im Level bewegen

Level6.tscn (zufällige Spawns) hat **keine** handplatzierten Enemy/Coin-Instanzen — dort stattdessen
Plattformen zur Gruppe `spawn_platforms` hinzufügen (siehe Abschnitt oben).

## Zufällige Gegner-/Coin-Platzierung (Level.gd, ab Level 6)

`Level.gd` ist die Basis-Klasse für alle Level und trägt jetzt ein optionales, wiederverwendbares
Zufalls-Spawn-System (opt-in, Default aus — Level 1-5 bleiben unverändert handplatziert):

- **Aktivierung**: `@export var randomize_spawns: bool` auf dem Level-Root (`randomize_spawns = true`
  in Level6.tscn), plus `@export var goblin_count`/`coin_count` (Default 8/10, passend zu Level 5s Dichte).
- **Spawn-Plattformen markieren**: Plattformen, die als Spawn-Punkt in Frage kommen, werden im
  Node-Dock → Groups-Tab zur Gruppe `"spawn_platforms"` hinzugefügt (kein neuer Node-Typ nötig).
  Start- und Ziel-Plattform bleiben unmarkiert, damit kein Gegner direkt am Spawn oder Ziel steht.
- **`Game._load_level()`** ruft direkt nach `add_child(level_root)` `level_root.call("randomize_level_spawns")`
  auf — läuft bei jedem Levelstart/Retry neu, ohne gespeicherten Seed (jedes Mal anders).
  Aufruf per `.call()`, da `level_root` statisch als `Node2D` typisiert ist.
- **Platzierungslogik**: pro markierter Plattform wird die sichere X-Spanne aus
  `CollisionShape2D.shape.size` berechnet — bei Gegnern abzüglich eines zufälligen
  `patrol_range` (20–40, wie bei den handplatzierten Level-5-Gegnern) + Sicherheitsabstand,
  damit `Enemy.gd`s Patrol (kein Kanten-Check!) nie über die Plattformkante hinausläuft.
  Y-Offsets (`ENEMY_Y_OFFSET = -13`, `COIN_Y_OFFSET = -35`) sind aus den handplatzierten
  Level-5-Koordinaten abgeleitet, damit prozedurale Spawns genauso aussehen wie handplatzierte.
  Ein Gegner pro Plattform (zyklisch bei Überschuss), Coins dürfen sich mehrfach eine Plattform teilen.

## Sprite-Skalierung

Sprites werden in `_ready()` der jeweiligen Scripts skaliert (kein White-Keying nötig — Sprites sind bereits transparent):
- Knight: Ziel-Höhe 52px → `scale = 52 / 1674`
- Goblin: Ziel-Höhe 40px → `scale = 40 / 1318`
- Platform: Breite/Höhe aus CollisionShape2D-Größe berechnet

## POW!-Effekt

`Game.gd._spawn_pow(pos)` erstellt einen animierten `Label`-Node auf einem temporären `CanvasLayer` (layer=20), der hochschwebt und ausfadet.

## Audio

Alle Sounds sind generierte Chiptune-WAVs (`python3 tools/generate_audio.py` → `assets/audio/`).
- **Busse** (`default_bus_layout.tres`): `Master` → `Music` (-6 dB), `SFX`
- **Game.gd** besitzt alle Audio-Nodes: 1× `AudioStreamPlayer` für Musik (Bus Music),
  8 Round-Robin-Voices für SFX (Bus SFX). `play_sfx(name, pitch_jitter)` spielt aus `SFX_FILES`;
  `pitch_jitter` variiert `pitch_scale` leicht gegen Monotonie (Coin, Stomp, Jump).
- **Musik**: `music.wav` loopt via `AudioStreamWAV.LOOP_FORWARD` (loop_end aus `get_length() × mix_rate`
  berechnet, da der Import QOA-komprimiert). Start bei Spielstart, Stop bei Tod/Win/Hauptmenü,
  Ducking auf -14 dB im Pause-Menü.
- **Jump-Sounds**: Player emittiert `jumped`/`double_jumped`, Game.gd verbindet sie in `_load_level()`.
- Events: jump, double_jump, coin, stomp, hit, death, level_clear, win, click (UI-Buttons).

## Highscore (lokal)

Bester abgeschlossener Run wird in `user://highscore.cfg` gespeichert (ConfigFile, Sektion
`[highscore]` mit `score` + `coins`). Nur lokal — kein Online-Leaderboard (geplant: später via Website).
- **Game.gd**: `_load_highscore()` in `_ready()`, `_submit_run(score, coins)` beim Win-Screen
  (speichert nur, wenn besser: höherer Score, bei Gleichstand mehr Coins) → zeigt "★ New Highscore! ★"
  bzw. den bestehenden Bestwert an. Hauptmenü zeigt "Best: Score X 🪙 Y" unter dem Titel.
- Für das spätere Web-Leaderboard ist `_submit_run()` der einzige Hook-Punkt.

## Quests, Keys & Cases (Progression.gd)

Meta-Progression-Loop, unabhängig vom Coins/Score-System: Keys werden ausschließlich über Daily
Quests verdient (nicht mit Coins kaufbar, damit Cases nicht trivial grindbar sind). Persistiert in
`user://progression.cfg` (ConfigFile, gleiches Muster wie `highscore.cfg`), Sektionen `[currency]`,
`[quests]`, `[inventory]`.

- **Daily Quests**: 3 aktive Quests aus einem Pool von 7 (`QUEST_POOL`), Reset am echten
  Kalendertag (`Time.get_date_string_from_system()` Vergleich gegen `last_reset`) — passiert in
  `_ready()` und beim Öffnen des Quests-Menüs. Quest-Typen: Goblins stompen, Coins sammeln (2 Größen),
  Ziel ohne Schaden erreichen, kompletten Run beenden, Double-Jumps, Level clearen.
- **Refill & Fragmente**: Sobald alle 3 Dailies geclaimed sind, rollt sofort ein frisches Set
  (in `claim_quest()`; `_refill_if_all_claimed()` als Safety-Net für Alt-Saves). Die ersten 6
  Daily-Claims pro Tag (`DAILY_FULL_KEY_CLAIMS`) geben je 1 Key; danach je 1 Key-Fragment
  (`key_fragments`, 3 = 1 Key, `FRAGMENTS_PER_KEY`) — unbegrenztes Grinden bleibt möglich,
  ist aber 3x weniger effizient. `daily_claims_today` wird beim Tagesreset genullt.
- **Weekly Quests**: 2 aktive aus `WEEKLY_POOL` (4 Typen: 10 Runs, 50 Goblins, 100 Coins,
  3 schadenfreie Runs), je 3 Keys (`WEEKLY_REWARD`), kein Refill innerhalb der Woche.
  Wochen-Identität: Montag-basierter Wochenindex seit Epoch (`_current_week_id()`,
  Unix-Zeit / 86400 + 3 Tage Offset / 7), Reset via `check_weekly_reset()`.
- **Progress-Tracking**: `Progression.add_quest_progress(stat)` aktualisiert Dailies UND Weeklies;
  Hooks in Game.gd: `coin_collected()`, `_on_player_stomped_enemy()`, `reach_goal()`
  (auch `level_clear` pro Ziel), `double_jumped`-Signal (in `_load_level()` verbunden).
  `took_damage_this_level` (pro Level) trackt den Schadenlos-Level-Quest,
  `took_damage_this_run` (pro Run, Reset an allen Run-Start-Stellen) den schadenfreien Run-Weekly.
  Wichtig: Tod erzwingt Neustart ab Level 1, d.h. jeder *abgeschlossene* Run ist automatisch
  todlos — deshalb gibt es "Finish X runs" (Volumen) und "ohne Schaden" (Skill) statt "ohne Tod".
- **Claim**: Keys werden nicht automatisch vergeben — im Quests-Menü muss ein fertiger Quest
  per Button bestätigt werden (`Progression.claim_quest(slot)` / `claim_weekly(slot)`).
  Das Quests-Menü hat zwei Sektionen (Daily/Weekly) mit Statuszeile für Bonus-Modus/Fragmente.
- **Cases**: 1 Key = 1 Case-Opening. Rewards sind Skins mit gewichteten Rarity-Tiers
  (`SKIN_TIERS`: Common/Rare/Epic), Duplikate sind erlaubt (kein Pity-/Dust-System).
  Reveal-Animation (`Game._spawn_skin_reveal()`) nutzt das gleiche Tween-Muster wie `_spawn_pow()`.
- **Skins**: zwei Varianten je nach `SKIN_TIERS`-Eintrag. Common-Skins (Bronze/Silber) sind reine
  Farb-Tints (`Sprite2D.modulate`) ohne neues Artwork — funktioniert nur für Helligkeits-/Sättigungs-
  Verschiebungen der Basis-Palette. Rare/Epic-Skins (Gold/Emerald/Blood) nutzen echtes Artwork
  (`texture`-Feld mit Pfad zu `assets/sprite_knight_*.png`), da Tinting bei neuen Farbtönen falsche
  Ergebnisse liefert (z.B. blauer Umhang wird unter Gold-Tint grün statt gold). `Player.apply_skin(skin)`
  bekommt das komplette Skin-Dictionary, tauscht bei vorhandenem `texture`-Feld die Sprite-Textur
  (inkl. Neuberechnung der Skalierung, da die Artwork-Dateien unterschiedliche Pixelmaße haben),
  sonst nur `modulate`. Ausrüsten über `Progression.equip_skin(id)`, angewendet in
  `Game._load_level()` via `player.apply_skin(Progression.get_equipped_skin())` bei jedem
  Levelstart. Ohne ausgerüsteten Skin bleibt der Ritter unverändert (`Color.WHITE`, Default-Textur).
- **UI**: 3 neue Hauptmenü-Buttons (Quests/Cases/Skins), Keys-Anzeige im HUD. "Quit Game" ist
  bewusst nicht Teil der VBoxContainer-Button-Liste, sondern unten rechts fix verankert
  (`PRESET_BOTTOM_RIGHT` + `offset_*`), damit neue Menü-Buttons es nicht aus dem Fenster schieben.
- **Out of scope (bewusst)**: Gameplay-Perks (nur Skins in v1), Keys mit Coins kaufen,
  weitere Level für mehr Quest-Varianz — siehe Plan-Historie für Details.

## Viewport

960×540 intern, Fenster 1280×720 (canvas_items stretch).
