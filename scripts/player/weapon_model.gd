extends RefCounted
class_name WeaponModel

static func build(parent: Node3D, weapon_id: String) -> void:
	for c in parent.get_children():
		c.queue_free()
	if weapon_id == "": return
	match weapon_id:
		"pistol":           _pistol(parent)
		"revolver":         _revolver(parent)
		"dual_pistols":     _pistol(parent)
		"smg":              _smg(parent)
		"assault_rifle":    _rifle(parent)
		"lmg":              _lmg(parent)
		"shotgun":          _shotgun(parent)
		"combat_shotgun":   _shotgun(parent)
		"sniper":           _sniper(parent)
		"crossbow":         _crossbow(parent)
		"rpg":              _rpg(parent)
		"grenade_launcher": _grenade_launcher(parent)
		"flamethrower":     _flamethrower(parent)
		"taser":            _pistol(parent)
		"minigun":          _lmg(parent)
		_:                  _pistol(parent)

static func _mat(color: Color, metallic: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.4
	return m

static func _add(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)

static func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new(); m.size = Vector3(x, y, z); return m

static func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r; m.bottom_radius = r; m.height = h; return m

static func _pistol(p: Node3D) -> void:
	var dark := _mat(Color(0.15, 0.15, 0.15))
	_add(p, _box(0.05, 0.12, 0.18), dark, Vector3(0, 0, 0.09))   # slide
	_add(p, _box(0.05, 0.10, 0.08), dark, Vector3(0, -0.10, 0.04)) # grip

static func _revolver(p: Node3D) -> void:
	var steel := _mat(Color(0.45, 0.45, 0.45), 0.9)
	_add(p, _box(0.06, 0.08, 0.22), steel, Vector3(0, 0.01, 0.11))
	_add(p, _cyl(0.04, 0.06), steel, Vector3(0, 0.01, 0.08))  # cylinder
	_add(p, _box(0.05, 0.12, 0.07), steel, Vector3(0, -0.10, 0.02))

static func _smg(p: Node3D) -> void:
	var dark := _mat(Color(0.12, 0.12, 0.12))
	var tan  := _mat(Color(0.55, 0.45, 0.30))
	_add(p, _box(0.055, 0.10, 0.28), dark, Vector3(0, 0.02, 0.14))
	_add(p, _box(0.05,  0.14, 0.06), tan,  Vector3(0, -0.08, 0.08))
	_add(p, _cyl(0.02,  0.08), dark, Vector3(0, 0.02, 0.32))  # suppressor hint

static func _rifle(p: Node3D) -> void:
	var dark := _mat(Color(0.10, 0.10, 0.10))
	var tan  := _mat(Color(0.5, 0.42, 0.28))
	_add(p, _box(0.055, 0.09, 0.40), dark, Vector3(0, 0.02, 0.20))
	_add(p, _box(0.05,  0.14, 0.08), tan,  Vector3(0, -0.08, 0.10))
	_add(p, _box(0.04,  0.05, 0.10), dark, Vector3(0, -0.01, 0.05))  # mag

static func _lmg(p: Node3D) -> void:
	var dark := _mat(Color(0.12, 0.12, 0.12))
	_add(p, _box(0.07, 0.10, 0.50), dark, Vector3(0, 0.02, 0.25))
	_add(p, _box(0.10, 0.16, 0.10), dark, Vector3(0, -0.05, 0.15))  # drum mag
	_add(p, _cyl(0.025, 0.12), dark, Vector3(0, 0.02, 0.56))

static func _shotgun(p: Node3D) -> void:
	var brown := _mat(Color(0.35, 0.22, 0.10), 0.1)
	var steel := _mat(Color(0.4, 0.4, 0.4), 0.8)
	_add(p, _box(0.06, 0.08, 0.45), steel, Vector3(0, 0.02, 0.22))
	_add(p, _box(0.05, 0.12, 0.20), brown, Vector3(0, -0.06, 0.08))

static func _sniper(p: Node3D) -> void:
	var dark  := _mat(Color(0.10, 0.10, 0.10))
	var tan   := _mat(Color(0.5, 0.42, 0.28))
	var glass := _mat(Color(0.3, 0.5, 0.7), 0.1)
	_add(p, _box(0.055, 0.08, 0.65), dark, Vector3(0, 0.02, 0.32))
	_add(p, _box(0.05,  0.14, 0.10), tan,  Vector3(0, -0.08, 0.14))
	_add(p, _box(0.04,  0.04, 0.12), glass, Vector3(0, 0.06, 0.22))  # scope
	_add(p, _cyl(0.02,  0.15), dark, Vector3(0, 0.02, 0.73))

static func _crossbow(p: Node3D) -> void:
	var wood  := _mat(Color(0.38, 0.24, 0.10), 0.0)
	var steel := _mat(Color(0.4, 0.4, 0.4), 0.8)
	_add(p, _box(0.05, 0.07, 0.35), wood,  Vector3(0, 0.01, 0.17))
	_add(p, _box(0.35, 0.04, 0.05), steel, Vector3(0, 0.04, 0.08))  # limbs

static func _rpg(p: Node3D) -> void:
	var green := _mat(Color(0.2, 0.35, 0.15), 0.2)
	_add(p, _cyl(0.05, 0.60), green, Vector3(0, 0.02, 0.30))
	_add(p, _cyl(0.03, 0.18), green, Vector3(0, 0.02, 0.69))  # warhead cone approx

static func _grenade_launcher(p: Node3D) -> void:
	var dark := _mat(Color(0.15, 0.15, 0.12))
	_add(p, _cyl(0.055, 0.35), dark, Vector3(0, 0.02, 0.17))
	_add(p, _box(0.05, 0.14, 0.08), dark, Vector3(0, -0.08, 0.08))

static func _flamethrower(p: Node3D) -> void:
	var red    := _mat(Color(0.7, 0.1, 0.1), 0.3)
	var silver := _mat(Color(0.6, 0.6, 0.6), 0.8)
	_add(p, _cyl(0.04, 0.55), silver, Vector3(0, 0.05, 0.27))
	_add(p, _cyl(0.06, 0.25), red,    Vector3(0, -0.02, 0.12))  # tank
