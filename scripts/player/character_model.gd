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

static func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

static func _mi(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
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

static func _build_normal(root: Node3D) -> void:
	var skin  := _mat(Color(0.9, 0.75, 0.6))
	var shirt := _mat(Color(0.3, 0.5, 0.8))
	var pants := _mat(Color(0.2, 0.25, 0.35))
	_mi(root, _capsule(0.32, 0.8), pants, Vector3(0, 0.4, 0))
	_mi(root, _capsule(0.35, 1.1), shirt, Vector3(0, 1.0, 0))
	_mi(root, _sphere(0.25),       skin,  Vector3(0, 1.75, 0))

static func _build_batman(root: Node3D) -> void:
	var suit := _mat(Color(0.12, 0.12, 0.15), 0.1, 0.6)
	var cape := _mat(Color(0.07, 0.07, 0.09))
	var gold := _mat(Color(0.9, 0.75, 0.1), 0.4, 0.4)
	_mi(root, _capsule(0.33, 0.8), suit, Vector3(0, 0.4, 0))
	_mi(root, _capsule(0.37, 1.1), suit, Vector3(0, 1.0, 0))
	_mi(root, _sphere(0.26),       suit, Vector3(0, 1.76, 0))
	_mi(root, _box(0.06, 0.22, 0.06), suit, Vector3(-0.1, 2.06, 0))
	_mi(root, _box(0.06, 0.22, 0.06), suit, Vector3( 0.1, 2.06, 0))
	_mi(root, _box(0.9, 1.4, 0.04),   cape, Vector3(0, 0.9, 0.22))
	_mi(root, _box(0.3, 0.12, 0.05),  gold, Vector3(0, 1.06, -0.36))

static func _build_flash(root: Node3D) -> void:
	var red  := _mat(Color(0.85, 0.08, 0.08), 0.05, 0.5)
	var gold := _mat(Color(0.95, 0.75, 0.0), 0.4, 0.4)
	_mi(root, _capsule(0.30, 0.8), red, Vector3(0, 0.4, 0))
	_mi(root, _capsule(0.33, 1.1), red, Vector3(0, 1.0, 0))
	_mi(root, _sphere(0.24),       red, Vector3(0, 1.75, 0))
	var bolt := _mi(root, _box(0.12, 0.35, 0.05), gold, Vector3(0.04, 1.0, -0.34))
	bolt.rotation_degrees.z = 20.0
	_mi(root, _box(0.04, 0.14, 0.08), gold, Vector3(-0.27, 1.78, 0))
	_mi(root, _box(0.04, 0.14, 0.08), gold, Vector3( 0.27, 1.78, 0))

static func _build_spiderman(root: Node3D) -> void:
	var blue  := _mat(Color(0.1, 0.15, 0.7))
	var red   := _mat(Color(0.8, 0.05, 0.05))
	var white := _mat(Color(1.0, 1.0, 1.0))
	_mi(root, _capsule(0.31, 0.9), blue,  Vector3(0, 0.4, 0))
	_mi(root, _capsule(0.34, 0.9), red,   Vector3(0, 1.05, 0))
	_mi(root, _sphere(0.25),       red,   Vector3(0, 1.76, 0))
	_mi(root, _box(0.10, 0.07, 0.04), white, Vector3(-0.08, 1.77, -0.24))
	_mi(root, _box(0.10, 0.07, 0.04), white, Vector3( 0.08, 1.77, -0.24))

static func _build_ironman(root: Node3D) -> void:
	var gold := _mat(Color(0.9, 0.65, 0.0), 0.9, 0.2)
	var red  := _mat(Color(0.75, 0.05, 0.05), 0.7, 0.3)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.4, 0.8, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.7, 1.0)
	glow.emission_energy_multiplier = 2.0
	_mi(root, _box(0.65, 0.8, 0.42),  gold, Vector3(0, 0.4, 0))
	_mi(root, _box(0.75, 0.85, 0.48), red,  Vector3(0, 1.05, 0))
	_mi(root, _box(0.50, 0.45, 0.48), gold, Vector3(0, 1.76, 0))
	_mi(root, _cylinder(0.08, 0.06),  glow, Vector3(0, 1.06, -0.26))
	_mi(root, _box(0.18, 0.15, 0.42), gold, Vector3(-0.45, 1.32, 0))
	_mi(root, _box(0.18, 0.15, 0.42), gold, Vector3( 0.45, 1.32, 0))

static func _build_hulk(root: Node3D) -> void:
	var green  := _mat(Color(0.15, 0.55, 0.15))
	var dark_g := _mat(Color(0.10, 0.42, 0.10))
	var purple := _mat(Color(0.25, 0.15, 0.5))
	_mi(root, _capsule(0.42, 0.9),  purple, Vector3(0, 0.4, 0))
	_mi(root, _capsule(0.55, 1.35), green,  Vector3(0, 1.1, 0))
	_mi(root, _sphere(0.35),        green,  Vector3(0, 2.0, 0))
	_mi(root, _box(0.55, 0.10, 0.20), dark_g, Vector3(0, 2.08, -0.22))
	_mi(root, _capsule(0.20, 0.72), green, Vector3(-0.68, 1.12, 0))
	_mi(root, _capsule(0.20, 0.72), green, Vector3( 0.68, 1.12, 0))
