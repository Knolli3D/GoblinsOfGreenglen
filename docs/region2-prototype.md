# Region 2 vertical-platforming prototype

Implemented and verified on 2026-10-12 with Godot 4.6.2 and Fennara MCP 0.4.0.
This is a development blockout for review, not a released campaign region.

## Play it

Open `scenes/prototypes/Region2Playtest.tscn` in Godot and press **F6**.
F5 still opens the normal game. Region 2 remains unavailable on the public map.

- Move with A/D or arrows; Space/Up jumps and double-jumps.
- Hold toward a green, striped crag while falling to slide. Press jump to kick away,
  then steer toward the opposite wall. Each kick leaves one double-jump available.
- Touch the midway flag to activate the checkpoint. Both hits and falls respawn
  there, cost one heart/score point, and retain damage tracking. Before activation,
  recovery uses the starting position. Fatal damage ends the attempt.
- R, pause Try Again, and result Run Again reset the complete prototype attempt,
  including its checkpoint. Escape pauses. Main Menu offers Start Game to replay
  this prototype and Quit Game to exit.

Prototype gameplay awards no quests, campaign completions/unlocks, or highscore
records. It reads the equipped cosmetic through the normal Progression autoload;
the standard autoload startup/load behavior still runs. Progression submenus are
hidden in the development harness.

## Implemented in prototype order

1. **Vertical presentation:** `Level.gd` exports `level_top`, `level_height`, and
   `fall_depth`, retaining `level_width`. Camera limits use the authored rectangle;
   tall levels enable following with smoothing and hard limits. The player receives
   the level's world-space fall boundary. Existing levels keep 960/540-style bounds
   and the original bottom-plus-160 fall margin. The existing parallax landscape
   remains vertically fixed to the viewport; the fallback sky covers the full level.
2. **Wall jumping:** only StaticBody2D nodes explicitly in `climbable_walls` qualify.
   Falling while holding toward the wall caps descent at 120 px/s. Kicks use
   260 px/s horizontally and -480 px/s vertically, a 250 ms same-wall re-grab
   lock, 120 ms initial kick control, a 120 ms jump buffer, and 100 ms wall coyote
   grace. Landing/respawning clears the lock. Ordinary walls remain ordinary.
   Jump buffering also applies to the existing ground/air jump input.
3. **Checkpoints:** `Checkpoint.tscn` contains an Area2D and an editable
   `RespawnPoint`. It emits an activation intent; Game owns the accepted checkpoint
   and recovery position. Signals from another level, another body, or a finished
   attempt are rejected. `checkpoint_respawn_on_hit` opts a level into hit recovery;
   existing Region 1 hits retain their in-place behavior.
4. **Foothill Scramble:** authored 1200 x 1620 blockout, initial double-jump gap,
   two 120 px-wide climbing openings, midway camp, four goblins, six coins, optional
   side ledges/high coin, and a goal on a solid summit shelf. All geometry is editable
   in the 2D editor. No catalog scenes or release flags were changed.

`PrototypeGame.gd` reuses Main's controllers and Game's level mounting, damage,
checkpoint, pause, and result presentation. Only development entry/retry and
progress submission differ. There is no additional production autoload.

## Verification

The full runner passed **522 checks**: saves 95, campaign 68, smoke 311, vertical
foundation 48. The save canary confirmed all three real saves and backups unchanged.

```powershell
& 'E:/1dev/Godot_v4.6.2-stable_win64/Godot_v4.6.2-stable_win64_console.exe' --headless --path . -s res://tests/run_all.gd
```

Fennara checks performed:

- Camera fixture sampled bottom, middle, and top of `VerticalBoundsTest.tscn`,
  including a screenshot confirming background coverage at negative world Y.
- Real input in `WallJumpLab.tscn` demonstrated sliding, kick plus double jump,
  and an eight-kick alternating ascent. A 190 px opening did not sustain kick-only
  ascent; the authored teaching shafts use a tested 120 px opening.
- Real movement into the checkpoint and then an enemy verified hit recovery.
  A separate fall-policy fixture verified fall recovery without claiming traversal.
- `tests/fennara_region2_playtest.gd` completed Foothill using only movement/jump
  inputs: **12 wall kicks, 3 hearts, no damage, 5 coins**, actual goal/result,
  no campaign/highscore awards, and a working R restart with cleared checkpoint.
- Eight scenes passed structural and three-second runtime validation with zero
  structural issues, zero runtime errors, and zero crashes. Existing integer-division
  and shadowed-name warnings in Game, HighscoreStore, and CaseMenuController remain.
- Changed gameplay scripts have no parser errors; new scripts have no warnings.

To repeat the Fennara playthrough, start `runtime_session` with
`res://scenes/prototypes/Region2Playtest.tscn`, run `runtime_script` using
`res://tests/fennara_region2_playtest.gd` and the returned session ID, then stop the
session. The probe logs pass/fail milestones and captures midway and completion.
R uses a logical keycode in this project's InputMap; a physical-only injected key
does not match it.

Additional fixtures: `VerticalBoundsTest.tscn`, `WallJumpLab.tscn`, and
`CheckpointPlaytest.tscn`. The `FoothillScramble.tscn` and `CheckpointLab.tscn`
files are level content; use their Playtest wrappers to spawn the game/player.

## Review and remaining production work

Playtest kick timing, surface readability, shaft width, checkpoint placement, and
the difficulty of crossing from camp into the second climb. This is temporary
blockout art with existing jump/coin audio and a small slide indicator; dedicated
wall animation/SFX, mountain artwork, and final level dressing remain a later pass.
Region 2's other levels, publication, and Region 3 rolling hazards are not included.
Changes are intentionally uncommitted pending user verification.
