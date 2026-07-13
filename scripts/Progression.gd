extends Node

const SAVE_PATH := "user://progression.cfg"

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
	"common": {"weight": 70, "skins": [
		{"id": "bronze_knight", "name": "Bronze Knight", "color": Color(0.8, 0.55, 0.3)},
		{"id": "silver_knight", "name": "Silver Knight", "color": Color(0.78, 0.8, 0.85)},
	]},
	"rare": {"weight": 25, "skins": [
		{"id": "gold_knight", "name": "Gold Knight", "color": Color(1.0, 0.85, 0.2), "texture": "res://assets/sprite_knight_gold.png"},
		{"id": "emerald_knight", "name": "Emerald Knight", "color": Color(0.2, 0.85, 0.45), "texture": "res://assets/sprite_knight_emerald.png"},
	]},
	"epic": {"weight": 5, "skins": [
		{"id": "blood_knight", "name": "Blood Knight", "color": Color(0.55, 0.05, 0.08), "texture": "res://assets/sprite_knight_blood.png"},
	]},
}

# Nur die ersten 6 Daily-Claims pro Tag geben volle Keys; danach Fragmente (3 = 1 Key),
# damit unbegrenztes Weiterspielen belohnt bleibt, aber 3x weniger effizient ist.
const DAILY_FULL_KEY_CLAIMS := 6
const FRAGMENTS_PER_KEY := 3
const WEEKLY_REWARD := 3

# Duplikat-Skins geben Shards (10 = 1 Key) — bewusst schwächer als Quest-Fragmente (3 = 1),
# damit Dupes ein Trostpreis bleiben und kein Farm-Einkommen werden.
const SHARDS_PER_KEY := 10
const PREMIUM_CASE_COST := 3
const PREMIUM_WEIGHTS := {"rare": 80, "epic": 20}
const TIER_RANK := {"": 0, "common": 1, "rare": 2, "epic": 3}

var keys := 0
var key_fragments := 0
var dup_shards := 0
var cases_opened := 0
var best_pull := ""
var last_reset := ""
var daily_claims_today := 0
var active_ids: Array = []
var progress: Array = [0, 0, 0]
var completed: Array = [false, false, false]
var claimed: Array = [false, false, false]
var week_id := 0
var weekly_ids: Array = []
var weekly_progress: Array = [0, 0]
var weekly_completed: Array = [false, false]
var weekly_claimed: Array = [false, false]
var owned_skins: Array = []
var equipped_skin := ""

func _ready() -> void:
	_load()
	check_daily_reset()
	check_weekly_reset()

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
	for i in range(min(3, indices.size())):
		active_ids.append(QUEST_POOL[indices[i]].id)
	progress = [0, 0, 0]
	completed = [false, false, false]
	claimed = [false, false, false]

func _roll_new_weeklies() -> void:
	var indices := range(WEEKLY_POOL.size())
	indices.shuffle()
	weekly_ids = []
	for i in range(min(2, indices.size())):
		weekly_ids.append(WEEKLY_POOL[indices[i]].id)
	weekly_progress = [0, 0]
	weekly_completed = [false, false]
	weekly_claimed = [false, false]

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

func equip_skin(id: String) -> void:
	if id not in owned_skins:
		return
	equipped_skin = id
	_save()

func get_equipped_skin() -> Dictionary:
	if equipped_skin == "":
		return {"id": "", "name": "Default", "color": Color.WHITE}
	for tier: String in SKIN_TIERS:
		for skin: Dictionary in SKIN_TIERS[tier].skins:
			if skin.id == equipped_skin:
				return skin
	return {"id": "", "name": "Default", "color": Color.WHITE}

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	keys = cfg.get_value("currency", "keys", 0)
	key_fragments = cfg.get_value("currency", "key_fragments", 0)
	dup_shards = cfg.get_value("currency", "dup_shards", 0)
	cases_opened = cfg.get_value("stats", "cases_opened", 0)
	best_pull = cfg.get_value("stats", "best_pull", "")
	last_reset = cfg.get_value("quests", "last_reset", "")
	daily_claims_today = cfg.get_value("quests", "daily_claims_today", 0)
	active_ids = cfg.get_value("quests", "active_ids", [])
	progress = cfg.get_value("quests", "progress", [0, 0, 0])
	completed = cfg.get_value("quests", "completed", [false, false, false])
	claimed = cfg.get_value("quests", "claimed", [false, false, false])
	week_id = cfg.get_value("quests", "week_id", 0)
	weekly_ids = cfg.get_value("quests", "weekly_ids", [])
	weekly_progress = cfg.get_value("quests", "weekly_progress", [0, 0])
	weekly_completed = cfg.get_value("quests", "weekly_completed", [false, false])
	weekly_claimed = cfg.get_value("quests", "weekly_claimed", [false, false])
	owned_skins = cfg.get_value("inventory", "owned_skins", [])
	equipped_skin = cfg.get_value("inventory", "equipped_skin", "")

func _save() -> void:
	var cfg := ConfigFile.new()
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
	cfg.save(SAVE_PATH)
