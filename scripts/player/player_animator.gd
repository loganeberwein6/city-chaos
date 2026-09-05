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

	var t   := _anim_t
	var spd := _speed

	# Scale amplitude with speed; small idle sway so the model never looks frozen
	var arm_amp := clampf(spd * 0.055, 0.03, 0.50)
	var leg_amp := clampf(spd * 0.060, 0.03, 0.48)

	# Hip joints swing the whole leg chain (upper + lower + foot follow automatically)
	# rotation.x negative = leg swings forward (+Z) for model facing +Z
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

	# Torso idle breath (position only; rotation.z handled by punch tween)
	if _torso:
		_torso.position.y = 1.28 + sin(t * 0.4) * 0.006

func play_punch() -> void:
	if _is_punching or not _rua:
		return
	_is_punching = true

	var tw := _rua.create_tween().set_parallel(true)

	# Phase 1 (0.09 s): shoulder swings forward, elbow extends into the strike,
	#                   left arm pulls back, torso twists into the punch
	tw.tween_property(_rua,   "rotation:x", -1.15, 0.09)
	if _rla:   tw.tween_property(_rla,   "rotation:x",  0.60, 0.09)
	if _lua:   tw.tween_property(_lua,   "rotation:x",  0.42, 0.09)
	if _torso: tw.tween_property(_torso, "rotation:z", -0.10, 0.09)

	# Phase 2 (0.20 s): return all
	tw.chain().set_parallel(true)
	tw.tween_property(_rua,   "rotation:x", 0.0, 0.20)
	if _rla:   tw.tween_property(_rla,   "rotation:x", 0.0, 0.20)
	if _lua:   tw.tween_property(_lua,   "rotation:x", 0.0, 0.20)
	if _torso: tw.tween_property(_torso, "rotation:z", 0.0, 0.20)

	tw.chain().tween_callback(func() -> void: _is_punching = false)
