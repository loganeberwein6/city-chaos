extends Node

const SAVE_PATH := "user://save_data.json"
const CFG_PATH  := "user://save_data.cfg"

# Hero unlock rep thresholds
const HERO_UNLOCKS := {
	"normal_person": 0,
	"batman":        10,
	"flash":         25,
	"spider_man":    40,
	"iron_man":      60,
	"hulk":          80,
}

var cash: int = 0
var total_rep: int = 0
var weapon_inventory: Dictionary = {}  # weapon_id -> {ammo: int, reserve: int}

func _ready() -> void:
	load_data()

# ── Hero unlock helpers ────────────────────────────────────────────────────────

func get_unlocked_heroes() -> Array:
	# For now always return all heroes (no real progression gate)
	return ["normal_person", "batman", "flash", "spider_man", "iron_man", "hulk"]

func is_hero_unlocked(hero_id: String) -> bool:
	return total_rep >= HERO_UNLOCKS.get(hero_id, 9999)

# ── Player name ────────────────────────────────────────────────────────────────

func save_player_name(p_name: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)  # load existing values first (ignore error if missing)
	cfg.set_value("player", "name", p_name)
	cfg.save(CFG_PATH)

func load_player_name() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return ""
	return cfg.get_value("player", "name", "") as String

# ── Last hero ─────────────────────────────────────────────────────────────────

func save_last_hero(hero_id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value("player", "last_hero", hero_id)
	cfg.save(CFG_PATH)

func load_last_hero() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return "normal_person"
	return cfg.get_value("player", "last_hero", "normal_person") as String

# ── Cash / rep ────────────────────────────────────────────────────────────────

func add_cash(amount: int) -> void:
	cash += amount
	cash = max(0, cash)

func deduct_cash_on_death() -> int:
	const CAP := 3000
	var loss := mini(int(cash * 0.1), CAP)
	cash -= loss
	return loss

func add_rep(amount: int) -> void:
	total_rep += amount
	total_rep = max(0, total_rep)

func deduct_rep_on_death() -> void:
	# 2% of current rep, no minimum
	var level_rep := _rep_to_level_progress()
	var loss := int(level_rep * 0.02)
	total_rep = max(0, total_rep - loss)

func _rep_to_level_progress() -> int:
	return total_rep % 100

# ── Weapons ───────────────────────────────────────────────────────────────────

func add_weapon(weapon_id: String, ammo: int, reserve: int) -> void:
	if weapon_id in weapon_inventory:
		weapon_inventory[weapon_id]["reserve"] += reserve
	else:
		weapon_inventory[weapon_id] = {"ammo": ammo, "reserve": reserve}

func deplete_ammo_on_death() -> void:
	for weapon_id: String in weapon_inventory:
		var entry: Dictionary = weapon_inventory[weapon_id]
		entry["ammo"]    = int(entry["ammo"]    * 0.75)
		entry["reserve"] = int(entry["reserve"] * 0.75)

func remove_equipped_weapon(weapon_id: String) -> void:
	weapon_inventory.erase(weapon_id)

# ── Armor pool ────────────────────────────────────────────────────────────────

var _armor_pool: float = 0.0

func give_armor(amount: float) -> void:
	_armor_pool = minf(_armor_pool + amount, 100.0)

func consume_armor_pool() -> float:
	var out := _armor_pool
	_armor_pool = 0.0
	return out

# ── Persistence ───────────────────────────────────────────────────────────────

func save() -> void:
	var data := {
		"cash":             cash,
		"total_rep":        total_rep,
		"weapon_inventory": weapon_inventory,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed as Dictionary
	cash             = d.get("cash", 0)
	total_rep        = d.get("total_rep", 0)
	weapon_inventory = d.get("weapon_inventory", {})
