extends Node

var _mesh_root: Node3D

# Joint node refs (shoulder/elbow/wrist/hip/knee — found by name after model build)
var _rua: Node3D    # right shoulder joint
var _lua: Node3D    # left shoulder joint
var _rla: Node3D    # right elbow joint  (child of RUA)
var _lla: Node3D    # left elbow joint   (child of LUA)
var _rhand: Node3D  # right wrist joint  (child of RLA)
var _rul: Node3D    # right hip joint
var _lul: Node3D    # left hip joint
var _rll: Node3D    # right knee joint   (child of RUL)
var _lll: Node3D    # left knee joint    (child of LUL)
var _torso: Node3D

var _anim_t      := 0.0
var _speed       := 0.0
var _is_punching := false
var _in_air      := false
var locked       := false  # set true by player_controller during finisher

func setup(mesh_root: Node3D) -> void:
	_mesh_root = mesh_root
	_refresh()

func _refresh() -> void:
	if not _mesh_root:
		return
	# find_child searches recursively so it works regardless of hierarchy depth
	_rua   = _mesh_root.find_child("RUA",   true, false) as Node3D
	_lua   = _mesh_root.find_child("LUA",   true, false) as Node3D
	_rla   = _mesh_root.find_child("RLA",   true, false) as Node3D
	_lla   = _mesh_root.find_child("LLA",   true, false) as Node3D
	_rhand = _mesh_root.find_child("RHand", true, false) as Node3D
	_rul   = _mesh_root.find_child("RUL",   true, false) as Node3D
	_lul   = _mesh_root.find_child("LUL",   true, false) as Node3D
	_rll   = _mesh_root.find_child("RLL",   true, false) as Node3D
	_lll   = _mesh_root.find_child("LLL",   true, false) as Node3D
	_torso = _mesh_root.find_child("Torso", true, false) as Node3D

func set_speed(speed: float) -> void:
	_speed = speed

func set_in_air(in_air: bool) -> void:
	_in_air = in_air

func _process(delta: float) -> void:
	if not _mesh_root:
		return
	if not _rul:
		_refresh()
		return

	_anim_t += delta * maxf(_speed * 1.5, 0.9)

	# Finisher tweens own all joints; don't fight them
	if locked:
		return

	# ── In-air: jump pose, no walk cycle ──────────────────────────────────────
	if _in_air:
		var k := 0.18  # lerp speed per frame
		if not _is_punching:
			if _lua: _lua.rotation.x = lerpf(_lua.rotation.x, -0.52, k)
			if _rua: _rua.rotation.x = lerpf(_rua.rotation.x, -0.52, k)
			if _lla: _lla.rotation.x = lerpf(_lla.rotation.x,  0.0,  k)
			if _rla: _rla.rotation.x = lerpf(_rla.rotation.x,  0.0,  k)
		if _lul: _lul.rotation.x = lerpf(_lul.rotation.x,  0.28, k)
		if _rul: _rul.rotation.x = lerpf(_rul.rotation.x,  0.28, k)
		if _lll: _lll.rotation.x = lerpf(_lll.rotation.x,  0.50, k)
		if _rll: _rll.rotation.x = lerpf(_rll.rotation.x,  0.50, k)
		if _torso: _torso.position.y = 1.28 + sin(_anim_t * 0.4) * 0.006
		return

	# ── On ground: walk cycle ─────────────────────────────────────────────────
	var t   := _anim_t
	var spd := _speed

	# Scale amplitude with speed; small idle sway so the model never looks frozen
	var arm_amp := clampf(spd * 0.055, 0.03, 0.50)
	var leg_amp := clampf(spd * 0.060, 0.03, 0.48)

	# Hip joints swing the whole leg chain (upper + lower + foot follow automatically)
	if _rul: _rul.rotation.x = -sin(t) * leg_amp
	if _lul: _lul.rotation.x =  sin(t) * leg_amp

	# Knee joints add a heel-lift bend on the push-off (rear) phase
	if _rll: _rll.rotation.x = maxf(-sin(t), 0.0) * leg_amp * 0.65
	if _lll: _lll.rotation.x = maxf( sin(t), 0.0) * leg_amp * 0.65

	# Arm/torso joints: punch tween owns these — don't overwrite during punch
	if not _is_punching:
		if _lua: _lua.rotation.x = -sin(t) * arm_amp
		if _rua: _rua.rotation.x =  sin(t) * arm_amp
		if _lla: _lla.rotation.x = maxf(sin(t), 0.0) * arm_amp * 0.30
		if _rla: _rla.rotation.x = maxf(-sin(t), 0.0) * arm_amp * 0.30

	# Torso idle breath
	if _torso:
		_torso.position.y = 1.28 + sin(t * 0.4) * 0.006

func play_punch() -> void:
	if _is_punching or not _lua:
		return
	_is_punching = true

	# Phase 1 (0.18 s): wind-up — left elbow pulls back, fist near neck, torso twists left
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_lua,    "rotation:x",  0.55, 0.18)  # left upper arm swings backward
	tw.tween_property(_lua,    "rotation:z",  0.40, 0.18)  # arm swings inward toward neck (mirrored)
	if _lla:   tw.tween_property(_lla,   "rotation:x", -1.70, 0.18)  # elbow bends sharply up
	if _rua:   tw.tween_property(_rua,   "rotation:x",  0.18, 0.18)  # right arm counter-balances
	if _torso: tw.tween_property(_torso, "rotation:y", -0.35, 0.18)  # torso twists left (mirrored)
	await tw.finished

	# Phase 2 (0.10 s): strike — arm extends and torso untwists simultaneously
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(_lua,   "rotation:x", -1.30, 0.10)
	tw2.tween_property(_lua,   "rotation:z",  0.0,  0.10)
	if _lla:   tw2.tween_property(_lla,   "rotation:x",  0.15, 0.10)
	if _rua:   tw2.tween_property(_rua,   "rotation:x",  0.35, 0.10)
	if _torso: tw2.tween_property(_torso, "rotation:y",  0.12, 0.10)  # slight counter-follow
	await tw2.finished

	# Phase 3 (0.22 s): return everything to rest
	var tw3 := create_tween().set_parallel(true)
	tw3.tween_property(_lua,   "rotation:x", 0.0, 0.22)
	tw3.tween_property(_lua,   "rotation:z", 0.0, 0.22)
	if _lla:   tw3.tween_property(_lla,   "rotation:x", 0.0, 0.22)
	if _rua:   tw3.tween_property(_rua,   "rotation:x", 0.0, 0.22)
	if _torso: tw3.tween_property(_torso, "rotation:y", 0.0, 0.22)
	await tw3.finished

	_is_punching = false
