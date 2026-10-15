class_name Card3D
extends Node3D
# Carta física: frente + verso + espessura. Plano local XY, frente para +Z.

signal tapped(card: Card3D)

const W := 0.63
const H := 0.86
const THICK := 0.008

static var _tex_cache := {}
static var _edge_mat: StandardMaterial3D

var id := ""
var ref = null  # objeto de jogo associado (item, monstro...)
var zone := ""
var _front_mat: StandardMaterial3D
var _glow: MeshInstance3D
var _glow_tw: Tween
var _move_tw: Tween

static func tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load("res://cards/%s.jpg" % name)
	return _tex_cache[name]

static func make(front_id: String, back_id: String) -> Card3D:
	var c := Card3D.new()
	c.id = front_id
	c._build(front_id, back_id)
	return c

func _build(front_id: String, back_id: String) -> void:
	if _edge_mat == null:
		_edge_mat = StandardMaterial3D.new()
		_edge_mat.albedo_color = Color(0.86, 0.82, 0.74)
		_edge_mat.roughness = 0.9
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(W, H, THICK)
	body.mesh = bm
	body.material_override = _edge_mat
	add_child(body)

	var fq := QuadMesh.new()
	fq.size = Vector2(W, H)
	var front := MeshInstance3D.new()
	front.mesh = fq
	_front_mat = _face_mat(tex(front_id))
	front.material_override = _front_mat
	front.position.z = THICK / 2 + 0.0005
	add_child(front)

	var back := MeshInstance3D.new()
	back.mesh = fq
	back.material_override = _face_mat(tex(back_id))
	back.position.z = -THICK / 2 - 0.0005
	back.rotation.y = PI
	add_child(back)

	_glow = MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(W + 0.07, H + 0.07)
	_glow.mesh = gq
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(1.0, 0.78, 0.35, 0.85)
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow.material_override = gm
	_glow.position.z = -0.001
	_glow.visible = false
	add_child(_glow)

	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(W, H, 0.03)
	cs.shape = sh
	area.add_child(cs)
	area.input_ray_pickable = true
	area.input_event.connect(_on_input)
	add_child(area)

func _face_mat(t: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.roughness = 0.45
	m.metallic_specular = 0.35
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func set_front(front_id: String) -> void:
	id = front_id
	_front_mat.albedo_texture = tex(front_id)

func _on_input(_cam, event, _pos, _n, _idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(self)

func highlight(on: bool, col := Color(1.0, 0.78, 0.35)) -> void:
	_glow.visible = on
	if _glow_tw:
		_glow_tw.kill()
	if on:
		var m: StandardMaterial3D = _glow.material_override
		m.albedo_color = col
		_glow_tw = create_tween().set_loops()
		_glow_tw.tween_property(m, "albedo_color:a", 0.25, 0.5).set_trans(Tween.TRANS_SINE)
		_glow_tw.tween_property(m, "albedo_color:a", 0.9, 0.5).set_trans(Tween.TRANS_SINE)

func dim(on: bool) -> void:
	_front_mat.albedo_color = Color(0.45, 0.45, 0.45) if on else Color.WHITE

# Move em arco (no espaço do pai) até o transform alvo.
func fly_to(target: Transform3D, dur := 0.45, arc := 0.5) -> Tween:
	if _move_tw:
		_move_tw.kill()
	var from := transform
	var q0 := from.basis.get_rotation_quaternion()
	var q1 := target.basis.get_rotation_quaternion()
	var s0 := from.basis.get_scale()
	var s1 := target.basis.get_scale()
	var up := Vector3.UP * arc
	var step := func(t: float) -> void:
		var p := from.origin.lerp(target.origin, t) + up * sin(t * PI)
		transform = Transform3D(Basis(q0.slerp(q1, t)).scaled(s0.lerp(s1, t)), p)
	_move_tw = create_tween()
	_move_tw.tween_method(step, 0.0, 1.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return _move_tw

# Pequeno "pulo" estilo papelão (squash & stretch).
func punch(strength := 0.15) -> void:
	var base := scale
	var t := create_tween()
	t.tween_property(self, "scale", base * Vector3(1 + strength, 1 - strength, 1), 0.06)
	t.tween_property(self, "scale", base * Vector3(1 - strength * 0.5, 1 + strength * 0.5, 1), 0.08)
	t.tween_property(self, "scale", base, 0.18).set_trans(Tween.TRANS_BACK)

func shake() -> void:
	var base := position
	var t := create_tween()
	for i in 5:
		t.tween_property(self, "position", base + Vector3(randf_range(-0.04, 0.04), 0, randf_range(-0.04, 0.04)), 0.04)
	t.tween_property(self, "position", base, 0.05)
