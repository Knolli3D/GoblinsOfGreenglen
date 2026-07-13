extends Node

const SAVE_PATH := "user://progression.cfg"

const QUEST_POOL := [
	{"id": "stomp_goblins", "desc": "Stomp %d goblins", "stat": "stomp", "target": 5},
	{"id": "collect_coins", "desc": "Collect %d coins", "stat": "coin", "target": 15},
	{"id": "no_damage_goal", "desc": "Reach a goal without taking damage", "stat": "no_damage_goal", "target": 1},
	{"id": "finish_run", "desc": "Finish a full run", "stat": "finish_run", "target": 1},
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

var keys := 0
var last_reset := ""
var active_ids: Array = []
var progress: Array = [0, 0, 0]
var completed: Array = [false, false, false]
var claimed: Array = [false, false, false]
var owned_skins: Array = []
var equipped_skin := ""

func _ready() -> void:
	_load()
	check_daily_reset()

func _quest_def(id: String) -> Dictionary:
	for q: Dictionary in QUEST_POOL:
		if q.id == id:
			return q
	return {}

func check_daily_reset() -> void:
	var today := Time.get_date_string_from_system()
	if last_reset == today:
		return
	last_reset = today
	_roll_new_quests()
	_save()

func _roll_new_quests() -> void:
	var indices := range(QUEST_POOL.size())
	indices.shuffle()
	active_ids = []
	for i in range(min(3, indices.size())):
		active_ids.append(QUEST_POOL[indices[i]].id)
	progress = [0, 0, 0]
	completed = [false, false, false]
	claimed = [false, false, false]

func get_active_quests() -> Array:
	var result: Array = []
	for i in range(active_ids.size()):
		var def := _quest_def(active_ids[i])
		if def.is_empty():
			continue
		result.append({
			"desc": def.desc % def.target if "%d" in def.desc else def.desc,
			"progress": progress[i],
			"target": def.target,
			"completed": completed[i],
			"claimed": claimed[i],
			"slot": i,
		})
	return result

func add_quest_progress(stat: String, amount: int = 1) -> void:
	var changed := false
	for i in range(active_ids.size()):
		if completed[i]:
			continue
		var def := _quest_def(active_ids[i])
		if def.is_empty() or def.stat != stat:
			continue
		progress[i] = min(progress[i] + amount, def.target)
		if progress[i] >= def.target:
			completed[i] = true
		changed = true
	if changed:
		_save()

func claim_quest(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= active_ids.size():
		return false
	if not completed[slot_idx] or claimed[slot_idx]:
		return false
	claimed[slot_idx] = true
	keys += 1
	_save()
	return true

func get_keys() -> int:
	return keys

func open_case() -> Dictionary:
	if keys <= 0:
		return {}
	keys -= 1
	var total_weight := 0
	for tier: String in SKIN_TIERS:
		total_weight += SKIN_TIERS[tier].weight
	var roll := randi_range(1, total_weight)
	var picked_tier := ""
	var acc := 0
	for tier: String in SKIN_TIERS:
		acc += SKIN_TIERS[tier].weight
		if roll <= acc:
			picked_tier = tier
			break
	var skins: Array = SKIN_TIERS[picked_tier].skins
	var skin: Dictionary = skins[randi() % skins.size()].duplicate()
	skin["tier"] = picked_tier
	if skin.id not in owned_skins:
		owned_skins.append(skin.id)
	_save()
	return skin

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
	last_reset = cfg.get_value("quests", "last_reset", "")
	active_ids = cfg.get_value("quests", "active_ids", [])
	progress = cfg.get_value("quests", "progress", [0, 0, 0])
	completed = cfg.get_value("quests", "completed", [false, false, false])
	claimed = cfg.get_value("quests", "claimed", [false, false, false])
	owned_skins = cfg.get_value("inventory", "owned_skins", [])
	equipped_skin = cfg.get_value("inventory", "equipped_skin", "")

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("currency", "keys", keys)
	cfg.set_value("quests", "last_reset", last_reset)
	cfg.set_value("quests", "active_ids", active_ids)
	cfg.set_value("quests", "progress", progress)
	cfg.set_value("quests", "completed", completed)
	cfg.set_value("quests", "claimed", claimed)
	cfg.set_value("inventory", "owned_skins", owned_skins)
	cfg.set_value("inventory", "equipped_skin", equipped_skin)
	cfg.save(SAVE_PATH)
