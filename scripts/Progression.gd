extends Node

const SAVE_PATH := "user://progression.cfg"
const SaveMigration := preload("res://scripts/SaveMigration.gd")
const SaveData := preload("res://scripts/SaveData.gd")

# Schema-Version von progression.cfg ([meta] version):
#   v1 = unversioniertes Original-Schema (keine [meta]-Sektion) — bleibt dauerhaft ladbar.
#   v2 = identisches Feld-Layout + [meta] version; Laden validiert Typen und normalisiert
#        Quest-Arrays/Inventar (siehe _normalize_state()).
# Upgrade v1→v2 = Normalisieren + Neuschreiben mit Versions-Tag in load_and_validate() —
# idempotent, ein bereits normalisierter Save ändert sich beim Wiederholen nicht.
const SAVE_VERSION := 2

const DAILY_SLOTS := 3
const WEEKLY_SLOTS := 2

const QUEST_POOL := [
	{"id": "stomp_goblins", "desc": "Stomp %d goblins", "stat": "stomp", "target": 5},
	{"id": "collect_coins", "desc": "Collect %d coins", "stat": "coin", "target": 15},
	{"id": "no_damage_goal", "desc": "Reach a goal without taking damage", "stat": "no_damage_goal", "target": 1},
	{"id": "finish_run", "desc": "Finish a full run", "stat": "finish_run", "target": 1},
	{"id": "double_jumps", "desc": "Double-jump %d times", "stat": "double_jump", "target": 15},
	{"id": "clear_levels", "desc": "Clear %d levels", "stat": "level_clear", "target": 5},
	{"id": "coin_hunter", "desc": "Collect %d coins", "stat": "coin", "target": 30},
]

const WEEKLY_POOL := [
	{"id": "w_finish_runs", "desc": "Finish %d runs", "stat": "finish_run", "target": 10},
	{"id": "w_stomp", "desc": "Stomp %d goblins", "stat": "stomp", "target": 50},
	{"id": "w_coins", "desc": "Collect %d coins", "stat": "coin", "target": 100},
	{"id": "w_no_damage_run", "desc": "Finish %d runs without taking damage", "stat": "no_damage_run", "target": 3},
]

const SKIN_TIERS := {
	"rare": {"weight": 60, "skins": [
		{"id": "gold_knight", "name": "Gold Knight", "color": Color(1.0, 0.85, 0.2), "texture": "res://assets/sprite_knight_gold.png"},
		{"id": "emerald_knight", "name": "Emerald Knight", "color": Color(0.2, 0.85, 0.45), "texture": "res://assets/sprite_knight_emerald.png"},
		{"id": "pink_knight", "name": "Pink Knight", "color": Color(0.95, 0.45, 0.7), "texture": "res://assets/sprite_knight_pink.png"},
	]},
	"epic": {"weight": 30, "skins": [
		{"id": "blood_knight", "name": "Blood Knight", "color": Color(0.55, 0.05, 0.08), "texture": "res://assets/sprite_knight_blood.png"},
		{"id": "black_knight", "name": "Black Knight", "color": Color(0.35, 0.3, 0.4), "texture": "res://assets/sprite_knight_black.png"},
	]},
	# Prinzessinnen — seltener als alle Ritter-Skins.
	"legendary": {"weight": 10, "skins": [
		{"id": "princess_gold", "name": "Golden Princess", "color": Color(1.0, 0.8, 0.2), "texture": "res://assets/sprite_princess_gold.png"},
		{"id": "princess_green", "name": "Emerald Princess", "color": Color(0.3, 0.8, 0.4), "texture": "res://assets/sprite_princess_green.png"},
		{"id": "princess_purple", "name": "Amethyst Princess", "color": Color(0.7, 0.4, 0.9), "texture": "res://assets/sprite_princess_purple.png"},
		{"id": "princess_red", "name": "Ruby Princess", "color": Color(0.9, 0.25, 0.35), "texture": "res://assets/sprite_princess_red.png"},
	]},
	# Starter-Tier: weight 0 → nie aus Cases, aber von Anfang an besessen (STARTER_SKINS).
	"starter": {"weight": 0, "skins": [
		{"id": "princess_blue", "name": "Sapphire Princess", "color": Color(0.25, 0.5, 0.95), "texture": "res://assets/sprite_princess_blue.png"},
	]},
}

# Skins, die jeder Spieler von Anfang an besitzt (neben dem Default-Ritter ohne Skin).
const STARTER_SKINS := ["princess_blue"]

# Nur die ersten 6 Daily-Claims pro Tag geben volle Keys; danach Fragmente (3 = 1 Key),
# damit unbegrenztes Weiterspielen belohnt bleibt, aber 3x weniger effizient ist.
const DAILY_FULL_KEY_CLAIMS := 6
const FRAGMENTS_PER_KEY := 3
const WEEKLY_REWARD := 3

# Duplikat-Skins geben Shards (10 = 1 Key) — bewusst schwächer als Quest-Fragmente (3 = 1),
# damit Dupes ein Trostpreis bleiben und kein Farm-Einkommen werden.
const SHARDS_PER_KEY := 10
const PREMIUM_CASE_COST := 3
const PREMIUM_WEIGHTS := {"rare": 55, "epic": 30, "legendary": 15}
const TIER_RANK := {"": 0, "rare": 1, "epic": 2, "legendary": 3}

# Im Test-Harness überschreibbar (tests/test_save_system.gd), damit Tests nie den
# echten Save berühren. Produktion nutzt immer den Default SAVE_PATH.
var save_path: String = SAVE_PATH
# Version des zuletzt geladenen Saves; < SAVE_VERSION triggert den Upgrade-Save.
var loaded_version := SAVE_VERSION

var keys := 0
var key_fragments := 0
var dup_shards := 0
var cases_opened := 0
var best_pull := ""
var last_reset := ""
var daily_claims_today := 0
var active_ids: Array = []
var progress: Array = []
var completed: Array = []
var claimed: Array = []
var week_id := 0
var weekly_ids: Array = []
var weekly_progress: Array = []
var weekly_completed: Array = []
var weekly_claimed: Array = []
var owned_skins: Array = []
var equipped_skin := ""

func _ready() -> void:
	var test_dir := SaveData.test_save_dir()
	if test_dir != "":
		# Test-Isolation (siehe SaveData.TEST_SAVE_DIR_ENV): Save-Pfad umleiten und die
		# Migration überspringen — sie würde sonst in den echten user://-Ordner schreiben.
		save_path = test_dir.path_join("progression.cfg")
	else:
		# Vor JEDEM Save-Load: alte Saves aus "Cloude Game" übernehmen (einmalig, idempotent).
		# Progression ist Autoload → läuft vor Game.gd, deckt also auch highscore.cfg ab.
		SaveMigration.migrate_old_saves()
	load_and_validate()

# Kompletter Lade-Pfad (wird auch vom Test-Harness ohne Autoload aufgerufen):
# Laden (inkl. Backup-Recovery) → Normalisieren → Schema-Upgrade/Reparatur sofort
# persistieren → Tages-/Wochen-Reset. Idempotent: ein zweiter Durchlauf auf einem
# bereits normalisierten v2-Save ändert nichts mehr.
func load_and_validate() -> void:
	_load()
	if _normalize_state() or loaded_version < SAVE_VERSION:
		_save()
	check_daily_reset()
	check_weekly_reset()

# Garantiert, dass Starter-Skins besessen sind — auch bei frischer Installation oder
# Alt-Saves von vor dem Starter-Feature. Speichert nicht selbst; der Aufrufer
# (_normalize_inventory) sammelt das changed-Flag ein.
func _ensure_starter_skins() -> bool:
	var changed := false
	for id: String in STARTER_SKINS:
		if id not in owned_skins:
			owned_skins.append(id)
			changed = true
	return changed

func _def_in(pool: Array, id: String) -> Dictionary:
	for q: Dictionary in pool:
		if q.id == id:
			return q
	return {}

func check_daily_reset() -> void:
	var today := Time.get_date_string_from_system()
	if last_reset == today:
		_refill_if_all_claimed()
		return
	last_reset = today
	daily_claims_today = 0
	_roll_new_quests()
	_save()

# Safety net für Saves, bei denen alle Dailies bereits geclaimed sind (z.B. Migration
# von vor dem Refill-Feature) — der reguläre Refill passiert direkt in claim_quest().
func _refill_if_all_claimed() -> void:
	if active_ids.is_empty():
		return
	for c in claimed:
		if not c:
			return
	_roll_new_quests()
	_save()

func check_weekly_reset() -> void:
	var current := _current_week_id()
	if week_id == current:
		return
	week_id = current
	_roll_new_weeklies()
	_save()

# Montag-basierter Wochenindex seit Epoch (Tag 0 war ein Donnerstag, +3 verschiebt auf Montag)
func _current_week_id() -> int:
	return int((Time.get_unix_time_from_system() / 86400.0 + 3.0) / 7.0)

func _roll_new_quests() -> void:
	var indices := range(QUEST_POOL.size())
	indices.shuffle()
	active_ids = []
	for i in range(mini(DAILY_SLOTS, indices.size())):
		active_ids.append(QUEST_POOL[indices[i]].id)
	progress = []
	completed = []
	claimed = []
	for _i in active_ids.size():
		progress.append(0)
		completed.append(false)
		claimed.append(false)

func _roll_new_weeklies() -> void:
	var indices := range(WEEKLY_POOL.size())
	indices.shuffle()
	weekly_ids = []
	for i in range(mini(WEEKLY_SLOTS, indices.size())):
		weekly_ids.append(WEEKLY_POOL[indices[i]].id)
	weekly_progress = []
	weekly_completed = []
	weekly_claimed = []
	for _i in weekly_ids.size():
		weekly_progress.append(0)
		weekly_completed.append(false)
		weekly_claimed.append(false)

func _quest_views(pool: Array, ids: Array, prog: Array, comp: Array, clm: Array) -> Array:
	var result: Array = []
	for i in range(ids.size()):
		var def := _def_in(pool, ids[i])
		if def.is_empty():
			continue
		result.append({
			"desc": def.desc % def.target if "%d" in def.desc else def.desc,
			"progress": prog[i],
			"target": def.target,
			"completed": comp[i],
			"claimed": clm[i],
			"slot": i,
		})
	return result

func get_active_quests() -> Array:
	return _quest_views(QUEST_POOL, active_ids, progress, completed, claimed)

func get_weekly_quests() -> Array:
	return _quest_views(WEEKLY_POOL, weekly_ids, weekly_progress, weekly_completed, weekly_claimed)

func add_quest_progress(stat: String, amount: int = 1) -> void:
	var changed := false
	for i in range(active_ids.size()):
		if completed[i]:
			continue
		var def := _def_in(QUEST_POOL, active_ids[i])
		if def.is_empty() or def.stat != stat:
			continue
		progress[i] = min(progress[i] + amount, def.target)
		if progress[i] >= def.target:
			completed[i] = true
		changed = true
	for i in range(weekly_ids.size()):
		if weekly_completed[i]:
			continue
		var def := _def_in(WEEKLY_POOL, weekly_ids[i])
		if def.is_empty() or def.stat != stat:
			continue
		weekly_progress[i] = min(weekly_progress[i] + amount, def.target)
		if weekly_progress[i] >= def.target:
			weekly_completed[i] = true
		changed = true
	if changed:
		_save()

func claim_quest(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= active_ids.size():
		return false
	if not completed[slot_idx] or claimed[slot_idx]:
		return false
	claimed[slot_idx] = true
	if daily_claims_today < DAILY_FULL_KEY_CLAIMS:
		keys += 1
	else:
		key_fragments += 1
		if key_fragments >= FRAGMENTS_PER_KEY:
			key_fragments -= FRAGMENTS_PER_KEY
			keys += 1
	daily_claims_today += 1
	var all_claimed := true
	for c in claimed:
		if not c:
			all_claimed = false
			break
	if all_claimed:
		_roll_new_quests()
	_save()
	return true

func claim_weekly(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= weekly_ids.size():
		return false
	if not weekly_completed[slot_idx] or weekly_claimed[slot_idx]:
		return false
	weekly_claimed[slot_idx] = true
	keys += WEEKLY_REWARD
	_save()
	return true

func get_keys() -> int:
	return keys

func get_fragments() -> int:
	return key_fragments

func _tier_rank(tier: String) -> int:
	return int(TIER_RANK.get(tier, 0))

func open_case(premium: bool = false) -> Dictionary:
	var cost: int = PREMIUM_CASE_COST if premium else 1
	if keys < cost:
		return {}
	keys -= cost
	var weights := {}
	if premium:
		weights = PREMIUM_WEIGHTS
	else:
		for tier: String in SKIN_TIERS:
			weights[tier] = SKIN_TIERS[tier].weight
	var total_weight := 0
	for tier: String in weights:
		total_weight += int(weights[tier])
	var roll := randi_range(1, total_weight)
	var picked_tier := ""
	var acc := 0
	for tier: String in weights:
		acc += int(weights[tier])
		if roll <= acc:
			picked_tier = tier
			break
	var skins: Array = SKIN_TIERS[picked_tier].skins
	var skin: Dictionary = skins[randi() % skins.size()].duplicate()
	skin["tier"] = picked_tier
	var is_dup: bool = skin.id in owned_skins
	var shards_gained := 0
	var key_from_shards := false
	if is_dup:
		dup_shards += 1
		shards_gained = 1
		if dup_shards >= SHARDS_PER_KEY:
			dup_shards -= SHARDS_PER_KEY
			keys += 1
			key_from_shards = true
	else:
		owned_skins.append(skin.id)
	cases_opened += 1
	if _tier_rank(picked_tier) > _tier_rank(best_pull):
		best_pull = picked_tier
	_save()
	skin["duplicate"] = is_dup
	skin["shards_gained"] = shards_gained
	skin["key_from_shards"] = key_from_shards
	return skin

func get_shards() -> int:
	return dup_shards

func get_cases_opened() -> int:
	return cases_opened

func get_best_pull() -> String:
	return best_pull

func get_total_skin_count() -> int:
	var total := 0
	for tier: String in SKIN_TIERS:
		var skins: Array = SKIN_TIERS[tier].skins
		total += skins.size()
	return total

func get_owned_skins() -> Array:
	var result: Array = []
	for tier: String in SKIN_TIERS:
		for skin: Dictionary in SKIN_TIERS[tier].skins:
			if skin.id in owned_skins:
				var entry: Dictionary = skin.duplicate()
				entry["tier"] = tier
				result.append(entry)
	return result

# Virtueller Default-Skin (Basis-Ritter ohne Tint). Bewusst NICHT in SKIN_TIERS:
# nie aus Cases ziehbar, zählt nicht zur Collection, id "" bleibt der kanonische
# "kein Skin"-Wert in progression.cfg (alte Saves bleiben kompatibel).
func get_default_skin() -> Dictionary:
	return {"id": "", "name": "Default Knight", "color": Color.WHITE, "tier": "default"}

func equip_skin(id: String) -> void:
	# "" = Default Knight ausrüsten (immer erlaubt, steht nicht in owned_skins)
	if id != "" and id not in owned_skins:
		return
	equipped_skin = id
	_save()

func get_equipped_skin() -> Dictionary:
	if equipped_skin == "":
		return get_default_skin()
	for tier: String in SKIN_TIERS:
		for skin: Dictionary in SKIN_TIERS[tier].skins:
			if skin.id == equipped_skin:
				return skin
	return get_default_skin()

# Getypte Reads: jedes Feld fällt einzeln auf seinen Default zurück (Warnung inklusive),
# ein kaputtes Feld resettet also nie den restlichen Save. Numerische Felder werden
# direkt hier auf >= 0 geklemmt; Semantik (Quest-IDs, Skins) prüft _normalize_state().
func _load() -> void:
	var cfg: ConfigFile = SaveData.load_with_backup(save_path)
	if cfg == null:
		return  # frische Installation (oder Save + Backup unlesbar → Defaults)
	loaded_version = SaveData.read_version(cfg, SAVE_VERSION, "progression.cfg")
	keys = SaveData.read_int(cfg, "currency", "keys", 0)
	key_fragments = SaveData.read_int(cfg, "currency", "key_fragments", 0)
	dup_shards = SaveData.read_int(cfg, "currency", "dup_shards", 0)
	cases_opened = SaveData.read_int(cfg, "stats", "cases_opened", 0)
	best_pull = SaveData.read_string(cfg, "stats", "best_pull", "")
	last_reset = SaveData.read_string(cfg, "quests", "last_reset", "")
	daily_claims_today = SaveData.read_int(cfg, "quests", "daily_claims_today", 0)
	active_ids = SaveData.read_array(cfg, "quests", "active_ids")
	progress = SaveData.read_array(cfg, "quests", "progress")
	completed = SaveData.read_array(cfg, "quests", "completed")
	claimed = SaveData.read_array(cfg, "quests", "claimed")
	week_id = SaveData.read_int(cfg, "quests", "week_id", 0)
	weekly_ids = SaveData.read_array(cfg, "quests", "weekly_ids")
	weekly_progress = SaveData.read_array(cfg, "quests", "weekly_progress")
	weekly_completed = SaveData.read_array(cfg, "quests", "weekly_completed")
	weekly_claimed = SaveData.read_array(cfg, "quests", "weekly_claimed")
	owned_skins = SaveData.read_array(cfg, "inventory", "owned_skins")
	equipped_skin = SaveData.read_string(cfg, "inventory", "equipped_skin", "")

# Repariert die geladenen Felder in-place. true = etwas wurde geändert → der Aufrufer
# persistiert den reparierten Stand sofort. Auf einem gültigen Save ist jede dieser
# Funktionen ein No-Op (Idempotenz — wiederholte Load/Save-Zyklen ändern nichts).
func _normalize_state() -> bool:
	var changed := _normalize_daily_state()
	changed = _normalize_weekly_state() or changed
	changed = _normalize_inventory() or changed
	changed = _normalize_stats() or changed
	return changed

func _normalize_daily_state() -> bool:
	var n := _normalize_quest_block(QUEST_POOL, active_ids, progress, completed, claimed, DAILY_SLOTS)
	active_ids = n.ids
	progress = n.progress
	completed = n.completed
	claimed = n.claimed
	# Alle Quests weggefiltert, aber der Tag ist bereits angebrochen (last_reset gesetzt):
	# sicherer Reroll statt leerem Quest-Menü — daily_claims_today bleibt dabei erhalten.
	# Frische Saves (last_reset == "") rollt check_daily_reset() ohnehin.
	if active_ids.is_empty() and last_reset != "":
		_roll_new_quests()
		return true
	return n.changed

func _normalize_weekly_state() -> bool:
	var n := _normalize_quest_block(WEEKLY_POOL, weekly_ids, weekly_progress, weekly_completed, weekly_claimed, WEEKLY_SLOTS)
	weekly_ids = n.ids
	weekly_progress = n.progress
	weekly_completed = n.completed
	weekly_claimed = n.claimed
	# Reroll nur, wenn der Save die aktuelle Woche betrifft — sonst rollt check_weekly_reset().
	if weekly_ids.is_empty() and week_id == _current_week_id():
		_roll_new_weeklies()
		return true
	return n.changed

# Filtert unbekannte, doppelte und falsch getypte Quest-IDs und richtet die parallelen
# Arrays (progress/completed/claimed) exakt an den verbleibenden IDs aus. Slot-Daten
# wandern mit ihrer ID mit (Index vor dem Filtern); fehlende Einträge werden gedefaultet.
# Invarianten danach: progress ∈ [0, target], completed folgt aus progress >= target,
# claimed nur wenn completed, alle vier Arrays gleich lang, höchstens max_slots Einträge.
func _normalize_quest_block(pool: Array, ids: Array, prog: Array, comp: Array, clm: Array, max_slots: int) -> Dictionary:
	var out := {"ids": [], "progress": [], "completed": [], "claimed": [], "changed": false}
	for i in range(ids.size()):
		if out.ids.size() >= max_slots:
			push_warning("Save: überzählige Quest-Slots verworfen (%d > %d)" % [ids.size(), max_slots])
			break
		var id: Variant = ids[i]
		if not (id is String):
			push_warning("Save: Quest-ID mit Typ %s entfernt" % type_string(typeof(id)))
			continue
		var def := _def_in(pool, id)
		if def.is_empty():
			push_warning("Save: unbekannte Quest-ID \"%s\" entfernt" % id)
			continue
		if id in out.ids:
			push_warning("Save: doppelte Quest-ID \"%s\" entfernt" % id)
			continue
		var target := int(def.target)
		var p: int = mini(SaveData.int_at(prog, i, 0), target)
		var c: bool = SaveData.bool_at(comp, i, false) or p >= target
		out.ids.append(id)
		out.progress.append(p)
		out.completed.append(c)
		out.claimed.append(SaveData.bool_at(clm, i, false) and c)
	out.changed = out.ids != ids or out.progress != prog \
		or out.completed != comp or out.claimed != clm
	return out

# Inventar: unbekannte/falsch getypte Skin-IDs raus, Duplikate dedupliziert, Starter-Skins
# garantiert, und ein nicht (mehr) besessener equipped_skin fällt auf den Default Knight
# ("") zurück. Reihenfolge wichtig: Starter zuerst sichern, damit ein equippter
# Starter-Skin einen korrupten owned_skins-Eintrag überlebt.
func _normalize_inventory() -> bool:
	var valid_ids := _all_skin_ids()
	var deduped: Array = []
	for id: Variant in owned_skins:
		if not (id is String) or id not in valid_ids:
			push_warning("Save: ungültige Skin-ID %s aus dem Inventar entfernt" % [str(id)])
			continue
		if id in deduped:
			continue  # stilles Deduplizieren — kein Datenverlust, keine Warnung nötig
		deduped.append(id)
	var changed: bool = deduped != owned_skins
	owned_skins = deduped
	changed = _ensure_starter_skins() or changed
	if equipped_skin != "" and equipped_skin not in owned_skins:
		push_warning("Save: ausgerüsteter Skin \"%s\" nicht besessen — zurück zum Default Knight" % equipped_skin)
		equipped_skin = ""
		changed = true
	return changed

func _normalize_stats() -> bool:
	# TIER_RANK ist die Quelle gültiger best_pull-Werte ("" = noch nichts gezogen;
	# "starter" fehlt bewusst, da weight 0 nie aus Cases fällt).
	if not TIER_RANK.has(best_pull):
		push_warning("Save: unbekannter best_pull-Tier \"%s\" — zurückgesetzt" % best_pull)
		best_pull = ""
		return true
	return false

func _all_skin_ids() -> Array:
	var ids: Array = []
	for tier: String in SKIN_TIERS:
		for skin: Dictionary in SKIN_TIERS[tier].skins:
			ids.append(skin.id)
	return ids

# false = Schreiben fehlgeschlagen (Warnung kommt aus SaveData; der Zustand im Speicher
# bleibt gültig und der nächste erfolgreiche _save() holt alles nach).
func _save() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("currency", "keys", keys)
	cfg.set_value("currency", "key_fragments", key_fragments)
	cfg.set_value("currency", "dup_shards", dup_shards)
	cfg.set_value("stats", "cases_opened", cases_opened)
	cfg.set_value("stats", "best_pull", best_pull)
	cfg.set_value("quests", "last_reset", last_reset)
	cfg.set_value("quests", "daily_claims_today", daily_claims_today)
	cfg.set_value("quests", "active_ids", active_ids)
	cfg.set_value("quests", "progress", progress)
	cfg.set_value("quests", "completed", completed)
	cfg.set_value("quests", "claimed", claimed)
	cfg.set_value("quests", "week_id", week_id)
	cfg.set_value("quests", "weekly_ids", weekly_ids)
	cfg.set_value("quests", "weekly_progress", weekly_progress)
	cfg.set_value("quests", "weekly_completed", weekly_completed)
	cfg.set_value("quests", "weekly_claimed", weekly_claimed)
	cfg.set_value("inventory", "owned_skins", owned_skins)
	cfg.set_value("inventory", "equipped_skin", equipped_skin)
	return SaveData.save_with_backup(cfg, save_path)
