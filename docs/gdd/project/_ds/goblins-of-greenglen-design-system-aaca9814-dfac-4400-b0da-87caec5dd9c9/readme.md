# Goblins of Greenglen — Design System

A hand-painted storybook-fantasy design system for **Goblins of Greenglen**, a 2D side-scrolling platformer built in Godot 4.6 / GDScript. You play a knight, stomp goblins, collect coins, and clear a growing campaign map — wrapped in a warm, painterly medieval-forest look.

## Sources

- GitHub repo (read for tokens, layout, and copy): https://github.com/Knolli3D/GoblinsOfGreenglen — explore `scripts/GreenglenUI.gd` (theme/button/color source of truth), `scripts/GameMenuController.gd`, `scripts/HUDController.gd`, `scripts/SkinMenuController.gd`, and `README.md` for the fullest picture. Re-read the live repo before extending this system — it is the ground truth, not this document.
- Uploaded art assets: logo, icon, character art (knight/goblin/princesses), skin sprites, menu/level background paintings, UI button textures, and the Cinzel variable font.

This design system is a derived artifact for prototyping and mockups — it simplifies and re-implements the visual language in HTML/CSS/React; it is **not** the game's real Godot UI code.

## Product

One product: the game itself, with two visual "modes" reused throughout this system —
1. **In-game HUD** — minimal overlay during platforming (hearts, score, coins, keys, run timer).
2. **Main menu + submenus** — Start Game, Map (campaign), Quests, Cases, Skins, plus Pause and the shared Run Result screen. All submenus share one look: full-bleed painted background, dark dimmer, centered Cinzel-Bold title, and hand-painted wood buttons.

## Index

- `styles.css` — root stylesheet, imports everything under `tokens/`
- `tokens/` — `colors.css`, `typography.css`, `spacing.css`, `fonts.css`
- `assets/brand/` — logo, app icon
- `assets/characters/` — hero art (knight, goblin, princesses) + `skins/` (all 10 cosmetic sprite variants + platform/goblin sprites)
- `assets/backgrounds/` — main menu, per-submenu (map/quests/cases/skins), and level parallax backgrounds
- `assets/ui/buttons/` — the 4-state Greenglen button art (normal/hover/pressed/disabled)
- `assets/screenshots/` — reference screenshots of the real game (main menu, gameplay)
- `assets/fonts/` — Cinzel variable font file
- `components/core/` — `GreenglenButton`, `GreenglenHeading`
- `components/hud/` — `HeartsMeter`, `StatValue`
- `components/badges/` — `TierBadge`
- `components/navigation/` — `SubmenuShell`
- `ui_kits/main-menu/` — clickable recreation of the main menu → Skins/Map/Result flow
- `guidelines/` — foundation specimen cards (Design System tab)

## Components

| Component | What it's for |
|---|---|
| `GreenglenButton` | Hand-painted wood/metal button, 4 art states, 6:1 aspect ratio |
| `GreenglenHeading` | Cinzel Bold display heading, cream fill + brown outline |
| `HeartsMeter` | ♥/♡ health pips for the gameplay HUD |
| `StatValue` | Big Cinzel stat readout with caption (Final Score / Run Time on the result screen) |
| `TierBadge` | Colored rarity label — Rare/Epic/Legendary/Starter/Default |
| `SubmenuShell` | Full-bleed themed background + dimmer + title wrapper shared by every submenu |

### Intentional additions
None of the above were invented — every one has a direct counterpart in `GreenglenUI.gd`, `GameMenuController.gd`, `HUDController.gd`, or `SkinMenuController.gd`. `StatValue` and `TierBadge` are named for their function since the source code builds them ad hoc (`_add_result_stat`, `TIER_COLORS` lookups) rather than as named node types.

## Content Fundamentals

- **Voice:** third-person, plain, game-manual tone. Buttons and labels are short imperative or noun phrases — "Start Game," "Try Again," "Exit to Menu," "Run Complete," "Run Over" — never a full sentence. No "you"/"I" address in UI copy; instructional text ("How to Run", controls table) is neutral and terse.
- **Casing:** Title Case for buttons, headings, and menu titles ("Main Menu", "New Highscore!"). Sentence case for longer descriptive copy (README prose, status/locked-region banners).
- **Punctuation for excitement:** a single exclamation point marks a reward/achievement moment — "New Highscore!", "New Best Time!", "POW!" — never stacked or overused.
- **Emoji:** not used in UI text. The HUD uses plain Unicode glyphs as functional icons (♥/♡ hearts, 🪙 coins, 🔑 keys) — these read as icons, not decorative emoji, and always pair with a number.
- **Numbers stay visible:** Score, Coins, and Run Time are shown live during play, not just at the end — the copy favors transparency over surprise.
- **Vibe:** cozy, goofy-charming fantasy adventure — "a fun, goofy charm" per the project's own README — never grimdark or self-serious, even though the visuals are painterly and detailed.

## Visual Foundations

- **Palette:** deep forest greens and warm wood/parchment browns as the base, with a single gold/amber accent (`--leaf-gold`, matching the shield-and-leaf crest and legendary tier color) used sparingly for emphasis. Cream (`--cream` `#FFF1C4`) is the one text color used everywhere, always paired with a dark brown outline for legibility over any background.
- **Type:** one family only — **Cinzel** (a chiseled serif/small-caps-adjacent display face) for absolutely everything: headings, buttons, HUD, body copy. Bold for headings/titles, SemiBold for buttons. There is no secondary sans-serif "UI font" — Cinzel carries the whole storybook feel.
- **Backgrounds:** full-bleed, hand-painted illustrations everywhere — no flat color panels, no repeating geometric patterns. Every submenu (Map, Quests, Cases, Skins) has its own unique themed painting (a notice board under a tree, a treasure vault, an armor/weapons market stall, a valley map with keys). A ~45–68% opaque dark overlay always sits between the art and the foreground UI for legibility.
- **Iconography:** none drawn — see Iconography section below.
- **Animation:** minimal and purposeful, not decorative. The one documented motion is the **POW!** label on a stomp: floats upward, scales to 1.5×, and fades out over ~0.35s with an ease-out curve. No page-transition animation, no idle bounces/pulses on menu chrome.
- **Hover/press states:** buttons swap to dedicated hand-painted art per state (not a CSS filter) — `normal → hover → pressed → disabled`. Text color also shifts per state: cream → brighter cream (`#FFFBEA`) on hover → warm gold (`#FFE7A0`) on press → muted tan (disabled).
- **Borders/shadows:** no CSS box-shadows or border-radius system at all. "Depth" comes entirely from the painted button art and from the heavy text outline (3px on buttons, 5px on headings) — never from drop shadows on UI chrome.
- **Corner radii:** none — button and panel shapes are baked into the source art (the button texture itself has rounded/beveled wood edges); HTML containers should stay rectangular with no `border-radius`.
- **Cards:** this game doesn't really have "cards" — the closest equivalent is a submenu content block, which is just text/buttons laid directly over the dimmed background art, no boxed panel, no border, no shadow.
- **Transparency/blur:** transparency is used exactly one way — the dark dimmer overlay (`rgba(13,15,26,0.45–0.68)`) between background art and foreground content. No backdrop-blur/glassmorphism anywhere.
- **Imagery color vibe:** warm, saturated, painterly fantasy-book illustration — golden-hour lighting, lush greens, no grain/desaturation/black-and-white treatment.
- **Layout:** menus are vertically stacked and centered (`VBoxContainer`), designed for a fixed 960×540 internal viewport (1280×720 window) — assume a centered, modest-width column of content rather than a responsive multi-column web layout.

## Iconography

- **No icon font, no SVG icon set.** The source project uses **plain Unicode glyphs** as its entire icon vocabulary in the HUD: ♥ / ♡ (hearts), 🪙 (coins), 🔑 (keys). Copy this pattern exactly — don't introduce a Lucide/Heroicons-style icon set or hand-drawn SVG icons; it would be inconsistent with the source.
- Rarity/tier is communicated by **color alone** (see `TierBadge`), never by a badge icon or shape.
- The only illustrated (non-glyph) imagery is full character/creature art (knight, goblin, princesses, skins) and full-bleed backgrounds — treat these as illustrations, not icons.

## Fonts

**Cinzel** (SIL Open Font License) is the only typeface, shipped here as the variable font file uploaded with the project (`assets/fonts/Cinzel-VariableFont_wght.ttf`). The upstream repo also ships static weights (Regular/Medium/SemiBold/Bold/ExtraBold/Black) under `Cinzel/static/` if a non-variable fallback is ever needed — pull `Cinzel/static/Cinzel-Bold.ttf` and `Cinzel/static/Cinzel-SemiBold.ttf` from the repo if a target environment can't handle variable-font weight interpolation.

## Caveats / Ask

- Skin sprite art (`sprite_knight_*`, `sprite_princess_*`) came in with transparent backgrounds already cut — good to use directly as HTML background/img assets.
- No Figma file was attached — everything here is derived from the GitHub codebase and the uploaded art. If a Figma file exists for this project, attach it and I can tighten spacing/sizing further.
- The UI kit is a cosmetic HTML/CSS/React approximation of the Godot UI, not the real Godot theme resource — pixel-for-pixel button padding and font metrics may drift slightly from the actual `.tscn` layout.
- I did not build a Quests or Cases screen in the UI kit yet (only Main Menu, Map preview, Skins, and Run Result) — say the word and I'll add them next, following the same `SubmenuShell` pattern.
