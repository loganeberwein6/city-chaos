extends "res://scripts/npc/npc_base.gd"
class_name Gangster

var weapon_id := "pistol"
var _shoot_cooldown := 0.0
const SHOOT_INTERVAL := 1.8

func _ready() -> void:
	faction      = Faction.GANGSTER
	max_health   = 80.0
	health       = max_health
	walk_speed   = 2.8
	run_speed    = 5.8
	awareness_radius = 30.0
	drop_cash_min = 50
	drop_cash_max = 200
	super._ready()
	_pick_weapon()

func _pick_weapon() -> void:
	var roll := _rng.randf()
	if roll < 0.5:    weapon_id = "pistol"
	elif roll < 0.75: weapon_id = "smg"
	elif roll < 0.90: weapon_id = "assault_rifle"
	elif roll < 0.97: weapon_id = "shotgun"
	else:             weapon_id = "rpg"

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD: return
	_shoot_cooldown -= delta
	# Gangsters are aggressive — attack any player they see
	if state == State.IDLE or state == State.WANDER:
		var p := is_player_nearby()
		if p and WantedSystem.get_stars() >= 1:
			enter_attack(p)

func _tick_attack(delta: float) -> void:
	if target == null or not is_instance_valid(target): _enter_wander(); return
	var dist := global_position.distance_to(target.global_position)
	var preferred := 15.0 if weapon_id == "rpg" else (8.0 if weapon_id == "shotgun" else 20.0)
	if dist > preferred + 5.0:
		_move_toward(target.global_position, run_speed, delta)
	elif dist < preferred - 5.0:
		var away := global_position + (global_position - target.global_position).normalized() * 5.0
		_move_toward(away, walk_speed, delta)
	if _shoot_cooldown <= 0.0:
		_shoot_cooldown = SHOOT_INTERVAL * (2.5 if weapon_id == "rpg" else 1.0)
		_shoot_at(target)

func _shoot_at(tgt: Node3D) -> void:
	if not tgt.has_method("take_damage"): return
	var dmg_table := {"pistol":22.0,"smg":14.0,"assault_rifle":28.0,"shotgun":70.0,"rpg":120.0}
	var dmg: float = dmg_table.get(weapon_id, 20.0)
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0,1,0), tgt.global_position + Vector3(0,1,0))
	query.exclude = [self]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result and result["collider"] == tgt:
		tgt.take_damage(dmg, -1)

func _build_visual(root: Node3D) -> void:
	_npc_build_humanoid(root,
		_npc_mat(Color(0.30, 0.22, 0.18)),          # skin
		_npc_mat(Color(0.10, 0.10, 0.12)),          # dark hoodie
		_npc_mat(Color(0.10, 0.10, 0.13)),          # dark baggy pants
		_npc_mat(Color(0.88, 0.86, 0.82)))          # white/grey sneakers

	# Hoodie hood hanging behind head
	var hood_m := _npc_mat(Color(0.10, 0.10, 0.12))
	var hood := BoxMesh.new(); hood.size = Vector3(0.28, 0.22, 0.16)
	_npc_mi(root, hood, hood_m, Vector3(0, 1.680, 0.090))

	# Gold chain
	var chain_m := _npc_mat(Color(0.88, 0.72, 0.15), 0.72, 0.22)
	var chain := CylinderMesh.new()
	chain.top_radius = 0.022; chain.bottom_radius = 0.022; chain.height = 0.185
	_npc_mi(root, chain, chain_m, Vector3(0, 1.380, -0.086))

func _on_hurt(attacker_id: int) -> void:
	var attacker := GameManager.get_player_node(attacker_id)
	if attacker: enter_attack(attacker)

func _die(killer_id: int) -> void:
	SaveData.add_weapon(weapon_id, _rng.randi_range(2, 8), _rng.randi_range(4, 16))
	if _rng.randf() < 0.15:
		SaveData.give_armor(15.0)
	super._die(killer_id)
