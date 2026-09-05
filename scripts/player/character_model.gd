extends RefCounted
class_name CharacterModel

static func build(mesh_root: Node3D, hero_id: String) -> void:
	for child in mesh_root.get_children():
		child.queue_free()
	match hero_id:
		"batman":     _build_batman(mesh_root)
		"flash":      _build_flash(mesh_root)
		"spider_man": _build_spiderman(mesh_root)
		"iron_man":   _build_ironman(mesh_root)
		"hulk":       _build_hulk(mesh_root)
		_:            _build_normal(mesh_root)

# ── Static mesh helpers ────────────────────────────────────────────────────────

static func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic     = metallic
	m.roughness    = roughness
	return m

static func _mi(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh              = mesh
	mi.material_override = mat
	mi.position          = pos
	parent.add_child(mi)
	return mi

static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new(); m.radius = r; m.height = h; return m

static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new(); m.radius = r; m.height = r * 2.0; return m

static func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new(); m.size = Vector3(x, y, z); return m

static func _cylinder(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new(); m.top_radius = r; m.bottom_radius = r; m.height = h; return m

# ── Shared humanoid builder ────────────────────────────────────────────────────
# scale: multiplier applied to all positions and mesh sizes (for Hulk)

static func _build_humanoid(
		root: Node3D,
		skin: StandardMaterial3D, shirt: StandardMaterial3D,
		pants: StandardMaterial3D, shoe: StandardMaterial3D,
		accessory_fn: Callable,
		scale: float = 1.0) -> void:

	var s := scale

	# Static body parts
	_mi(root, _sphere(0.115 * s),               skin,  Vector3(0,        1.72 * s,  0))  # Head
	_mi(root, _cylinder(0.048 * s, 0.09 * s),   skin,  Vector3(0,        1.615 * s, 0))  # Neck
	_mi(root, _box(0.34*s, 0.46*s, 0.19*s),     shirt, Vector3(0,        1.28 * s,  0)).name = "Torso"
	_mi(root, _box(0.30*s, 0.18*s, 0.17*s),     pants, Vector3(0,        0.88 * s,  0))  # Pelvis
	_mi(root, _box(0.10*s, 0.08*s, 0.10*s),     shirt, Vector3(-0.22*s,  1.42 * s,  0))  # L shoulder pad
	_mi(root, _box(0.10*s, 0.08*s, 0.10*s),     shirt, Vector3( 0.22*s,  1.42 * s,  0))  # R shoulder pad

	# ── Left arm chain: LUA (shoulder) → LLA (elbow) → LHand (wrist) ──────────
	var lua := Node3D.new(); lua.name = "LUA"
	lua.position = Vector3(-0.25 * s, 1.35 * s, 0)
	root.add_child(lua)
	_mi(lua, _capsule(0.055 * s, 0.26 * s), shirt, Vector3(0, -0.13 * s, 0))
	var lla := Node3D.new(); lla.name = "LLA"
	lla.position = Vector3(0, -0.26 * s, 0)
	lua.add_child(lla)
	_mi(lla, _capsule(0.045 * s, 0.24 * s), shirt, Vector3(0, -0.12 * s, 0))
	var lhand := Node3D.new(); lhand.name = "LHand"
	lhand.position = Vector3(0, -0.24 * s, 0)
	lla.add_child(lhand)
	_mi(lhand, _box(0.07 * s, 0.055 * s, 0.038 * s), skin, Vector3(0, -0.028 * s, 0))

	# ── Right arm chain: RUA (shoulder) → RLA (elbow) → RHand (wrist) ─────────
	var rua := Node3D.new(); rua.name = "RUA"
	rua.position = Vector3(0.25 * s, 1.35 * s, 0)
	root.add_child(rua)
	_mi(rua, _capsule(0.055 * s, 0.26 * s), shirt, Vector3(0, -0.13 * s, 0))
	var rla := Node3D.new(); rla.name = "RLA"
	rla.position = Vector3(0, -0.26 * s, 0)
	rua.add_child(rla)
	_mi(rla, _capsule(0.045 * s, 0.24 * s), shirt, Vector3(0, -0.12 * s, 0))
	var rhand := Node3D.new(); rhand.name = "RHand"
	rhand.position = Vector3(0, -0.24 * s, 0)
	rla.add_child(rhand)
	_mi(rhand, _box(0.07 * s, 0.055 * s, 0.038 * s), skin, Vector3(0, -0.028 * s, 0))

	# ── Left leg chain: LUL (hip) → LLL (knee, with foot attached) ─────────────
	var lul := Node3D.new(); lul.name = "LUL"
	lul.position = Vector3(-0.10 * s, 0.79 * s, 0)
	root.add_child(lul)
	_mi(lul, _capsule(0.072 * s, 0.36 * s), pants, Vector3(0, -0.18 * s, 0))
	var lll := Node3D.new(); lll.name = "LLL"
	lll.position = Vector3(0, -0.36 * s, 0)
	lul.add_child(lll)
	_mi(lll, _capsule(0.058 * s, 0.33 * s), pants, Vector3(0, -0.165 * s, 0))
	_mi(lll, _box(0.09 * s, 0.055 * s, 0.20 * s), shoe, Vector3(0, -0.36 * s, 0.04 * s))

	# ── Right leg chain: RUL (hip) → RLL (knee, with foot attached) ────────────
	var rul := Node3D.new(); rul.name = "RUL"
	rul.position = Vector3(0.10 * s, 0.79 * s, 0)
	root.add_child(rul)
	_mi(rul, _capsule(0.072 * s, 0.36 * s), pants, Vector3(0, -0.18 * s, 0))
	var rll := Node3D.new(); rll.name = "RLL"
	rll.position = Vector3(0, -0.36 * s, 0)
	rul.add_child(rll)
	_mi(rll, _capsule(0.058 * s, 0.33 * s), pants, Vector3(0, -0.165 * s, 0))
	_mi(rll, _box(0.09 * s, 0.055 * s, 0.20 * s), shoe, Vector3(0, -0.36 * s, 0.04 * s))

	accessory_fn.call(root)

# ── Per-hero builders ──────────────────────────────────────────────────────────

static func _build_normal(root: Node3D) -> void:
	var skin  := _mat(Color(0.88, 0.72, 0.58))
	var shirt := _mat(Color(0.30, 0.50, 0.80))
	var pants := _mat(Color(0.20, 0.25, 0.35))
	var shoe  := _mat(Color(0.15, 0.12, 0.10))
	_build_humanoid(root, skin, shirt, pants, shoe, func(_r: Node3D) -> void: pass)

static func _build_batman(root: Node3D) -> void:
	var suit := _mat(Color(0.12, 0.12, 0.15), 0.1, 0.6)
	var skin  := _mat(Color(0.15, 0.15, 0.18))
	var gold  := _mat(Color(0.9, 0.75, 0.1), 0.4, 0.4)
	var cape  := _mat(Color(0.07, 0.07, 0.09))
	_build_humanoid(root, skin, suit, suit, suit,
		func(r: Node3D) -> void:
			# Ear spikes
			_mi(r, _box(0.05, 0.20, 0.04), suit, Vector3(-0.08, 1.96, 0))
			_mi(r, _box(0.05, 0.20, 0.04), suit, Vector3( 0.08, 1.96, 0))
			# Cape
			_mi(r, _box(0.80, 1.30, 0.03), cape, Vector3(0, 0.95, 0.14))
			# Bat symbol
			_mi(r, _box(0.28, 0.10, 0.04), gold, Vector3(0, 1.28, -0.11))
			# Belt
			_mi(r, _box(0.32, 0.06, 0.20), gold, Vector3(0, 0.88, 0))
	)

static func _build_flash(root: Node3D) -> void:
	var skin := _mat(Color(0.88, 0.72, 0.58))
	var red  := _mat(Color(0.85, 0.08, 0.08), 0.05, 0.5)
	var shoe := _mat(Color(0.60, 0.05, 0.05))
	var gold := _mat(Color(0.95, 0.75, 0.0), 0.4, 0.4)
	_build_humanoid(root, skin, red, red, shoe,
		func(r: Node3D) -> void:
			# Chest lightning bolt
			var bolt := _mi(r, _box(0.11, 0.30, 0.04), gold, Vector3(0, 1.28, -0.11))
			bolt.rotation_degrees.z = 20.0
			# Ear wings
			_mi(r, _box(0.03, 0.12, 0.07), gold, Vector3(-0.13, 1.77, 0))
			_mi(r, _box(0.03, 0.12, 0.07), gold, Vector3( 0.13, 1.77, 0))
			# Belt
			_mi(r, _box(0.30, 0.05, 0.20), gold, Vector3(0, 0.88, 0))
	)

static func _build_spiderman(root: Node3D) -> void:
	var red   := _mat(Color(0.80, 0.05, 0.05))
	var blue  := _mat(Color(0.10, 0.15, 0.70))
	var white := _mat(Color(1.0, 1.0, 1.0))
	var web   := _mat(Color(0.65, 0.02, 0.02))
	# mask covers face → skin = red, upper = red, lower = blue
	_build_humanoid(root, red, red, blue, blue,
		func(r: Node3D) -> void:
			# Eye visors
			_mi(r, _box(0.09, 0.055, 0.03), white, Vector3(-0.055, 1.72, -0.115))
			_mi(r, _box(0.09, 0.055, 0.03), white, Vector3( 0.055, 1.72, -0.115))
			# Web pattern hint on chest
			_mi(r, _box(0.30, 0.30, 0.02), web, Vector3(0, 1.28, -0.11))
	)

static func _build_ironman(root: Node3D) -> void:
	var red  := _mat(Color(0.75, 0.05, 0.05), 0.7, 0.3)
	var gold := _mat(Color(0.90, 0.65, 0.0), 0.9, 0.2)

	var glow_chest := StandardMaterial3D.new()
	glow_chest.albedo_color             = Color(0.3, 0.7, 1.0)
	glow_chest.emission_enabled         = true
	glow_chest.emission                 = Color(0.2, 0.6, 1.0)
	glow_chest.emission_energy_multiplier = 3.0

	var glow_visor := StandardMaterial3D.new()
	glow_visor.albedo_color             = Color(0.3, 0.7, 1.0)
	glow_visor.emission_enabled         = true
	glow_visor.emission                 = Color(0.2, 0.6, 1.0)
	glow_visor.emission_energy_multiplier = 1.5

	# Gold helmet covers face → skin=gold; torso=red; arms=gold; legs=red; shoe=red
	_build_humanoid(root, gold, red, red, red,
		func(r: Node3D) -> void:
			# Chest arc reactor
			_mi(r, _cylinder(0.055, 0.04), glow_chest, Vector3(0, 1.28, -0.11))
			# Faceplate visor
			_mi(r, _box(0.22, 0.06, 0.03), glow_visor, Vector3(0, 1.72, -0.12))
			# Shoulder pauldrons (bigger overlay)
			_mi(r, _box(0.16, 0.12, 0.14), gold, Vector3(-0.24, 1.52, 0))
			_mi(r, _box(0.16, 0.12, 0.14), gold, Vector3( 0.24, 1.52, 0))
	)

static func _build_hulk(root: Node3D) -> void:
	var s     := 1.35
	var green := _mat(Color(0.15, 0.55, 0.15))
	var dark_g := _mat(Color(0.10, 0.42, 0.10))
	var purple := _mat(Color(0.25, 0.15, 0.50))
	var shoe   := _mat(Color(0.10, 0.40, 0.10))
	# Hulk has no shirt — torso is bare (skin green), pants purple
	_build_humanoid(root, green, green, purple, shoe,
		func(r: Node3D) -> void:
			# Brow ridge
			_mi(r, _box(0.28 * s, 0.06 * s, 0.06 * s), dark_g, Vector3(0, 1.80 * s, -0.10 * s))
	, s)
