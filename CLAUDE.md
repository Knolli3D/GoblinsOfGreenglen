# Cloude Game

Ein 2D-Platformer in Godot 4.6, handgeschrieben in GDScript. Kein C#.

## Spielprinzip

Ritter springt durch 3 Level, besiegt Goblins per Stomp und erreicht das rote Ziel-Flag.
- 3 Herzen (Health), Score +1 pro Kill, -1 pro Treffer/Fall
- Coins sammelbar (+1 pro Coin), werden im Win-Screen angezeigt
- Nach 3 Leveln: Gewinn-Screen mit Final Score + Coin-Count
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
  Game.gd       # Haupt-Controller: HUD, Menüs, Level laden, POW!-Effekt
  Player.gd     # CharacterBody2D: Bewegung, Double-Jump, Stomp, Signals
  Enemy.gd      # CharacterBody2D: Patrol (@export patrol_range), Kill-Logik
  Coin.gd       # Area2D: Coin-Pickup, ruft game.coin_collected()
  Goal.gd       # Area2D: add_to_group("goals"), _draw() Flag-Visual
  Platform.gd   # StaticBody2D: Sprite-Scale aus CollisionShape-Größe
  Level.gd      # Node2D Basis: _draw() Himmel + Berge Hintergrund

scenes/
  Main.tscn         # Einstieg → lädt Game.gd
  Player.tscn       # CharacterBody2D + CollisionShape2D + Sprite2D
  Enemy.tscn        # CharacterBody2D + CollisionShape2D + Sprite2D
  Coin.tscn         # Area2D + CircleShape2D
  Goal.tscn         # Area2D + RectangleShape2D
  Platform.tscn     # StaticBody2D + CollisionShape2D (Template)
  Level1-3.tscn     # Visuelle Level (editierbar im 2D-Editor!)

assets/
  sprite_knight.png   # Ritter-Sprite (788×1674, transparent)
  sprite_goblin.png   # Goblin-Sprite (923×1318, transparent)
  sprite_platform.png # Plattform-Textur (4128×496)
  sky.png             # Himmel-Hintergrund (Parallax)
  knight.png / goblin.png / platform.png  # Original-Uploads (Backup)
```

## Architektur

- **Level als .tscn-Dateien** → im Godot 2D-Editor visuell editierbar
- **Game.gd** ist der zentrale Controller; lädt Level-Scenes via `load(LEVELS[idx]).instantiate()`
- **Player** wird von Game.gd per `find_child("PlayerSpawn")` im Level platziert
- **Kommunikation per Signals** (nicht get_parent().get_parent()):
  - `Player` emittiert: `stomped_enemy`, `hit_enemy`, `fell_off`, `reached_goal`
  - `Coin` ruft `game.coin_collected()` via `get_tree().get_first_node_in_group("game")`
- **Game.gd** ist in Gruppe `"game"`, Player in `"player"`, Enemies in `"enemies"`, Goals in `"goals"`

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

Level-Szenen (`scenes/Level1-3.tscn`) im Godot-Editor öffnen:
- **Plattform verschieben**: Node in Scene-Tree auswählen → Drag im 2D-View
- **Plattform-Größe**: `CollisionShape2D` auswählen → Inspector → `Shape → Size`
- **Gegner-Patrol**: Enemy-Instanz auswählen → Inspector → `Patrol Range`
- **Neuer Gegner**: `Enemy.tscn` aus FileSystem in Level-Scene ziehen
- **Neue Coin**: `Coin.tscn` aus FileSystem in Level-Scene ziehen
- **PlayerSpawn**: `Marker2D` namens `PlayerSpawn` im Level bewegen

## Sprite-Skalierung

Sprites werden in `_ready()` der jeweiligen Scripts skaliert (kein White-Keying nötig — Sprites sind bereits transparent):
- Knight: Ziel-Höhe 52px → `scale = 52 / 1674`
- Goblin: Ziel-Höhe 40px → `scale = 40 / 1318`
- Platform: Breite/Höhe aus CollisionShape2D-Größe berechnet

## POW!-Effekt

`Game.gd._spawn_pow(pos)` erstellt einen animierten `Label`-Node auf einem temporären `CanvasLayer` (layer=20), der hochschwebt und ausfadet.

## Viewport

960×540 intern, Fenster 1280×720 (canvas_items stretch). Kein Audio implementiert.
