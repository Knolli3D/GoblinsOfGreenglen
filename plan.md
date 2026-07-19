# Campaign Map Implementation Prompts

Run these prompts in order. Each one is deliberately self-contained so it can be pasted into a fresh coding task. The working tree is already dirty: preserve unrelated changes, inspect the files on disk, and do not overwrite work merely because an older document says something different.

## 1. Expand the campaign catalog to five planned regions

```text
You are working on Goblins of Greenglen, a Godot 4.6 platformer written entirely in GDScript.

Goal: expand the campaign catalog from two regions to a five-region sequential roadmap without making unfinished content playable.

Before editing:
1. Read CLAUDE.md, AGENTS.md, README.md, scripts/CampaignCatalog.gd, scripts/CampaignProgressStore.gd, scripts/CampaignMapController.gd, and the campaign tests.
2. Inspect git status --short and the current diff. Preserve all unrelated worktree changes.
3. Work from the files currently on disk. Do not assume the documentation reflects the latest implementation.

Required catalog structure:
- Keep Region 1 as the released six-main-level region using its existing scene paths.
- Keep Region 2 unreleased with its existing 8 main placeholder nodes and 2 optional bonus nodes.
- Add unreleased Region 3, Region 4, and Region 5.
- Required main-level counts are exactly: Region 1 = 6, Region 2 = 8, Region 3 = 10, Region 4 = 12, Region 5 = 14.
- Connect regions sequentially with stable next_region_id values:
  region_01 -> region_02 -> region_03 -> region_04 -> region_05.
- Region 5 has no successor.
- Use stable IDs such as r03_level_01 through r05_level_14. Do not renumber or alter existing Region 1 or Region 2 IDs.
- Keep generic placeholder display names (Region N / Location N). Do not invent final world, biome, or location names.
- Regions 3–5 must have released = false and empty scene paths. They must not be launchable.
- Give Regions 3–5 a readable serpentine required path that fits CampaignCatalog.MAP_BOUNDS. Do not add optional branches outside Region 2 yet.
- Provide valid entry level IDs, prerequisites, required connections, and keyboard focus neighbors for all nodes.
- Preserve the validator guarantees: no duplicate IDs, no dangling references, no prerequisite cycles, no unreachable required nodes, and no released level without a loadable PackedScene.

Testing:
- Update focused catalog/progression tests for five ordered stable region IDs, the 6/8/10/12/14 main-level counts, the sequential region links, valid placeholder topology, and the continued unreleased status of Regions 2–5.
- Preserve existing Region 2 optional-path assertions.
- Run the relevant headless campaign tests and report the exact command and result.

Do not:
- Make any future region released or playable.
- Add temporary level scenes, scene paths, artwork, dependencies, autoloads, or save-schema changes.
- Change Region 1 gameplay or Region 2's existing topology.
- Commit or push.

Deliver: the focused catalog/test patch, the final test result, and a short list of modified files.
```

## 2. Add the Region 1 core-unlock requirement

```text
You are working on Goblins of Greenglen, a Godot 4.6 platformer written entirely in GDScript.

Goal: make Region 1 require both its six main-level completions and a no-damage clear of Level 6 before Region 2 becomes eligible to unlock when it is eventually released.

Prerequisite: the campaign catalog already contains five sequential regions. Do not redo or discard that work.

Before editing:
1. Read CLAUDE.md, AGENTS.md, scripts/Game.gd, scripts/CampaignCatalog.gd, scripts/CampaignProgressStore.gd, and the campaign tests.
2. Inspect git status --short and the diff. Preserve all unrelated changes.
3. Trace the current level-completion path and the existing per-level no-damage state before modifying it.

Required behavior:
- Add one catalog-driven Region 1 core trial with a stable ID, clear display name, target 1, and required_for_clear = true.
- The trial is earned only when r01_level_06 is completed without the player taking damage during that Level 6 attempt.
- "No damage" means Level 6 only, not the full six-level run.
- Award trial progress through CampaignProgressStore's existing trial API. Do not introduce a second progression store or a parallel unlock system.
- The award must be idempotent: replaying or duplicating the goal signal cannot produce duplicate unlock events or corrupt progress.
- Region 1 is cleared only after all six required main levels and this core trial are complete.
- If Region 2 is still unreleased, satisfying Region 1 must be persisted but must not make Region 2 playable.
- When Region 2 is later changed to released with valid scene paths, the existing load/normalization flow must automatically unlock Region 2 and its entry level for players who already completed Region 1's requirements.
- Do not define core trials for Regions 2–5 yet. Their future requirements will be designed with their actual content.

Testing:
- Add regression coverage for a damaging Level 6 completion not satisfying the trial.
- Add coverage for a no-damage Level 6 completion satisfying it exactly once.
- Verify that all six main completions without the trial do not clear Region 1.
- Verify that completing the trial plus the six main levels clears Region 1.
- Verify future-release reconciliation still unlocks Region 2 only after it becomes released.
- Run the focused campaign suite and report the result.

Do not:
- Change health, damage, run-result, highscore, quest, or linear Start Game semantics.
- Require a no-damage full run.
- Add Region 2 gameplay or alter save schemas.
- Commit or push.

Deliver: the implementation summary, focused test result, and modified-file list.
```

## 3. Add five-region lock and Coming Soon presentation

```text
You are working on Goblins of Greenglen, a Godot 4.6 platformer written entirely in GDScript.

Goal: make the campaign map clearly explain each region's availability while keeping unreleased regions safely non-playable.

Prerequisites:
- The catalog contains Regions 1–5, with Region 1 released and Regions 2–5 unreleased.
- Region 1 has a required no-damage Level 6 core trial.

Before editing:
1. Read CLAUDE.md, AGENTS.md, scripts/CampaignMapController.gd, scripts/CampaignMapPathLayer.gd, scripts/CampaignProgressStore.gd, scripts/CampaignCatalog.gd, scripts/GreenglenUI.gd, and map smoke tests.
2. Inspect git status --short and the current diff. Preserve unrelated worktree changes.
3. Reuse the existing shared Theme, fonts, CanvasLayer 14 ownership, and map background. Do not build a second map shell.

Required presentation:
- Keep the existing Region selector as the primary navigation. Do not add a separate world-route screen.
- Add a region-level status banner in the map header area, separate from selected-location details.
- The banner must express these distinct states:
  1. Released and unlocked: Available.
  2. Prerequisite region not yet cleared: Locked, with the previous region and its outstanding requirement(s).
  3. Predecessor requirements met but this region is unreleased: Coming Soon.
- For Region 2, the locked message must make the Region 1 gate understandable: complete the six main levels and the no-damage Level 6 finale.
- For later regions whose core trial is intentionally not designed yet, state the predecessor-region requirement without inventing a fictional trial name.
- Keep Regions 2–5 selectable for preview. Their dimmed nodes and paths stay visible beneath the status banner.
- Keep their Play buttons disabled and prevent level_requested from emitting for every unreleased node.
- Preserve the existing Region 2 selector suffix and Coming Soon location state where they remain useful; avoid contradictory status text.
- Do not use a separate full-screen lockscreen. The player should see the dimmed placeholder map and the status banner.
- Preserve required solid paths, Region 2 optional dotted paths, focus behavior, details panel, keyboard interaction, and the dedicated map background.

Testing:
- Add or update smoke coverage for all three region states: available, prerequisite-locked, and earned-but-unreleased Coming Soon.
- Verify Region 2 still renders 8 main + 2 bonus nodes, and Regions 3–5 render 10/12/14 required nodes respectively.
- Verify all unreleased regions remain unplayable even when selected and their Play button is pressed.
- Verify the banner does not cause duplicate map controls, backgrounds, CanvasLayers, or refresh side effects.
- Run the relevant smoke and campaign tests and report results.

Do not:
- Make future regions playable.
- Add final names, region-specific artwork, or bonus branches to Regions 3–5.
- Change controller ownership, add autoloads, modify persistence format, or commit/push.

Deliver: the UI behavior summary, test results, and modified-file list.
```

## 4. Verify public Map navigation and campaign-level play flow

```text
You are working on Goblins of Greenglen, a Godot 4.6 platformer written entirely in GDScript.

Goal: verify and complete the public Map submenu flow after the five-region campaign expansion, without changing its established gameplay lifecycle.

Before editing:
1. Read CLAUDE.md, AGENTS.md, scripts/Game.gd, scripts/GameMenuController.gd, scripts/CampaignMapController.gd, and tests/test_smoke.gd.
2. Inspect git status --short and the current diff. Preserve unrelated changes.
3. Determine whether the current worktree already contains the Map button and map_requested intent. Extend the current implementation; do not duplicate it.

Required behavior:
- The main menu exposes one Greenglen-styled Map button placed after Start Game and before Quests/Cases/Skins.
- GameMenuController emits only a map_requested intent. Game.gd owns all lifecycle handling and connects the signal exactly once.
- Opening Map reuses the established menu lifecycle: hide other menus, pause/result UI, HUD, and stale gameplay; unpause; invalidate stale transitions; stop music; and show the map.
- Reopen the last valid selected region/level, falling back to Region 1 when saved selection is invalid.
- Region 1 remains playable through the existing CampaignMapController.level_requested -> Game._start_campaign_level() path.
- A selected playable location starts there, then continues through subsequent required main levels to that region's endpoint. Do not add a one-level-return-to-map mode or cross-region auto-transition.
- Region 2–5 remain selectable previews but cannot start gameplay.
- Back returns cleanly to the normal main menu and restores sensible focus.
- Preserve show_campaign_map_preview() if tests or development tooling still require it; do not keep a divergent duplicate map-opening implementation.

Testing:
- Exercise the real Map main-menu button, not only the preview API.
- Verify exactly-once intent wiring, mutually exclusive menu visibility, last-selection fallback, clean Back navigation, and repeat Map -> Back -> Map stability.
- Verify playable Region 1 launch and non-playable guards for Regions 2–5.
- Verify the main-menu layout still fits at 960x540 and 1280x720.
- Run smoke tests and report results.

Do not:
- Replace Start Game or alter its linear six-level flow.
- Redesign run results, highscore semantics, quests, audio, or save data.
- Add a new menu architecture, autoload, dependency, or commit/push.

Deliver: the final navigation behavior, test results, and modified-file list.
```

## 5. Full regression, documentation, and visual handoff

```text
You are working on Goblins of Greenglen, a Godot 4.6 platformer written entirely in GDScript.

Goal: finish and document the five-region campaign-map milestone after the catalog, unlock requirement, map presentation, and public navigation work are complete.

Before editing:
1. Read CLAUDE.md, AGENTS.md, README.md, the final diff, and the relevant implementation/tests.
2. Inspect git status --short. Preserve unrelated worktree changes.
3. Do not make broad refactors; correct only defects required for this milestone or its regression coverage.

Documentation requirements:
- Update CLAUDE.md, AGENTS.md, and README.md to describe the public Map submenu.
- Document the five-region roadmap and main-level counts: 6, 8, 10, 12, and 14.
- State that Region 1 is the only released playable region.
- State that Regions 2–5 are visible previews, with Locked before their predecessor gate is earned and Coming Soon after it is earned but before the region ships.
- Document Region 1's core unlock requirement: a no-damage completion of Level 6 in addition to all six main levels.
- State that Region 2 retains two optional bonus placeholders and later-region trials/bonus branches are intentionally deferred.
- Keep Start Game's existing linear run behavior accurately documented.
- Update test counts only from actual final test output; do not copy stale totals.

Visual validation:
- Open the public Map submenu from the main menu at 960x540 and 1280x720.
- Inspect Region 1, a prerequisite-locked future region, and an earned-but-unreleased future region using an isolated test save or controlled progress state.
- Confirm button layout, header readability, dimmed-node readability, distinct Locked/Coming Soon messaging, solid/dotted path semantics, disabled Play behavior, focus behavior, and no clipped or overlapping controls.

Validation:
- Run the complete Godot 4.6 headless suite using the repository's documented runner.
- Run a parser/import check and a normal headless startup smoke check.
- Run git diff --check.
- Report the exact commands, pass/fail results, final automated-test count, final git status, and any validation that could not be performed.

Do not:
- Commit or push.
- Make unfinished regions playable.
- Add final themes, levels, scene paths, or non-approved future trial requirements.

Deliver: synchronized documentation, verification results, modified-file list, and any remaining limitations.
```
