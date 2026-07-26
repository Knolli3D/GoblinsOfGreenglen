# Wall Jump & Rolling Hazards — Implementation & Idea Notes

Status: direction approved (GDD Decision Log, 2026-07-26); interaction rules and technical prerequisites locked in a same-day follow-up review. This file is working notes for prototyping and brainstorming — it is **not** canon. Canon lives in `Game Design Document.dc.html` (§7.5, §8.2, §12.4, §12.5, §18, §21, §22, §23, §26, §25.2, §25.3).

## 1. Wall Jump (Region 2 — Stonepeak Reach)

### Design recap (GDD §7.5)
Layered on top of the existing double jump, never replacing it. Wall-slide on a designated climbable surface while airborne + falling; jump input while sliding kicks off and away; refreshes jumps like a ground touch; short lockout against re-grabbing the same wall right after a kick.

### Implementation approach (Godot 4.6 / GDScript)
- Add an `is_wall_sliding` state to the player's existing movement state machine; detect via `is_on_wall()` + falling + directional input held toward the wall.
- New tuning constants alongside existing movement constants (§7.2): `WALL_SLIDE_SPEED`, `WALL_JUMP_VELOCITY` (Vector2), `WALL_JUMP_LOCKOUT_MS`.
- Climbable surfaces need their own collision layer/group (e.g. `climbable_walls`) — do not make this a property of all vertical geometry, or every existing wall in Regions 1's levels suddenly behaves differently.
- Camera2D needs vertical smoothing + `limit_top`/`limit_bottom` per level to satisfy "never reveal space beyond level bounds" (§7.3) in the vertical axis, not just horizontal.
- Animation states needed: wall-slide loop, wall-jump kick pose.

### Resolved rules (external review, 2026-07-26)
- Wall kick is its own move, tracked separately from the double jump; it always refreshes the double jump, so kick-then-double-jump is guaranteed.
- Re-grab lockout applies only to the same wall and clears immediately on landing; switching to a different wall is never restricted.
- Two-wall ping-pong climbing is the intended core loop for narrow shafts — do not dampen it.
- Input forgiveness is required during prototyping, not optional polish: a short jump-buffer window plus a brief wall coyote-time grace after leaving a climbable surface.
- A vertical-camera/level-bounds test (see §4 below and GDD §18) is a prerequisite for the feel prototype, not a parallel task — today's camera hardcodes a 540px bottom and a y>700 fall threshold built for a single-screen level.

### Open technical questions
- Exact tuning numbers (wall-slide cap, kick velocity/angle, re-grab lockout ms) still need a playtest pass — starting values are proposed in GDD §7.5.
- Prefer the tagged-group approach for climbable surfaces; only add a dedicated physics layer if that genuinely can't scale.

### Idea-finding — level beats to prototype
- Single wall, straight vertical shaft (simplest possible test of the kick arc).
- Two facing walls, ping-pong climb (the classic arcade climb read).
- Wall-jump chain with a patrolling goblin on a mid-shaft ledge — stomp as a rest stop.
- Wall-jump used sideways to cross a gap wider than base double-jump range (tests it as a horizontal tool too, not just vertical).
- Mastery version: **The Miser's Ledge** (existing Region 2 bonus location) reframed as a no-rest chained wall-jump gauntlet.

### Art/audio needs
- Distinct climbable-wall texture (mossy/cracked crag face) vs. plain background rock, so the surface reads before a player tries it.
- New SFX: wall-slide scrape (loop), wall-jump kick (distinct from the normal jump cue).
- Optional polish: small dust/pebble particle on wall contact.

## 2. Rolling Hazards (Region 3 — The Hollowdeep)

### Design recap (GDD §12.5)
Ore carts (fast, rail-bound) and ale kegs (slower, slope-rolling) move at fixed, fully deterministic speed. Always telegraphed at least a beat before they're a threat. Avoid-only — jump/duck, never stompable. Contact uses the existing hit rule (§8.2): −1 heart, −1 combat score, 1s invulnerability.

### Implementation approach
- Own hazard scene, `RollingHazard.tscn`, two visual/behavior variants:
  - **OreCart** — rail-bound, use `PathFollow2D` along an authored path for fully deterministic motion (matches the GDD's "identical layout every attempt" rule far better than physics-simulated rigidbodies).
  - **AleKeg** — slope-rolling, same PathFollow2D approach along a slope-hugging spline rather than true physics, for the same determinism reason; add sprite rotation matched to travel speed for the "rolling" read.
- Telegraph: a visual cue (dust puff, goblin "heave!" animation) and/or audio cue firing ~1s before the hazard becomes reachable-space-relevant.
- Reuse the existing player-hit signal contract (same one goblins use) so `Game.gd` doesn't need a second damage pathway — hazards just emit the same signal.
- New group tag `rolling_hazards`, consistent with the existing `spawn_platforms` convention (§12.3).

### Resolved rules (external review, 2026-07-26)
- Both continuous timed loops and one-shot player-triggered sequences are valid — pick per beat (loops for ambient rails, triggers for curated teaching moments). Both stay deterministic as long as initial conditions are fixed.
- Hazards need their own contact-detection source — the player's existing swept check only covers the enemies group, and goblins are deliberately non-solid, so hazards can't just reuse that path. Hazards stay out of the enemies group (never stompable, never award combat score) while still routing contact into the same `Game.damage_player()` policy goblins use.
- Successive hazards on a shared route must be spaced farther apart than the 1-second invulnerability window, or players learn to tank through the whole pattern.
- Don't combine a first-time cart/keg introduction with dense goblin groups — teach the hazard read on its own, combine later.

### Open technical questions
- Any goblin/hazard interaction (e.g. a goblin comically flattened by a passing cart) — pure polish idea, not required for launch.

### Idea-finding — level beats to prototype
- Single rail, single cart, wide floor — pure read-and-dodge teaching beat (matches the drafted "The Ore Chute" brief).
- Two rails on offset timers, forcing a mid-point pause rather than a run-through.
- A keg rolling down a long slope the player is also descending — races the player, reads differently from a cart crossing perpendicular.
- Stomp-a-goblin-while-a-cart-passes-behind micro-beat, to test whether combat and hazard dodging stay legible together.
- Mastery version: multi-rail gauntlet, "Flawless Descent" trial.

### In-fiction flavor (theming: ore carts + ale kegs)
- Carts: goblins mining frantically to stay ahead of whatever's below them — player is incidental, not targeted (keeps the goofy, non-malicious tone from §4/§17).
- Kegs: raided festival ale rolling loose down old mine chutes — a light callback to the Harvest Festival inciting incident (§4 canon).

### Art/audio needs
- Cart sprite + rail/track dressing, ties into the mine-tunnel background.
- Keg sprite with roll-matched rotation.
- Approach-rumble SFX distinct from goblin patrol audio, so players learn to distinguish enemy-by-ear from hazard-by-ear.

## 3. Shared system — Vertical checkpoints (Region 2, some Region 3)

### Design recap (GDD §12.4)
Mid-route checkpoints for levels taller than one screen. Attempt-local only (nothing persists across retries). A fall/hit still costs a heart but respawns from the last checkpoint, not level start.

### Implementation approach
- Checkpoint = `Area2D`; on first enter, sets `Game`'s active respawn point for the current attempt.
- Existing fall/hit respawn logic in `Game.gd` swaps its `PlayerSpawn` lookup for "last checkpoint or level start" — should be a small, localized change given §18's stated ownership (`Game.gd` owns level lifecycle/respawn).
- Visual confirmation on activation: open per GDD §23 — candidates are a brief flag-plant animation or a screen-edge flash; needs an art/audio pass either way.

### Resolved rules (external review, 2026-07-26)
- Target policy is explicit: a fall OR a hit both respawn to the last checkpoint, not just falls. Today's implementation isn't there yet — falls already respawn the player, but an ordinary enemy/hazard hit only cancels vertical velocity. Both pathways must converge on one checkpoint-aware respawn policy before Region 2 ships.
- Checkpoint activation must never clear a level's no-damage tracking (e.g. a `took_damage_this_level` flag) — touching a checkpoint banks position only, never trial progress. A no-damage trial (Flawless Ascent/Descent) stays judged from true level start regardless of checkpoints reached (§12.4).

## 4. Suggested prototyping order
1. Vertical-camera/level-bounds test — replace the hardcoded 540px camera bottom and y>700 fall threshold with authored per-level bounds; confirm background art survives a taller viewport. De-risks presentation before either mechanic prototype depends on it.
2. Wall Jump feel prototype (isolated test scene, no art) — include jump buffering and wall coyote time from the start.
3. Vertical checkpoint respawn logic (Region 2 levels need this immediately) — converge fall and hit onto one checkpoint-aware respawn policy.
4. Rolling hazard prototype (isolated test scene) — own contact-detection source, kept out of the enemies group.
5. Foothill Scramble blockout (Region 2, uses 1-3).
6. The Ore Chute blockout (Region 3, uses 1 + 4).
7. Playtest both before committing to full Region 2/3 location rosters.

## 5. Open questions now tracked in the GDD (§23)
- Exact Wall Jump tuning values (wall-slide cap, kick velocity/angle, re-grab lockout).
- Visual/audio confirmation for checkpoint activation and wall-slide/wall-jump.
- Whether rolling hazards ever appear outside Region 3, or stay a Region 3-exclusive identity marker.
- Full scope of the vertical-camera/level-bounds rework (per-level authoring approach, background-art fix) — see §18.
