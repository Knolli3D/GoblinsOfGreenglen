# Goblins of Greenglen

> Repo/folder name remains `cloude-game`; "Goblins of Greenglen" is the in-game display name.

A 2D side-scrolling platformer built with **Godot 4.6** and pure **GDScript**. Play as a knight, stomp goblins, collect coins, and reach the red flag across 6 increasingly challenging levels — including two horizontally scrolling stages and a final level with randomized enemy/coin placement.

**Status:** Fully playable end to end — all 6 levels, combat, coins, and win/death flow work as intended. The generated chiptune soundtrack and SFX add a fun, goofy charm to the whole thing.

---

## Gameplay

- **6 levels** of increasing difficulty — Levels 4–5 scroll horizontally, Level 6 randomizes enemy/coin placement on every playthrough
- **Stomp enemies** by landing clearly on top while descending; upward and side contacts deal damage
- **Collect coins** scattered across each level
- **Reach the red flag** to advance to the next level
- **3 hearts** of health — taking damage or falling off the world costs a heart and reduces your score
- **Greenglen win menu** shows score, coins, best run, and new-record status after Level 6, with Play Again and Main Menu buttons

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

### Main Menu

![Goblins of Greenglen main menu](assets/screenshots/main-menu.png)

### Gameplay

![Goblins of Greenglen platforming gameplay](assets/screenshots/gameplay.png)

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
│   ├── Game.gd          # Main controller: HUD, menus including results, level loading, POW!, meta UI
│   ├── Progression.gd   # Autoload singleton: daily/weekly quests, keys, case opening, skin inventory
│   ├── Player.gd        # CharacterBody2D: movement, double-jump, swept stomp detection, signals, skins
│   ├── Enemy.gd         # CharacterBody2D: patrol AI, previous position tracking, kill logic
│   ├── Coin.gd          # Area2D: coin pickup
│   ├── Goal.gd          # Area2D: level exit flag
│   ├── Platform.gd      # StaticBody2D: sprite scaling from collision shape
│   ├── Level.gd         # Node2D base: parallax background, optional randomized spawns
│   └── SaveMigration.gd # One-time save migration from the pre-rename "Cloude Game" user dir
├── scenes/
│   ├── Main.tscn       # Entry point
│   ├── Player.tscn / Enemy.tscn / Coin.tscn / Goal.tscn / Platform.tscn
│   ├── Level1–3.tscn   # Hand-placed levels
│   ├── Level4.tscn     # Horizontal scrolling (1920 px wide)
│   ├── Level5.tscn     # Wide scrolling (2560 px wide)
│   └── Level6.tscn     # Finale: randomized enemy/coin spawns each play
├── assets/
│   ├── sprite_knight.png / sprite_goblin.png / sprite_platform.png
│   ├── sprite_knight_*.png     # Skin art: gold, emerald, pink, blood, black
│   ├── sprite_princess_*.png   # Legendary skin art: blue (starter), gold, green, purple, red
│   ├── level_bg.png / level_bg_near.png   # Level parallax background art
│   ├── menubackground.png / menu_bg_quests.png / menu_bg_cases.png / menu_bg_skins.png  # Menu backgrounds
│   ├── LOGO_menu_GoGg.png / icon_GoGg.png  # Main-menu logo and app/window icon
│   ├── ui/buttons/button_greenglen_*.png   # Nine-patch button art (normal/hover/pressed/disabled)
│   ├── screenshots/              # Main-menu and gameplay images used in this README
│   └── audio/                  # Generated chiptune SFX + looping music
└── Cinzel/              # Cinzel font family (SIL OFL) used for all UI text
```

> Skin sprites (`sprite_knight_*`, `sprite_princess_*`) must have transparent backgrounds; sprites delivered with a white background are cut out before use, or they show as a white box in-game.

---

## Architecture

The game uses a **signal-based, scene-driven** architecture, mostly avoiding singletons:

- **`Game.gd`** is the central controller added to the `"game"` group. It loads level scenes dynamically, spawns the player at the `PlayerSpawn` marker, and handles all game state (health, score, coins, transitions).
- **`Player.gd`** communicates exclusively via signals (`stomped_enemy`, `hit_enemy`, `fell_off`, `reached_goal`) — never by calling parent nodes directly. Combat remains lightweight and manual: rectangle colliders classify contact without adding physical Player/Enemy collision.
- **`Coin.gd`** finds the game controller via `get_tree().get_first_node_in_group("game")`.
- **`Progression.gd`** is the project's one deliberate autoload/singleton — meta-progression (quests, keys, cases, skins) needs to persist across level loads and be readable from the main menu, where the group-lookup pattern doesn't apply.
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
| Stomp top tolerance | 2 px |
| Minimum stomp overlap | 4 px |

### Stomp Classification

Before each `move_and_slide()`, the player records its previous global position and whether it was descending. A stomp requires the player's feet to cross the moving enemy's top surface from above while at least 4 px of the real rectangle colliders overlap horizontally. Enemy previous positions allow the crossing point to be interpolated even while both actors move. Other swept contacts — upward, sideways, or too close to the edge — emit `hit_enemy`; dead enemies are ignored. This also prevents tunneling through combat contacts at coarse physics timesteps while preserving the existing bounce and signal interface.

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
| Invincibility frames | 1 second after taking damage or a non-fatal fall; never carries over into a new level, restart, or run |
| POW! effect | Animated label that floats and fades on stomp |
| Pause menu | Resume, Try Again, Exit to Menu |
| Win & death screens | Dedicated themed results menu with Play Again/Main Menu; compact death message; `R` retries |
| Scrolling levels | Camera clamps to `level_width` per level |

---

## Audio

All music and sound effects are generated chiptune WAVs (`tools/generate_audio.py`), routed through two audio buses (`Master → Music`, `SFX`). A looping background track plays during gameplay, with round-robin SFX voices for jump, double-jump, coin pickup, stomp, hit, death, level clear, and win — pitch-jittered slightly so they don't feel repetitive. Music ducks during the pause menu and consistently restores to normal volume on resume, restart, or exiting to the main menu.

## Highscore

Your best completed run (score + coins) is saved locally to `user://highscore.cfg` — no online leaderboard yet. Beat your previous best and the win menu shows "New Highscore!"; the main menu displays your current best under the title. If you have a save from before the game was renamed from "Cloude Game," it's picked up automatically the first time you launch — nothing to do on your end.

---

## Look & Feel

The UI uses hand-painted **Greenglen** button art (ornate wood-and-metal nine-patch textures with animated hover/pressed/disabled states) and the **Cinzel** font family throughout — Cinzel Bold for menu headings, Cinzel SemiBold for buttons, both in a pale cream with a dark brown outline for readability against any background. The main menu displays a painted logo and castle backdrop instead of a plain text title, and each submenu (Quests/Cases/Skins) has its own themed background image. The completed-run screen uses the same theme in a centered full-screen overlay, leaving the finished level visible beneath a restrained dark dimmer while presenting final score, coins, best values, and replay/menu actions.

---

## Quests, Keys, Cases & Skins

A meta-progression loop layered on top of the core game, all saved locally to `user://progression.cfg`:

- **Daily quests** — 3 active from a pool of 7 (stomp goblins, collect coins, clear levels, double-jumps, etc.), reset on the real calendar day. Claiming all three immediately rolls a fresh set.
- **Weekly quests** — 2 bigger challenges per week (e.g. finish 10 runs, stomp 50 goblins), worth more.
- **Keys** — earned only by claiming quests (not buyable with coins, so cases stay meaningful). The first 6 daily claims each day pay a full key; further claims pay key fragments (3 = 1 key).
- **Cases** — spend keys to open a case and win a cosmetic **skin**, revealed via a CS:GO-style spinning reel that decelerates onto the reward.
  - **Regular case** (1 key): weighted rarity tiers (Common 60% / Rare 24% / Epic 12% / Legendary 4%).
  - **Premium case** (3 keys): Rare-or-better only (Rare 55% / Epic 30% / Legendary 15%) — a "skip the Commons" completion accelerator.
  - **Duplicate shards** — rolling a skin you already own grants 1 shard; 10 shards auto-convert to 1 key (deliberately weaker than quest fragments, so dupes are a consolation, not income).
  - **Reveal flair scales with rarity** — Rare adds a colored flash + fanfare, Epic/Legendary add a bigger flash, screen shake, and the win jingle.
  - The Cases menu shows your keys, shard progress, collection completion (X/Y skins), total cases opened, and best pull.
- **Skins** — cosmetic character variants across four rarity tiers: **Common** knights (Bronze/Silver, simple color tints), **Rare** and **Epic** knights (Gold, Emerald, Pink, Blood, Black — hand-painted art), and a **Legendary** tier of princesses (Golden, Emerald, Amethyst, Ruby — rarer than any knight). The **Sapphire Princess** is a free starter skin owned from the very beginning, and the **Default Knight** is always available as a selectable entry in the Skins menu — so you can switch back to the base look at any time (it never drops from cases and doesn't count toward collection completion). The Skins menu has a two-column layout: a rarity-colored list on the left and a live preview on the right showing the character art, name, tier, and equipped status. Selecting previews; a separate button equips. The equipped skin is applied on every level load.

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

This project is released for educational and personal use. All sprite assets were created for this project. The **Cinzel** font family (`Cinzel/`) is third-party, licensed under the [SIL Open Font License](Cinzel/OFL.txt).
