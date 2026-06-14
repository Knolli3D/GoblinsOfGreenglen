# Cloude Game

A 2D side-scrolling platformer built with **Godot 4.6** and pure **GDScript**. Play as a knight, stomp goblins, collect coins, and reach the red flag across 5 increasingly challenging levels — including two horizontally scrolling stages.

---

## Gameplay

- **5 levels** of increasing difficulty, ending with wide scrolling stages
- **Stomp enemies** (jump on top of a Goblin) to earn score points
- **Collect coins** scattered across each level
- **Reach the red flag** to advance to the next level
- **3 hearts** of health — taking damage or falling off the world costs a heart and reduces your score
- **Win screen** shows your final score and total coins collected after Level 5

---

## Controls

| Action | Keys |
|---|---|
| Move left / right | Arrow keys or `A` / `D` |
| Jump | `Space` or `Arrow Up` |
| Double jump | Press `Space` / `Arrow Up` again in mid-air |
| Pause | `Escape` |
| Restart / Retry | `R` |

---

## Screenshots

> *(Add screenshots of gameplay here)*

---

## Requirements

- [Godot Engine 4.6](https://godotengine.org/download) (standard build, no .NET required)

---

## How to Run

1. Clone this repository:
   ```bash
   git clone https://github.com/Knolli3D/cloude-game.git
   ```
2. Open Godot 4.6 and choose **Import Project**
3. Select the `project.godot` file in the cloned folder
4. Press **F5** (Run Project) or click the Play button

No external plugins or dependencies required.

---

## Project Structure

```
cloude-game/
├── scripts/
│   ├── Game.gd       # Main controller: HUD, menus, level loading, POW! effect
│   ├── Player.gd     # CharacterBody2D: movement, double-jump, stomp, signals
│   ├── Enemy.gd      # CharacterBody2D: patrol AI, kill logic
│   ├── Coin.gd       # Area2D: coin pickup
│   ├── Goal.gd       # Area2D: level exit flag
│   ├── Platform.gd   # StaticBody2D: sprite scaling from collision shape
│   └── Level.gd      # Node2D base: sky + mountain background drawing
├── scenes/
│   ├── Main.tscn     # Entry point
│   ├── Player.tscn
│   ├── Enemy.tscn
│   ├── Coin.tscn
│   ├── Goal.tscn
│   ├── Platform.tscn
│   ├── Level1.tscn   # Intro level
│   ├── Level2.tscn   # Medium difficulty
│   ├── Level3.tscn   # Harder layout
│   ├── Level4.tscn   # Horizontal scrolling (1920 px wide)
│   └── Level5.tscn   # Wide scrolling finale (2560 px wide)
└── assets/
    ├── sprite_knight.png
    ├── sprite_goblin.png
    ├── sprite_platform.png
    └── sky.png
```

---

## Architecture

The game uses a **signal-based, scene-driven** architecture with no singletons:

- **`Game.gd`** is the central controller added to the `"game"` group. It loads level scenes dynamically, spawns the player at the `PlayerSpawn` marker, and handles all game state (health, score, coins, transitions).
- **`Player.gd`** communicates exclusively via signals (`stomped_enemy`, `hit_enemy`, `fell_off`, `reached_goal`) — never by calling parent nodes directly.
- **`Coin.gd`** finds the game controller via `get_tree().get_first_node_in_group("game")`.
- **Levels** are `.tscn` files edited visually in the Godot 2D editor. Enemy patrol range and spawn positions are set as exported properties in the Inspector.
- A **`Camera2D`** is attached to the player at runtime with per-level `limit_right` to enable scrolling in Levels 4 and 5.

### Collision Layers

| Layer | Name   | Used by |
|-------|--------|---------|
| 1 | world  | Platforms (StaticBody2D) |
| 2 | player | Player (CharacterBody2D) |
| 3 | enemy  | Enemies (CharacterBody2D) |
| 4 | goal   | Goal area (Area2D, mask = 2) |

### Physics Constants

| Constant | Value |
|---|---|
| Gravity | 1400 px/s² |
| Move speed | 220 px/s |
| Jump velocity | −520 px/s |
| Double-jump velocity | −460 px/s |
| Enemy patrol speed | 60 px/s |

---

## Viewport

- **Internal resolution:** 960 × 540
- **Window size:** 1280 × 720
- **Stretch mode:** `canvas_items`

---

## Features at a Glance

| Feature | Details |
|---|---|
| Health system | 3 hearts; damage from enemies and falls |
| Score | +1 per goblin stomped, −1 per hit or fall |
| Coins | Persistent across levels, shown on win screen |
| Double jump | Full second jump with slightly lower velocity |
| Invincibility frames | 1 second after taking damage |
| POW! effect | Animated label that floats and fades on stomp |
| Pause menu | Resume, Try Again, Exit to Menu |
| Win & death screens | Inline HUD messages; `R` to restart |
| Scrolling levels | Camera clamps to `level_width` per level |

---

## Level Design (editing)

Open any `scenes/Level*.tscn` in the Godot 2D editor:

- **Move a platform:** select the node in the Scene tree → drag in the 2D viewport
- **Resize a platform:** select `CollisionShape2D` → Inspector → `Shape → Size`
- **Enemy patrol range:** select Enemy instance → Inspector → `Patrol Range`
- **Add enemies / coins:** drag `Enemy.tscn` or `Coin.tscn` from FileSystem into the level scene
- **Change spawn point:** move the `PlayerSpawn` (Marker2D) node

---

## License

This project is released for educational and personal use. All sprite assets were created for this project.
