# Goblins of Greenglen

Ein 2D-Platformer in Godot 4.6, handgeschrieben in GDScript. Kein C#.
(Repo/Ordner heißt weiterhin `cloude-game`; "Goblins of Greenglen" ist nur der In-Game-Anzeigename
via `config/name` in `project.godot`. Achtung: `config/name` bestimmt auch den `user://`-Save-Pfad —
alte Saves aus `app_userdata/Cloude Game` werden von `scripts/SaveMigration.gd` automatisch
übernommen, siehe Abschnitt "Save-Migration".)

**Status:** Spiel läuft einwandfrei durch (alle Level, Combat, Coins, gemeinsamer Run-Result-Flow "Run Complete"/"Run Over"). Der generierte Chiptune-Sound ist witzig und rundet das Ganze gut ab.

## Spielprinzip

Ritter springt durch 6 Level (Level 4+5 mit horizontalem Scrolling, Level 6 mit zufälliger
Gegner-/Coin-Platzierung), besiegt Goblins per Stomp und erreicht das rote Ziel-Flag.
- 3 Herzen (Health), Score +1 pro Kill, -1 pro Treffer/Fall
- Stomp zählt nur beim Abwärtsflug und beim Überqueren der Goblin-Oberkante von oben;
  Aufwärts- und Seitenkontakt verursachen Schaden
- 1s Invulnerability nach Treffer/Fall-Respawn (`invuln_until`); wird in `_load_level()` und
  im Hauptmenü auf 0.0 zurückgesetzt — bewusst keine Spawn-Protection beim Levelstart
  (PlayerSpawn liegt überall abseits der Gegner)
- Coins sammelbar (+1 pro Coin), werden im Result-Menü angezeigt
- Beide Run-Ausgänge teilen sich EIN Result-Menü (siehe "Run-Result-System"): Level 6
  geschafft = "Run Complete" (Gold-Akzent), Tod durch tödlichen Treffer/Fall = "Run Over"
  (warmer Akzent) — beide mit Score, Coins, Bestwert, stabiler optionaler
  "New Highscore!"-Zeile (nur bei COMPLETED möglich), "Run Again" und "Main Menu";
  `R` startet ebenfalls einen frischen Run

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
  Game.gd         # Run-Coordinator: Gameplay-State, Level-Lifecycle, Player-Signale, Transitions
  AudioController.gd # Musik/SFX-Player, Voice-Pool und Pause-Ducking
  HUDController.gd   # HUD-Snapshot, transiente Meldung und POW!-Feedback
  GameMenuController.gd # Haupt-/Pause-/Result-Menü; emittiert nur Navigations-Intents
  QuestMenuController.gd # Daily-/Weekly-Quest-Darstellung und Claims
  CaseMenuController.gd  # Case-Reel, Spin-State und Rarity-Reveal
  SkinMenuController.gd  # Skin-Liste, Preview und Equip-Aktion
  HighscoreStore.gd      # Highscore-V2 laden/vergleichen/speichern via SaveData
  GreenglenUI.gd         # Gemeinsame Theme-/Font-/Submenu-Factory
  Progression.gd  # Autoload-Singleton: Daily Quests, Keys-Währung, Case-Opening, Skin-Inventory
  Player.gd       # CharacterBody2D: Bewegung, Double-Jump, Swept-Stomp-Test, Signals, apply_skin()
  Enemy.gd        # CharacterBody2D: Patrol, vorherige Globalposition, Kill-Logik
  Coin.gd         # Area2D: Coin-Pickup, ruft game.coin_collected()
  Goal.gd         # Area2D: add_to_group("goals"), _draw() Flag-Visual
  Platform.gd     # StaticBody2D: Sprite-Scale aus CollisionShape-Größe
  Level.gd        # Node2D Basis: Parallax-Hintergrund (mit _draw()-Fallback), optionales randomize_level_spawns()
  SaveMigration.gd # Statischer Helper: einmalige Save-Übernahme aus "Cloude Game" (siehe Save-Migration)
  SaveData.gd     # Statische Save-Helfer: getypte Reads, [meta]-Versionierung, .bak-Backups (siehe Save-System)

scenes/
  Main.tscn         # Einstieg: Game.gd-Root + sieben explizite Controller-Kinder
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
  sprite_knight_*.png   # Skin-Artwork (gold, emerald, pink, blood, black)
  sprite_princess_*.png # Legendary-Skin-Artwork (blue = Starter, gold, green, purple, red)
  level_bg_near.png   # Level-Parallax-Hintergrund (Landschaft, siehe Level.gd)
  level_bg.png        # Wolken-Himmel (opak → aktuell ungenutzt, siehe Parallax-Abschnitt)
  menubackground.png  # Hauptmenü-Hintergrundbild (Schloss-Artwork)
  menu_bg_quests.png / menu_bg_cases.png / menu_bg_skins.png  # Submenü-Hintergründe
  LOGO_menu_GoGg.png  # Titel-Logo im Hauptmenü (ersetzt Text-Label, siehe UI-Theme-Abschnitt)
  icon_GoGg.png       # App-/Fenster-Icon, via `config/icon` in project.godot referenziert
  ui/buttons/button_greenglen_*.png  # Nine-Patch-Button-Texturen (normal/hover/pressed/disabled)
  knight.png / goblin.png / platform.png  # Original-Uploads (Backup)
  audio/              # Generierte Chiptune-WAVs (SFX + music.wav Loop)

Cinzel/               # Cinzel-Schriftfamilie (SIL OFL), static/Cinzel-{SemiBold,Bold}.ttf
                       # werden vom UI-Theme geladen (siehe Abschnitt "UI-Theme")

tools/
  generate_audio.py   # Erzeugt alle WAVs in assets/audio/ (Python-Stdlib)

tests/
  run_all.gd          # DER Test-Runner: beide Suiten als isolierte Kind-Prozesse + Canary (siehe Tests-Abschnitt)
  test_save_system.gd # Save-System-Suite (79 Checks)
  test_smoke.gd       # Smoke-/Verhaltens-Suite (152 Checks inkl. Komponenten, Meta-Menüs, Run-Results)
  test_env.gd         # Isolations-Helfer (setzt GOGG_TEST_SAVE_DIR vor Autoload-Start)

default_bus_layout.tres  # Audio-Busse: Master → Music (-6 dB), SFX
```

## Architektur

- **Level als .tscn-Dateien** → im Godot 2D-Editor visuell editierbar
- **Game.gd** ist der schlanke Run-Coordinator und alleinige Besitzer von Levelindex, Health,
  Score, Coins, Damage-Flags, Invulnerability, `RunOutcome` und `transition_gen`. Er lädt
  Level-Scenes via `load(LEVELS[idx]).instantiate()` und verteilt Zustands-Snapshots/Intents
  über kleine Controller-APIs; UI-Komponenten besitzen keine Kopie des Gameplay-Zustands.
- **Main.tscn komponiert die Controller sichtbar im Scene-Tree**: `AudioController`,
  `HighscoreStore`, `HUDController`, `GameMenuController`, `QuestMenuController`,
  `CaseMenuController`, `SkinMenuController`. `Game._ready()` injiziert EIN gemeinsames
  Theme und den Audio-Service, verbindet Intent-Signale genau einmal und startet danach
  den normalen Menü-Lifecycle. Kein Controller ist ein zusätzlicher Autoload.
- **Kommunikationsgrenzen**: `GameMenuController` emittiert Start/Resume/Restart/Main-Menu/
  Submenu/Quit-Intents; die drei Submenüs emittieren `back_requested`, das Quest-Menü
  zusätzlich `keys_changed`. Nur Game entscheidet über Run-/Level-Lifecycle. Meta-Menüs
  lesen/ändern die Source of Truth `Progression`; Audio wird als explizite Referenz injiziert.
- **UI-/CanvasLayer-Ownership**: `GameMenuController` besitzt Result (8), Main (9) und Pause
  (10), die Submenü-Controller je ihren Layer (11/12/13), `HUDController` den Gameplay-HUD
  plus temporäre POW-Layer (20), `CaseMenuController` temporäre Reveal-Layer (21).
- **Player** wird von Game.gd per `find_child("PlayerSpawn")` im Level platziert
- **Kommunikation per Signals** (nicht get_parent().get_parent()):
  - `Player` emittiert: `stomped_enemy`, `hit_enemy`, `fell_off`, `reached_goal`, `jumped`, `double_jumped`
  - `Coin` ruft `game.coin_collected()` via `get_tree().get_first_node_in_group("game")`
- **Kampf bleibt signalbasiert und ohne Player/Enemy-Physikkollision**: `Player.gd` klassifiziert
  Kontakte anhand der Rechteck-Collider und emittiert weiterhin nur `stomped_enemy` oder `hit_enemy`.
  `Game._on_player_stomped_enemy()` prüft vor Kill/Score/SFX/Quest/POW nochmals `is_enemy()`, damit
  ein veraltetes oder doppeltes Signal niemals mehrfach belohnt wird.
- **Game.gd** ist in Gruppe `"game"`, Player in `"player"`, Enemies in `"enemies"`, Goals in `"goals"`
- **Progression.gd** bleibt der einzige Autoload/Singleton im Projekt (Ausnahme vom Group-Lookup-Pattern,
  da Meta-Progression session-übergreifend und auch im Hauptmenü ohne geladenes Level lesbar sein muss)
- **Level-Übergänge (Race-Schutz)**: `reach_goal()` wartet 1s ("Level Cleared!", Timer pausiert
  mit dem Spiel) und validiert danach gegen das Generation-Token `transition_gen`, das von
  `_load_level()`, `_show_main_menu()` und `_finish_run()` erhöht wird — veraltete
  Übergangs-Coroutinen nach Restart/Menü/Run-Ende laden nichts mehr. Neue Code-Pfade, die
  Level wechseln, ins Menü führen oder den Run beenden, müssen durch eine dieser
  Funktionen laufen (oder das Token selbst erhöhen)

## Run-Result-System (Game.gd)

Ein gemeinsames, outcome-getriebenes Result-Menü ersetzt den alten Win-Screen und die
"Ouch!"-Textmeldung. Terminologie ist bewusst Run-orientiert ("Run Over" / "Run Complete" /
"Run Again"), da das Spiel später ggf. ein Infinite Runner wird.

- **Zustand**: `enum RunOutcome { NONE, FAILED, COMPLETED }` + `run_outcome`. NONE = Run
  läuft; FAILED (tödlicher Treffer/Fall) und COMPLETED (Level 6 geschafft) sind final —
  nur `_load_level()` und `_show_main_menu()` setzen auf NONE zurück.
- **Genau-einmal-Garantie**: `_finish_run(outcome)` ist der EINZIGE Lifecycle-Eintritts-
  punkt für das Run-Ende. Guard: bei `run_outcome != NONE` ist jeder weitere Aufruf
  (doppelte Fatal-/Goal-Signale, nachlaufende Callbacks) ein No-Op — Highscore-Submit und
  Quest-Fortschritt können nie doppelt vergeben werden. `damage_player()`/`fell_off_world()`/
  `reach_goal()` sind zusätzlich über `run_outcome`/`transitioning` geguardet.
- **Completed-only-Policy**: `_submit_run()` (Highscore) und der `finish_run`-/
  `no_damage_run`-Quest-Progress laufen ausschließlich im COMPLETED-Zweig von
  `_finish_run()`. FAILED spielt den Death-SFX, stoppt die Musik und zeigt nur das
  Ergebnis — Fehlversuche ändern `highscore.cfg` nie.
- **Transition-Invalidierung**: `_finish_run()` erhöht `transition_gen` — eine noch
  wartende `reach_goal()`-Coroutine (1s-"Level Cleared!"-Fenster) lädt danach nichts mehr.
- **Präsentation**: `Game._show_run_result()` übergibt nur Outcome, Run-Werte und
  `HighscoreStore.result_text()` an `GameMenuController.show_result()`. Der Menü-Controller
  besitzt EINE geteilte Control-Hierarchie (`run_result_menu`, CanvasLayer 8,
  `PROCESS_MODE_ALWAYS`, gemeinsames Theme, Cinzel-Bold-Titel): Titel wechselt Text + Akzentfarbe
  (`RESULT_COMPLETED_ACCENT` = Gold wie Legendary-/Highscore-Akzente,
  `RESULT_FAILED_ACCENT` = zurückhaltendes warmes Rot-Orange); darunter Final Score,
  Coins, Best-Run-Zeile (bzw. "No completed run yet") und die stabile optionale
  "New Highscore!"-Zeile. "Run Again" erhält initialen Tastatur-Fokus. Das letzte
  Gameplay-Bild bleibt hinter dem dunklen Dimmer sichtbar (`level_root` =
  `PROCESS_MODE_DISABLED`), HUD ist ausgeblendet.
- **Kein UI über dem Result**: Escape öffnet KEIN Pause-Menü, solange ein Result aktiv
  ist (`_unhandled_input`-Guard); `_show_message()` delegiert "Level Cleared!" an
  `HUDController.message_label` und zeigt nichts über einem aktiven Result.
- **Clean-Run-Pfad**: `_start_new_run()` ist DER zentrale Neustart — R,
  Result-"Run Again" und Pause-"Try Again" laufen alle über
  `_restart_level_from_menu()`/`_start_new_run()`: Pause + Musik-Ducking zurücksetzen,
  Score/Coins/Run-Schaden nullen, Musik starten, `_load_level(0)`. `_load_level()` ist
  die Lifecycle-Grenze und setzt zentral Health, `transitioning`, `run_outcome`,
  `transition_gen`, `invuln_until` zurück und blendet Result-UI/HUD über die Controller-APIs um.
  "Main Menu" nutzt `_show_main_menu()` (räumt Musik, Pause, HUD, Transitions,
  Invulnerability, Result-Zustand und Gameplay-Nodes konsistent ab).
- **Unverändert**: 1s-Schutz nach nicht-tödlichem Treffer/Fall-Respawn, bewusst keine
  Spawn-Protection beim Levelstart, signalbasiertes Player/Game-Interface sowie
  Damage-/Score-/Coin-/Quest-/Stomp-Systeme.

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
| Stomp Top Tolerance | 2 px |
| Min. horizontaler Stomp-Overlap | 4 px |

## Stomp-Erkennung (Player.gd / Enemy.gd)

Die Bodies kollidieren weiterhin nicht physisch miteinander; die leichte manuelle Kampflogik ist
jetzt aber richtungs- und frameratefest:

- `Player._physics_process()` merkt sich direkt vor `move_and_slide()` die vorherige
  `global_position` und ob `velocity.y > 0.0` war. Nur ein abwärts bewegter Player kann stompen.
- Player- und Enemy-Ausdehnung kommen aus ihren echten `RectangleShape2D`-Collidern inklusive
  globaler Skalierung; die alten Magic Numbers `dx < 25` / `dy < 35` sind entfernt.
- `Enemy.gd` speichert pro Physikframe seine vorherige Globalposition. Dadurch wird der Zeitpunkt,
  an dem die Player-Füße die bewegte Enemy-Oberkante kreuzen, zwischen vorheriger und aktueller
  Position interpoliert. An diesem Zeitpunkt müssen mindestens 4 px horizontal überlappen;
  `STOMP_TOP_TOLERANCE` (2 px) hält den Stomp leicht verzeihend.
- Jeder andere Swept-AABB-Kontakt — von unten, von der Seite oder mit zu wenig Top-Overlap —
  emittiert `hit_enemy`. Das Sweeping verhindert Durchtunneln bei groben Physikschritten.
- Tote Gegner liefern `is_enemy() == false` und werden ignoriert. Nach einem gültigen Stomp bleiben
  Bounce (`velocity.y = DOUBLE_JUMP_VELOCITY`) und `jumps_remaining = MAX_JUMPS` unverändert.

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

## Level-Hintergrund (Parallax, Level.gd)

Gemeinsamer, code-gebauter Parallax-Hintergrund für **alle** Level (keine Per-Level-.tscn-Änderung):
- **`BG_LAYERS`** (Konstante in `Level.gd`): Liste von `{path, scroll_scale}`. `_ready()` ruft
  `_build_parallax_background()`, das pro vorhandener Textur ein `Parallax2D` mit `Sprite2D`-Kind baut.
  `scroll_scale < 1` = Layer scrollt langsamer als die Welt (Tiefenwirkung); `z_index = -20 + i`
  (hinter Plattformen/Gegnern/Coins/Player). Sprite wird auf 540px Viewport-Höhe skaliert,
  `repeat_size.x` = skalierte Breite → horizontales Tiling über die volle Levelbreite.
- **`Parallax2D`** (Godot 4.6) trackt automatisch die aktive Kamera (Viewport-Canvas-Transform) —
  die Kamera wird in `Game._load_level()` zur Laufzeit am Player erzeugt, **kein Wiring nötig**.
- **Artwork**: aktuell ein Layer, `assets/level_bg_near.png` (komplette Landschaft: Himmel +
  Wolken + Berge + Hügel, `scroll_scale 0.4`). Fehlt die Datei, greift der `_draw()`-Fallback
  (flacher Himmel + Bodenband, wie zuvor); `_bg_active` schaltet um. Viewport-Clear-Color ist
  bereits himmelblau, deckt also Lücken ab.
- **Echte Mehr-Layer-Parallax** braucht einen vorderen Layer mit **transparentem Himmel** (Alpha),
  sonst deckt der opake Vorder-Layer den hinteren komplett ab. `assets/level_bg.png` (Wolken-Himmel)
  und `level_bg_near.png` sind beide opak → nur ein sichtbarer Layer möglich; `level_bg.png` daher
  aktuell nicht in `BG_LAYERS`. Für Tiefe müsste ein Layer als Alpha-Cutout vorliegen.

## Sprite-Skalierung

Sprites werden in `_ready()` der jeweiligen Scripts skaliert (kein White-Keying nötig — Sprites sind bereits transparent):
- Knight: Ziel-Höhe 52px → `scale = 52 / 1674`
- Goblin: Ziel-Höhe 40px → `scale = 40 / 1318`
- Platform: Breite/Höhe aus CollisionShape2D-Größe berechnet

## POW!-Effekt

`HUDController.spawn_pow(pos)` erstellt einen animierten `Label`-Node auf einem temporären,
vom HUD-Controller besessenen `CanvasLayer` (layer=20), der hochschwebt und ausfadet.

## Audio

Alle Sounds sind generierte Chiptune-WAVs (`python3 tools/generate_audio.py` → `assets/audio/`).
- **Busse** (`default_bus_layout.tres`): `Master` → `Music` (-6 dB), `SFX`
- **AudioController.gd** besitzt alle Audio-Nodes: 1× `AudioStreamPlayer` für Musik (Bus Music),
  8 Round-Robin-Voices für SFX (Bus SFX). `play_sfx(name, pitch_jitter)` spielt aus `SFX_FILES`;
  `pitch_jitter` variiert `pitch_scale` leicht gegen Monotonie (Coin, Stomp, Jump).
- **Musik**: `music.wav` loopt via `AudioStreamWAV.LOOP_FORWARD` (loop_end aus `get_length() × mix_rate`
  berechnet, da der Import QOA-komprimiert). Start bei Spielstart, Stop bei Tod/Win/Hauptmenü.
- **Jump-Sounds**: Player emittiert `jumped`/`double_jumped`; Game verbindet sie in
  `_load_level()` mit seinem schmalen `play_sfx()`-Facade zum AudioController.
- Events: jump, double_jump, coin, stomp, hit, death, level_clear, win, click (UI-Buttons).
- **Musik-Lautstärke (zentralisiert)**: einziger Schreibzugriff auf `music_player.volume_db`
  ist `AudioController.set_music_ducked(bool)`, gesteuert über `MUSIC_NORMAL_DB` (0 dB) / `MUSIC_PAUSED_DB`
  (-14 dB) — beide Werte addieren sich auf den Music-Bus (-6 dB), Ducking ergibt also -20 dB
  Gesamtausgang. `_toggle_pause()`, `_restart_level_from_menu()`, `_start_game()` und
  `_show_main_menu()` rufen alle `_set_music_ducked(false)`/`(true)` auf — verhindert, dass
  "Exit to Menu" während der Pause den gedämpften Pegel in den nächsten Run durchreicht
  (ehemaliger Bug: `_show_main_menu()` stoppte die Musik, setzte aber nie den Pegel zurück).

## Highscore (lokal)

Bester abgeschlossener Run wird in `user://highscore.cfg` gespeichert (ConfigFile, Sektionen
`[meta]` (Schema-Version) + `[highscore]` mit `score` + `coins` — Validierung/Versionierung/Backup
siehe Abschnitt "Save-System"). Nur lokal — kein Online-Leaderboard (geplant: später via Website).
- **HighscoreStore.gd** besitzt Pfad, Schema-Version, Laden, Backup-kompatibles Speichern und
  Vergleich. `Game._submit_run(score, coins)` bleibt der eine künftige Web-Leaderboard-Hook
  und delegiert an `HighscoreStore.submit()` ausschließlich im COMPLETED-Zweig von
  `_finish_run()` — nur abgeschlossene Runs werden submittet,
  Fehlversuche ("Run Over") ändern den Bestwert nie. Gespeichert wird nur, wenn besser:
  höherer Score, bei Gleichstand mehr Coins → Result-Menü zeigt "New Highscore!" bzw. den
  bestehenden Bestwert. Hauptmenü zeigt "Best: Score X 🪙 Y" unter dem Titel.
- Für das spätere Web-Leaderboard ist `_submit_run()` der einzige Hook-Punkt.

## Save-System (SaveData.gd — Versionierung, Validierung & Backups)

Beide Saves (`user://highscore.cfg`, `user://progression.cfg`) laufen über die statischen
Helfer in `scripts/SaveData.gd` (getypte Reads, Versionierung, Backup/Recovery). Die
inhaltliche Normalisierung bleibt bewusst bei den Besitzern der Definitionen —
`Progression.gd` mit `QUEST_POOL`/`WEEKLY_POOL`/`SKIN_TIERS` als Source of Truth.

- **Schema-Versionen** (`[meta] version`): beide Dateien aktuell **v2**
  (`Progression.SAVE_VERSION`, `HighscoreStore.SAVE_VERSION`; Game exportiert nur einen
  Kompatibilitäts-Alias). Fehlt die `[meta]`-Sektion,
  gilt die Datei als **v1** = unversioniertes Original-Schema und bleibt dauerhaft ladbar
  (v1 und v2 haben identisches Feld-Layout, v2 ergänzt nur `[meta]` + Validierung beim Laden).
  Das v1→v2-Upgrade passiert beim ersten Laden (Normalisieren + Neuschreiben) und ist
  idempotent — wiederholte Load/Save-Zyklen ändern eine gültige Datei byte-genau nicht.
  Neuere Versionen als die unterstützte werden gewarnt und best-effort geladen.
- **Getypte Reads** (`SaveData.read_int/read_string/read_array`, `int_at`/`bool_at` für
  Array-Elemente): jedes Feld fällt bei falschem Typ einzeln auf seinen Default zurück
  (mit `push_warning`) — ein einzelnes kaputtes Feld resettet nie den restlichen Save.
  Numerische Felder (Keys, Fragmente, Shards, Zähler, Score, Coins) werden auf ≥ 0 geklemmt.
- **Normalisierung** (`Progression._normalize_state()`, Teil von `load_and_validate()`,
  das `_ready()` nach der Migration aufruft):
  - **Daily/Weekly-Quests**: unbekannte, doppelte und falsch getypte Quest-IDs werden
    entfernt; `progress`/`completed`/`claimed` werden exakt an `active_ids`/`weekly_ids`
    ausgerichtet (Slot-Daten wandern mit ihrer ID mit, Überzähliges gekappt auf
    `DAILY_SLOTS`/`WEEKLY_SLOTS`, Fehlendes gedefaultet). Invarianten: progress ∈ [0, target],
    completed folgt aus progress ≥ target, claimed nur wenn completed. Sind alle IDs
    ungültig, wird sicher neu gerollt (`daily_claims_today` bleibt dabei erhalten).
  - **Inventar**: unbekannte Skin-IDs raus, Duplikate dedupliziert, Starter-Skins garantiert
    (`_ensure_starter_skins()` läuft innerhalb von `_normalize_inventory()`, speichert nicht
    mehr selbst); ein nicht (mehr) besessener `equipped_skin` fällt auf den Default Knight
    (`""`) zurück. `best_pull` muss ein Tier aus `TIER_RANK` sein, sonst Reset auf `""`.
- **Backups & Recovery** (`SaveData.save_with_backup`/`load_with_backup`): vor jedem
  Überschreiben wird die bestehende Datei — sofern sie noch als ConfigFile parst — nach
  `<datei>.bak` kopiert. Ist der Haupt-Save beim Laden korrupt, wird das Backup geladen
  und der Haupt-Save daraus repariert (Self-Healing). Ohne lesbares Backup startet nur das
  betroffene System mit Defaults; der jeweils andere Save bleibt unberührt.
- **Fehlerverhalten**: `ConfigFile.save()`-Rückgabewerte werden geprüft; Fehlschläge
  (`_save()`/`save_with_backup()` → `false`) nur als `push_warning` — der Zustand im
  Speicher bleibt gültig, der nächste erfolgreiche Save holt alles nach. Der Spielstart
  wird nie blockiert (gleiche Philosophie wie SaveMigration.gd).
- **Highscore-Semantik unverändert**: höherer Score gewinnt, bei Gleichstand mehr Coins
  (`HighscoreStore.submit()`, aufgerufen über `Game._submit_run()`). Ein unbrauchbarer
  `score`-Wert gilt als "kein Highscore" (nächster
  beendeter Run überschreibt); ein kaputtes `coins`-Feld allein verwirft den Score nicht.
- **Tests**: `tests/test_save_system.gd` (79 Checks: frische Installation, gültiger
  v2-Save, v1-Upgrade, fehlende Felder, falsche Typen, negative Werte, unbekannte/doppelte
  Quest- und Skin-IDs, zu kurze/lange Arrays, equipped nicht besessen, Backup-Recovery,
  Schreibfehler, Idempotenz, Highscore-Vergleichssemantik). Ausführung, Isolation und
  Determinismus: siehe Abschnitt "Tests (headless)".

## Save-Migration (SaveMigration.gd)

Einmalige, automatische Übernahme alter Saves nach der Umbenennung "Cloude Game" →
"Goblins of Greenglen" (Godot leitet `user://` aus `config/name` ab, alte Saves lägen sonst
unauffindbar im alten `app_userdata`-Ordner).

- **Aufruf**: `SaveMigration.migrate_old_saves()` als erste Zeile in `Progression._ready()` —
  Progression ist Autoload und läuft vor Game.gd, die Migration passiert also garantiert vor
  dem Laden BEIDER Saves (`progression.cfg` und `highscore.cfg`).
- **Pfad-Ermittlung**: alter Ordner = Geschwister-Verzeichnis von `OS.get_user_data_dir()`
  (`.get_base_dir().path_join("Cloude Game")`) — kein hartkodierter absoluter Pfad,
  funktioniert auf macOS, Windows und Linux. Existiert der alte Ordner nicht (frische
  Installation, custom user dir), ist die Migration ein stiller No-Op.
- **Regeln**: existierende aktuelle Saves werden NIE überschrieben (das macht die Migration
  zugleich idempotent — kein Marker-File nötig); beide Dateien werden unabhängig migriert
  (eine kann fehlen/kaputt sein, ohne die andere zu blockieren); alte Dateien werden vor dem
  Kopieren validiert (ConfigFile parst + Kerntypen stimmen) und das Ziel nach dem Kopieren
  verifiziert (bei Fehlschlag wird das unbrauchbare Ziel entfernt, damit ein späterer Lauf
  erneut versuchen kann); die Quelle bleibt immer unangetastet (kein automatisches Löschen).
- **Fehlerverhalten**: nur `push_warning()` — der Spielstart wird nie blockiert.
- **Starter-Skins**: die Migration fasst Skins nicht an; `_ensure_starter_skins()` läuft
  danach und ist durch den `if id not in owned_skins`-Guard dedupliziert.

## Quests, Keys & Cases (Progression.gd)

Meta-Progression-Loop, unabhängig vom Coins/Score-System: Keys werden ausschließlich über Daily
Quests verdient (nicht mit Coins kaufbar, damit Cases nicht trivial grindbar sind). Persistiert in
`user://progression.cfg` (ConfigFile, gleiches Muster wie `highscore.cfg`), Sektionen `[meta]`
(Schema-Version), `[currency]`, `[quests]`, `[inventory]` — Laden/Validierung/Backup siehe
Abschnitt "Save-System".

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
  (`no_damage_goal`/`level_clear` pro Ziel), `_finish_run()` (`finish_run`/`no_damage_run`
  genau einmal pro ABGESCHLOSSENEM Run — Fehlversuche vergeben nichts, siehe
  Run-Result-System), `double_jumped`-Signal (in `_load_level()` verbunden).
  `took_damage_this_level` (pro Level) trackt den Schadenlos-Level-Quest,
  `took_damage_this_run` (pro Run, Reset im zentralen Clean-Run-Pfad `_start_new_run()`
  und in `_start_game()`) den schadenfreien Run-Weekly.
  Wichtig: Tod erzwingt Neustart ab Level 1, d.h. jeder *abgeschlossene* Run ist automatisch
  todlos — deshalb gibt es "Finish X runs" (Volumen) und "ohne Schaden" (Skill) statt "ohne Tod".
- **Claim**: Keys werden nicht automatisch vergeben — im Quests-Menü muss ein fertiger Quest
  per Button bestätigt werden (`Progression.claim_quest(slot)` / `claim_weekly(slot)`).
  Das Quests-Menü hat zwei Sektionen (Daily/Weekly) mit Statuszeile für Bonus-Modus/Fragmente.
- **Cases**: Regulär 1 Key (Tier-Gewichte 60/24/12/4), Premium 3 Keys (`PREMIUM_WEIGHTS` 55/30/15
  Rare/Epic/Legendary, keine Commons — "Skip-Commons"-Beschleuniger für Completion). Duplikate geben
  1 Shard (`dup_shards`, `SHARDS_PER_KEY` 10 = 1 Key, Auto-Konvertierung) — bewusst schwächer
  als Quest-Fragmente (3 = 1), damit Dupes Trostpreis bleiben. Kein Pity-System.
  Stats in Sektion `[stats]` (`cases_opened`, `best_pull` via `TIER_RANK`-Vergleich);
  Cases-Menü zeigt Shards, Collection X/Y, Opened-Count und Best Pull.
- **Reel-Animation**: CS:GO-Stil im Cases-Menü — `reel_strip` (40 Karten à 100px,
  Gewinner fest an `WIN_INDEX` 34, Rest zufällige Füller) scrollt per Tween
  (`TRANS_QUINT`/`EASE_OUT`, 2.8s) unter eine Gold-Markierung; Tick-SFX in `_process`
  bei Kartenwechsel; Buttons (beide Cases + Back) via `is_spinning` gesperrt.
  Karten-Art nutzt das gleiche Textur/Tint-Muster wie die Skins-Preview.
- **Reveal-Effekte pro Tier** (`CaseMenuController._spawn_skin_reveal()`, Tween-Muster wie POW):
  Common = Float-Label; Rare = + Farb-Flash (`TIER_COLORS`) + `level_clear`-SFX;
  Epic/Legendary = stärkerer Flash + Shake am `reel_frame` + `win`-SFX (Legendary am kräftigsten).
  Dupe-Label zeigt "+1 Shard" bzw. "+1 Key from Shards!" bei Konvertierung.
- **Tiers & Skins** (`SKIN_TIERS`, Gewichte regulär 60/24/12/4): **Common** (Bronze/Silber, reine
  `modulate`-Tints ohne Artwork), **Rare** (Gold/Emerald/Pink Knight), **Epic** (Blood/Black Knight),
  **Legendary** (4 Prinzessinnen: Golden/Emerald/Amethyst/Ruby — seltener als alle Ritter).
  Zusätzlich ein **`starter`-Tier mit weight 0** (nie aus Cases): die **Sapphire Princess**
  (`princess_blue`) ist über `STARTER_SKINS` von Anfang an besessen (neben dem Default-Ritter ohne
  Skin). `_ensure_starter_skins()` (Teil der Save-Normalisierung, siehe Save-System-Abschnitt)
  garantiert das auch für Alt-Saves. Premium-Case-
  Gewichte (`PREMIUM_WEIGHTS`) 55/30/15 Rare/Epic/Legendary (keine Commons/Starter).
- **Texture- vs. Tint-Skins**: Tint-Skins (Common) nur `Sprite2D.modulate` (funktioniert nur für
  Helligkeits-/Sättigungs-Verschiebungen der Basis-Palette). Alle anderen nutzen echtes Artwork
  (`texture`-Feld → `assets/sprite_knight_*.png` / `sprite_princess_*.png`), da Tinting bei neuen
  Farbtönen falsche Ergebnisse liefert. `Player.apply_skin(skin)` bekommt das komplette Skin-
  Dictionary, tauscht bei `texture` die Sprite-Textur (inkl. Neu-Skalierung, da die Dateien
  unterschiedliche Pixelmaße haben — Prinzessinnen sind z.B. schmaler/höher als Ritter), sonst nur
  `modulate`. Ausrüsten über `Progression.equip_skin(id)`, angewendet in `Game._load_level()` via
  `player.apply_skin(Progression.get_equipped_skin())` bei jedem Levelstart. Ohne ausgerüsteten Skin
  bleibt der Ritter unverändert (`Color.WHITE`, Default-Textur).
- **Default Knight (abwählbar)**: `Progression.get_default_skin()` liefert einen virtuellen Skin
  (id `""`, Basis-Ritter, Tier "default") — bewusst NICHT in `SKIN_TIERS`/`owned_skins`, also nie
  aus Cases ziehbar und nicht in der Collection-Zählung. `equip_skin("")` ist explizit erlaubt und
  persistiert `equipped_skin=""` (kanonischer "kein Skin"-Wert, alte Saves kompatibel). Das
  Skins-Menü listet ihn via `SkinMenuController.selectable_skins()` (Default + besessene) immer als ersten
  Eintrag, damit man nach dem Ausrüsten eines Skins zum Basis-Ritter zurückkehren kann.
- **Artwork-Anforderung**: Textur-Skins müssen **transparenten Hintergrund** haben. Einige
  gelieferte Sprites (Prinzessinnen, Black Knight) kamen als opakes RGB mit weißem Hintergrund und
  wurden per ImageMagick freigestellt (near-white → transparent via `-fuzz 12% -transparent white`,
  entfernt auch eingeschlossene Lücken zwischen Beinen/Arm/Körper). Bei neuen Skins vorab prüfen,
  dass der Hintergrund transparent ist, sonst erscheint im Spiel eine weiße Box.
- **Skins-Menü (Preview)**: Zwei-Spalten-Layout — links scrollbare Skin-Liste (Buttons, Text in
  Rarity-Farbe via `TIER_COLORS`, ausgewählter mit `▶`-Präfix), rechts Preview-Panel mit großem
  Sprite, Name, Rarity-Tier und `✓ Equipped`-Indikator. Klick auf einen Listeneintrag setzt nur
  `selected_skin_id` und aktualisiert die Preview (`_update_skin_preview()`); erst der separate
  Equip-Button ruft `Progression.equip_skin()`. Preview rendert Textur-Skins direkt, Tint-Skins als
  Basis-Ritter + `modulate` — gleiche Logik wie `Player.apply_skin()`. Default-Auswahl beim Öffnen:
  ausgerüsteter Skin, unbekannte/leere id fällt auf den Default Knight zurück.
- **UI**: 3 neue Hauptmenü-Buttons (Quests/Cases/Skins), Keys-Anzeige im HUD. Der Hauptmenü-VBox
  spannt die volle Viewport-Breite (`custom_minimum_size.x = VIEW.x`), Buttons zentriert via
  `SIZE_SHRINK_CENTER` — sonst würde das breite Titel-Label die Box-Breite aufblähen und Titel +
  Buttons aus der Mitte schieben. "Quit Game" ist bewusst nicht Teil der Button-Liste, sondern unten
  rechts fix verankert (`PRESET_BOTTOM_RIGHT` + `offset_*`), damit neue Menü-Buttons es nicht
  aus dem Fenster schieben.
- **Out of scope (bewusst)**: Gameplay-Perks (nur Skins in v1), Keys mit Coins kaufen,
  weitere Level für mehr Quest-Varianz — siehe Plan-Historie für Details.

## UI-Theme (Greenglen-Buttons + Cinzel-Typografie)

`GreenglenUI.build_theme_bundle()` baut in `Game._ready()` genau EIN `Theme`-Objekt plus
Heading-/Body-Font. Game injiziert dieselbe Instanz in `GameMenuController` und alle drei
Submenü-Controller; sämtliche Button-Kinder erben sie — kein wiederholtes Stylebox-Bauen
und kein zweites visuelles System pro Komponente.

- **Button-Texturen**: `assets/ui/buttons/button_greenglen_{normal,hover,pressed,disabled}.png`
  (900×150, transparent) als `StyleBoxTexture` pro Zustand; `focus` nutzt bewusst die
  Hover-Textur statt Godots Standard-Fokusrahmen. `GreenglenUI._make_button_style(state)` baut jede Stylebox:
  - die komplette Textur wird ohne `region_rect`-Zuschnitt und ohne Nine-Patch-Randaufteilung
    gerendert; dadurch bleiben Metall-Enden, Gems, Holz und Vine-Ranken vollständig erhalten,
  - `GreenglenUI.configure_button(button, height)` erzwingt überall das originale Seitenverhältnis
    6:1 (z.B. 192×32 Claims, 240×40 Standard, 300×50 Cases) und horizontale Textzentrierung,
    damit Textur und Ausrichtung nicht zwischen Menüs abweichen,
  - `content_margin_left/right = 32` hält alle Texte innerhalb der Holzfläche und fern von Gems/Vines;
    identische obere/untere Content-Margins halten Godots Textlayout vertikal zentriert, lange
    Labels nutzen weiterhin gezielte kleinere Font-Größen.
- **Typografie**: `Cinzel-SemiBold.ttf` für Buttons (18px, `UI_CREAM` = `#FFF1C4`, Outline
  `UI_BROWN` = `#351D0E`, Größe 3), `Cinzel-Bold.ttf` für Menü-Überschriften via
  `GreenglenUI.apply_heading_style()` (Outline-Größe 5). Beide Fonts aus `res://Cinzel/static/`
  (SIL-OFL-lizenziert, nicht umbenennen/duplizieren). Cinzel deckt keine Emoji/Sonderzeichen ab
  (🔑 🪙 ▶ ★) — `FontFile.fallbacks = [ThemeDB.fallback_font]` wird auf beide Fonts gesetzt.
  Einzelne besonders lange Labels (z.B. "Premium Case (3 🔑) — Rare+", "Quit Game") bekommen
  einen kleineren `font_size`-Override, damit sie zwischen die Metall-Enden passen.
- **Logo & Icon**: Hauptmenü zeigt `assets/LOGO_menu_GoGg.png` (TextureRect, seitenverhältnis-
  erhaltend, 180px hoch) statt eines Text-Titels; `assets/menubackground.png` bleibt der
  Hintergrund darunter. `assets/icon_GoGg.png` (1024×1024) ist via `config/icon` in
  `project.godot` das Fenster-/Dock-Icon und wird im macOS-Export-Preset als App-Icon verwendet
  (`export_presets.cfg` ist gitignored).
- **Result-Menü**: `GameMenuController` erzeugt einen eigenen `CanvasLayer` (layer 8) mit
  abgedunkeltem, weiterhin sichtbarem Level, zentriertem Container-Layout, outcome-abhängigem
  Titel ("Run Complete" Gold / "Run Over" warmer Akzent), Final Score, Coins, Bestwert und
  stabiler optionaler Highscore-Zeile — Details siehe Abschnitt "Run-Result-System".
  Seine Buttons emittieren nur `restart_requested`/`main_menu_requested`; Game routet diese
  in `_start_new_run()` bzw. `_show_main_menu()`. `_load_level()` blendet Result über
  `menus.hide_result()` aus und den HUD über `hud.show_gameplay()` ein.
  `run_result_menu.process_mode = PROCESS_MODE_ALWAYS` hält die Buttons bedienbar, obwohl
  `level_root` deaktiviert ist. `HUDController.message_label` bleibt nur für "Level Cleared!".

## Tests (headless, deterministisch, isoliert)

Eigenes dependency-freies GDScript-Harness (kein GUT, kein C#). DER eine Befehl für die
komplette Suite (Godot 4.6):

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_all.gd
```

Exit-Code `0` = alle Suiten grün UND Canary unverändert; jeder Fehlschlag liefert `1`.
Die Suiten sind auch einzeln lauffähig (`-s res://tests/test_save_system.gd` bzw.
`test_smoke.gd`) und isolieren sich dann selbst. WARNING-Zeilen im Output sind erwartet
(die Save-Tests füttern absichtlich kaputte Saves).

- **Suiten (231 Checks gesamt)**: `test_save_system.gd` (79, Save-System inkl. direktem
  `HighscoreStore`-Test) und `test_smoke.gd` (152: Main-Komponenten/Interfaces,
  einmalige Signalverbindungen, eindeutige CanvasLayer-Ownership und gemeinsame Theme-Instanz,
  Quest-/Case-/Skin-Menü-Intents inkl. komplettem Case-Spin und Skin-Equip/-Anwendung,
  Player-Szene inkl. Signale, Input-Actions, Audio- und
  Skin-Ressourcen, Case-Gewichtssummen, Quest-/Skin-ID-Eindeutigkeit, alle 6 Level
  (PlayerSpawn/Platforms/level_width/Goal), Level-6-Randomisierung (Anzahlen, Platzierung
  nur auf `spawn_platforms`, Start-/Ziel-Plattform unmarkiert), Run-Result-Lifecycle
  (beide Ausgänge, Genau-einmal-Garantie, Highscore-Policy, Escape-/R-Verhalten,
  Clean-Run-Resets) und Transition-Cancellation (normal, Restart, Menü-Exit, Run-Ende)).
- **Isolation (verifiziert)**: Jede Suite setzt in `_init()` — also VOR der Autoload-
  Registrierung (Autoloads starten im `-s`-Modus nach `_init`, vor dem ersten Frame) —
  `GOGG_TEST_SAVE_DIR` (siehe `SaveData.test_save_dir()` und `tests/test_env.gd`) auf ein
  frisches Temp-Verzeichnis. Dadurch leiten auch das mitbootende Progression-Autoload und
  Progression und `HighscoreStore` ihre Save-Pfade dorthin um und die Save-Migration wird
  übersprungen — echte
  Saves unter `user://` werden weder gelesen noch geschrieben. Der Runner gibt jeder
  Suite ein eigenes Unterverzeichnis und BEWEIST die Isolation per Canary: MD5-Hashes
  von `highscore.cfg`/`progression.cfg` (+ `.bak`) vor und nach dem Lauf; jede Änderung
  schlägt den Lauf fehl. Temp-Verzeichnisse werden bei Erfolg entfernt, bei Fehlschlag
  zur Analyse belassen. Ohne die Env-Variable ist das Produktionsverhalten unverändert.
- **Determinismus**: Zufall geseedet (Quest-Rolls, Level-6-Spawns via `seed()`); Warte-
  Assertions nutzen großzügige Zeitmargen statt Frame-Zählungen. Zwei aufeinanderfolgende
  Läufe liefern identische Ergebnisse; ein absichtlich fehlschlagender Check liefert
  nachweislich Exit `1`. `run_all.gd` verlangt zusätzlich den Erfolgsmarker jeder Suite,
  weil Godot bei einem frühen Script-Parsefehler gelegentlich trotzdem Exit 0 liefert.
- **Wichtig für neue Tests**: Game.gd referenziert das Autoload `Progression` und
  kompiliert im `-s`-Modus erst nach der Autoload-Registrierung — Game.gd daher nie
  `preload`en, sondern zur Laufzeit (nach dem ersten Frame) laden bzw. über Main.tscn
  instanziieren. `Progression.save_path` und `HighscoreStore.save_path` bleiben zusätzlich
  pro Instanz übersteuerbar.

## Viewport

960×540 intern, Fenster 1280×720 (canvas_items stretch).
