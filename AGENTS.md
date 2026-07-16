# Goblins of Greenglen

Ein 2D-Platformer in Godot 4.6, handgeschrieben in GDScript. Kein C#.
(Repo/Ordner heißt weiterhin `cloude-game`; "Goblins of Greenglen" ist nur der In-Game-Anzeigename
via `config/name` in `project.godot`. Achtung: `config/name` bestimmt auch den `user://`-Save-Pfad —
alte Saves aus `app_userdata/Cloude Game` werden von `scripts/SaveMigration.gd` automatisch
übernommen, siehe Abschnitt "Save-Migration".)

**Status:** Spiel läuft einwandfrei durch (alle Level, Combat, Coins, Win/Death-Flow). Der generierte Chiptune-Sound ist witzig und rundet das Ganze gut ab.

## Spielprinzip

Ritter springt durch 6 Level (Level 4+5 mit horizontalem Scrolling, Level 6 mit zufälliger
Gegner-/Coin-Platzierung), besiegt Goblins per Stomp und erreicht das rote Ziel-Flag.
- 3 Herzen (Health), Score +1 pro Kill, -1 pro Treffer/Fall
- Stomp zählt nur beim Abwärtsflug und beim Überqueren der Goblin-Oberkante von oben;
  Aufwärts- und Seitenkontakt verursachen Schaden
- 1s Invulnerability nach Treffer/Fall-Respawn (`invuln_until`); wird in `_load_level()` und
  im Hauptmenü auf 0.0 zurückgesetzt — bewusst keine Spawn-Protection beim Levelstart
  (PlayerSpawn liegt überall abseits der Gegner)
- Coins sammelbar (+1 pro Coin), werden im Win-Screen angezeigt
- Nach 6 Leveln: eigener Greenglen-Gewinn-Screen mit Score, Coins, Bestwert, optionalem
  "New Highscore!", "Play Again" und "Main Menu"; `R` startet ebenfalls neu
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
  Game.gd         # Haupt-Controller: HUD, Menüs inkl. Win-Screen, Level laden, POW!, Meta-UI
  Progression.gd  # Autoload-Singleton: Daily Quests, Keys-Währung, Case-Opening, Skin-Inventory
  Player.gd       # CharacterBody2D: Bewegung, Double-Jump, Swept-Stomp-Test, Signals, apply_skin()
  Enemy.gd        # CharacterBody2D: Patrol, vorherige Globalposition, Kill-Logik
  Coin.gd         # Area2D: Coin-Pickup, ruft game.coin_collected()
  Goal.gd         # Area2D: add_to_group("goals"), _draw() Flag-Visual
  Platform.gd     # StaticBody2D: Sprite-Scale aus CollisionShape-Größe
  Level.gd        # Node2D Basis: Parallax-Hintergrund (mit _draw()-Fallback), optionales randomize_level_spawns()
  SaveMigration.gd # Statischer Helper: einmalige Save-Übernahme aus "Cloude Game" (siehe Save-Migration)

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

default_bus_layout.tres  # Audio-Busse: Master → Music (-6 dB), SFX
```

## Architektur

- **Level als .tscn-Dateien** → im Godot 2D-Editor visuell editierbar
- **Game.gd** ist der zentrale Controller; lädt Level-Scenes via `load(LEVELS[idx]).instantiate()`
- **Player** wird von Game.gd per `find_child("PlayerSpawn")` im Level platziert
- **Kommunikation per Signals** (nicht get_parent().get_parent()):
  - `Player` emittiert: `stomped_enemy`, `hit_enemy`, `fell_off`, `reached_goal`, `jumped`, `double_jumped`
  - `Coin` ruft `game.coin_collected()` via `get_tree().get_first_node_in_group("game")`
- **Kampf bleibt signalbasiert und ohne Player/Enemy-Physikkollision**: `Player.gd` klassifiziert
  Kontakte anhand der Rechteck-Collider und emittiert weiterhin nur `stomped_enemy` oder `hit_enemy`.
  `Game._on_player_stomped_enemy()` prüft vor Kill/Score/SFX/Quest/POW nochmals `is_enemy()`, damit
  ein veraltetes oder doppeltes Signal niemals mehrfach belohnt wird.
- **Game.gd** ist in Gruppe `"game"`, Player in `"player"`, Enemies in `"enemies"`, Goals in `"goals"`
- **Progression.gd** ist der einzige Autoload/Singleton im Projekt (Ausnahme vom Group-Lookup-Pattern,
  da Meta-Progression session-übergreifend und auch im Hauptmenü ohne geladenes Level lesbar sein muss)
- **Level-Übergänge (Race-Schutz)**: `reach_goal()` wartet 1s ("Level Cleared!", Timer pausiert
  mit dem Spiel) und validiert danach gegen das Generation-Token `transition_gen`, das von
  `_load_level()` und `_show_main_menu()` erhöht wird — veraltete Übergangs-Coroutinen nach
  Restart/Menü laden nichts mehr. Neue Code-Pfade, die Level wechseln oder ins Menü führen,
  müssen durch eine dieser beiden Funktionen laufen (oder das Token selbst erhöhen)

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

`Game.gd._spawn_pow(pos)` erstellt einen animierten `Label`-Node auf einem temporären `CanvasLayer` (layer=20), der hochschwebt und ausfadet.

## Audio

Alle Sounds sind generierte Chiptune-WAVs (`python3 tools/generate_audio.py` → `assets/audio/`).
- **Busse** (`default_bus_layout.tres`): `Master` → `Music` (-6 dB), `SFX`
- **Game.gd** besitzt alle Audio-Nodes: 1× `AudioStreamPlayer` für Musik (Bus Music),
  8 Round-Robin-Voices für SFX (Bus SFX). `play_sfx(name, pitch_jitter)` spielt aus `SFX_FILES`;
  `pitch_jitter` variiert `pitch_scale` leicht gegen Monotonie (Coin, Stomp, Jump).
- **Musik**: `music.wav` loopt via `AudioStreamWAV.LOOP_FORWARD` (loop_end aus `get_length() × mix_rate`
  berechnet, da der Import QOA-komprimiert). Start bei Spielstart, Stop bei Tod/Win/Hauptmenü.
- **Jump-Sounds**: Player emittiert `jumped`/`double_jumped`, Game.gd verbindet sie in `_load_level()`.
- Events: jump, double_jump, coin, stomp, hit, death, level_clear, win, click (UI-Buttons).
- **Musik-Lautstärke (zentralisiert)**: einziger Schreibzugriff auf `music_player.volume_db`
  ist `_set_music_ducked(bool)`, gesteuert über `MUSIC_NORMAL_DB` (0 dB) / `MUSIC_PAUSED_DB`
  (-14 dB) — beide Werte addieren sich auf den Music-Bus (-6 dB), Ducking ergibt also -20 dB
  Gesamtausgang. `_toggle_pause()`, `_restart_level_from_menu()`, `_start_game()` und
  `_show_main_menu()` rufen alle `_set_music_ducked(false)`/`(true)` auf — verhindert, dass
  "Exit to Menu" während der Pause den gedämpften Pegel in den nächsten Run durchreicht
  (ehemaliger Bug: `_show_main_menu()` stoppte die Musik, setzte aber nie den Pegel zurück).

## Highscore (lokal)

Bester abgeschlossener Run wird in `user://highscore.cfg` gespeichert (ConfigFile, Sektion
`[highscore]` mit `score` + `coins`). Nur lokal — kein Online-Leaderboard (geplant: später via Website).
- **Game.gd**: `_load_highscore()` in `_ready()`, `_submit_run(score, coins)` beim Win-Screen
  (speichert nur, wenn besser: höherer Score, bei Gleichstand mehr Coins) → zeigt "New Highscore!"
  bzw. den bestehenden Bestwert an. Hauptmenü zeigt "Best: Score X 🪙 Y" unter dem Titel.
- Für das spätere Web-Leaderboard ist `_submit_run()` der einzige Hook-Punkt.

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
- **Reveal-Effekte pro Tier** (`Game._spawn_skin_reveal()`, Tween-Muster wie `_spawn_pow()`):
  Common = Float-Label; Rare = + Farb-Flash (`TIER_COLORS`) + `level_clear`-SFX;
  Epic/Legendary = stärkerer Flash + Shake am `reel_frame` + `win`-SFX (Legendary am kräftigsten).
  Dupe-Label zeigt "+1 Shard" bzw. "+1 Key from Shards!" bei Konvertierung.
- **Tiers & Skins** (`SKIN_TIERS`, Gewichte regulär 60/24/12/4): **Common** (Bronze/Silber, reine
  `modulate`-Tints ohne Artwork), **Rare** (Gold/Emerald/Pink Knight), **Epic** (Blood/Black Knight),
  **Legendary** (4 Prinzessinnen: Golden/Emerald/Amethyst/Ruby — seltener als alle Ritter).
  Zusätzlich ein **`starter`-Tier mit weight 0** (nie aus Cases): die **Sapphire Princess**
  (`princess_blue`) ist über `STARTER_SKINS` von Anfang an besessen (neben dem Default-Ritter ohne
  Skin). `_ensure_starter_skins()` in `_ready()` garantiert das auch für Alt-Saves. Premium-Case-
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
  Skins-Menü listet ihn via `Game._selectable_skins()` (Default + besessene) immer als ersten
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

Ein einziges `Theme`-Objekt (`ui_theme`, gebaut von `_build_ui_theme()` in `_ready()`) wird auf
alle Menü-Root-Controls gesetzt (Hauptmenü, Pause, Win, Quests/Cases/Skins) und vererbt sich auf
sämtliche Button-Kinder — kein wiederholtes Stylebox-Bauen pro Button nötig.

- **Button-Texturen**: `assets/ui/buttons/button_greenglen_{normal,hover,pressed,disabled}.png`
  (900×150, transparent) als `StyleBoxTexture` pro Zustand; `focus` nutzt bewusst die
  Hover-Textur statt Godots Standard-Fokusrahmen. `_make_button_style(state)` baut jede Stylebox:
  - `texture_margin_left/right = 85` (dekorierte Metall-Enden mit Vine-Ranken bleiben fix),
  - `texture_margin_top/bottom = 10` — **bewusst klein**, da Buttons nur 32–48px hoch sind;
    zu große vertikale Margins lassen die Holz-Mitte kollabieren (behobener Bug: 30+30=60px
    > Button-Höhe → nur Rahmen sichtbar, kein Holz), siehe Commit-Historie.
  - `axis_stretch_horizontal/vertical = AXIS_STRETCH_MODE_STRETCH` (Nine-Patch),
  - `content_margin_left/right = 64` hält Text von Gems/Vines fern, mittig auf dem Holz.
- **Typografie**: `Cinzel-SemiBold.ttf` für Buttons (18px, `UI_CREAM` = `#FFF1C4`, Outline
  `UI_BROWN` = `#351D0E`, Größe 3), `Cinzel-Bold.ttf` für Menü-Überschriften via
  `_apply_heading_style(label, size)` (Outline-Größe 5). Beide Fonts aus `res://Cinzel/static/`
  (SIL-OFL-lizenziert, nicht umbenennen/duplizieren). Cinzel deckt keine Emoji/Sonderzeichen ab
  (🔑 🪙 ▶ ★) — `FontFile.fallbacks = [ThemeDB.fallback_font]` wird auf beide Fonts gesetzt.
  Einzelne besonders lange Labels (z.B. "Premium Case (3 🔑) — Rare+", "Quit Game") bekommen
  einen kleineren `font_size`-Override, damit sie zwischen die Metall-Enden passen.
- **Logo & Icon**: Hauptmenü zeigt `assets/LOGO_menu_GoGg.png` (TextureRect, seitenverhältnis-
  erhaltend, 180px hoch) statt eines Text-Titels; `assets/menubackground.png` bleibt der
  Hintergrund darunter. `assets/icon_GoGg.png` (1024×1024) ist via `config/icon` in
  `project.godot` das Fenster-/Dock-Icon und wird im macOS-Export-Preset als App-Icon verwendet
  (`export_presets.cfg` ist gitignored).
- **Gewinn-Screen**: `_build_win_menu()` erzeugt einen eigenen `CanvasLayer` (layer 8) mit
  abgedunkeltem, weiterhin sichtbarem Level, zentriertem Container-Layout, Final Score, Coins,
  Bestwert und stabiler optionaler Highscore-Zeile. "Play Again" nutzt
  `_restart_level_from_menu()`/`_load_level(0)`, "Main Menu" nutzt `_show_main_menu()`;
  `_load_level()` blendet den Win-Screen zentral aus und stellt den Gameplay-HUD wieder her.
  `win_menu.process_mode = PROCESS_MODE_ALWAYS` hält die Buttons bedienbar, obwohl das fertige
  `level_root` deaktiviert ist. Der alte `win_label` bleibt nur für Level-Clear-/Death-Meldungen.

## Viewport

960×540 intern, Fenster 1280×720 (canvas_items stretch).
