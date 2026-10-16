class_name Card3D
extends Node3D
# Carta física: frente + verso + espessura. Plano local XY, frente para +Z.
# Hierarquia: raiz (transform de jogo, fly_to) → _fx (soco, tremida, investida) → _vis (inclinação, flutuação) → malhas.
# Separar as camadas evita que animações sobrepostas "deformem" a carta para sempre.

signal tapped(card: Card3D)

const W := 0.63
const H := 0.86
const THICK := 0.008
const RADIUS := 0.03

# Vértice compartilhado: a carta flexiona ao longo do eixo Y (comprimento) conforme `bend`.
const _VERTEX := """
uniform float flip = 1.0;
uniform float bend = 0.0;
varying vec2 lp;
void vertex() {
	lp = VERTEX.xy;
	float y = VERTEX.y;
	VERTEX.z += flip * bend * y * y;
	NORMAL_FIX
}
float corner(vec2 p) {
	vec2 q = abs(p) - vec2(%f, %f);
	return length(max(q, 0.0)) - %f;
}
"""

const _FACE_FRAG := """
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float shine = -1.0;
uniform float flash = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float gore = 0.0;
uniform vec2 seed = vec2(0.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	if (corner(lp) > 0.0) discard;
	vec3 c = texture(tex, UV).rgb * tint;
	// Sangue: manchas que nascem nas bordas e avançam conforme `gore` (0 limpa, 1 encharcada).
	float wet = 0.0;
	if (gore > 0.001) {
		vec2 q = UV * vec2(4.0, 5.5) + seed;
		float n = vnoise(q) * 0.6 + vnoise(q * 2.3 + 7.0) * 0.3 + vnoise(q * 5.1) * 0.1;
		n += max(abs(UV.x - 0.5), abs(UV.y - 0.5)) * 0.7;
		float th = 1.3 - gore * 0.8;
		wet = smoothstep(th, th + 0.05, n);
		float core = smoothstep(th + 0.08, th + 0.25, n);
		c = mix(c, c * vec3(0.45, 0.03, 0.03) + vec3(0.16, 0.0, 0.01), wet * 0.92);
		c *= 1.0 - core * 0.35;
	}
	float diag = (UV.x + UV.y) * 0.5;
	float band = 1.0 - smoothstep(0.0, 0.08, abs(diag - shine));
	band += 0.35 * (1.0 - smoothstep(0.0, 0.03, abs(diag - shine + 0.1)));
	ALBEDO = c;
	ROUGHNESS = mix(0.42, 0.1, wet);
	SPECULAR = mix(0.4, 0.75, wet);
	EMISSION = vec3(1.0, 0.92, 0.75) * band * 0.85 + c * flash;
}
"""

const _EDGE_FRAG := """
uniform vec3 tint : source_color = vec3(0.86, 0.82, 0.74);
void fragment() {
	if (corner(lp) > 0.0) discard;
	ALBEDO = tint;
	ROUGHNESS = 0.9;
}
"""

const _GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.78, 0.35, 1.0);
varying vec2 lp;
void vertex() { lp = VERTEX.xy; }
void fragment() {
	vec2 q = abs(lp) - vec2(%f, %f);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - %f;
	float a = clamp(1.0 - d / 0.075, 0.0, 1.0);
	a = a * a * step(-0.002, d);
	ALBEDO = col.rgb;
	ALPHA = a * col.a;
}
"""

static var _tex_cache := {}
static var touch_mode := false  # no celular o hover vem do toque (main chama set_hover), não do mouse
static var _face_shader: Shader
static var _edge_shader: Shader
static var _glow_shader: Shader

var id := ""
var ref = null  # objeto de jogo associado (item, monstro...)
var zone := ""
var bob := false  # flutuação ociosa (cartas na mão)
var _fx: Node3D
var _vis: Node3D
var _front_mat: ShaderMaterial
var _mats: Array[ShaderMaterial] = []
var _glow: MeshInstance3D
var _glow_mat: ShaderMaterial
var _glow_on := false
var _glow_col := Color.BLACK
var _glow_tw: Tween
var _move_tw: Tween
var _scale_tw: Tween
var _pos_tw: Tween
var _sheen_tw: Tween
var _flash_tw: Tween
var _area: Area3D
# Dinâmica (molas): flexão e inclinação reagem à velocidade.
var _last_pos := Vector3.INF
var _vel := Vector3.ZERO
var _bend := 0.0
var _bend_v := 0.0
var _bend_sent := 0.0
var _tilt := Vector2.ZERO
var _tilt_v := Vector2.ZERO
var _phase := randf() * TAU
# Hover: levanta, cresce e inclina na direção do ponteiro.
var hovered := false
var _hover := 0.0
var _ptr := Vector2.ZERO
var _ptr_s := Vector2.ZERO
var _gore := 0.0
var _gore_tw: Tween

static func tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load("res://assets/cards/%s.jpg" % name)
	return _tex_cache[name]

static func _shaders() -> void:
	if _face_shader != null:
		return
	var hw := W / 2 - RADIUS
	var hh := H / 2 - RADIUS
	var vtx := _VERTEX % [hw, hh, RADIUS]
	_face_shader = Shader.new()
	_face_shader.code = "shader_type spatial;\n" + vtx.replace("NORMAL_FIX", "NORMAL = normalize(vec3(0.0, -2.0 * flip * bend * y, 1.0));") + _FACE_FRAG
	_edge_shader = Shader.new()
	_edge_shader.code = "shader_type spatial;\n" + vtx.replace("NORMAL_FIX", "") + _EDGE_FRAG
	_glow_shader = Shader.new()
	_glow_shader.code = _GLOW_SHADER % [hw, hh, RADIUS]

# Material de face reutilizável (decks usam o mesmo visual).
static func face_material(t: Texture2D, flip := 1.0) -> ShaderMaterial:
	_shaders()
	var m := ShaderMaterial.new()
	m.shader = _face_shader
	m.set_shader_parameter("tex", t)
	m.set_shader_parameter("flip", flip)
	return m

static func make(front_id: String, back_id: String) -> Card3D:
	var c := Card3D.new()
	c.id = front_id
	c._build(front_id, back_id)
	return c

func _build(front_id: String, back_id: String) -> void:
	_shaders()
	_fx = Node3D.new()
	add_child(_fx)
	_vis = Node3D.new()
	_fx.add_child(_vis)

	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(W, H, THICK)
	bm.subdivide_height = 8
	body.mesh = bm
	var em := ShaderMaterial.new()
	em.shader = _edge_shader
	body.material_override = em
	_mats.append(em)
	_vis.add_child(body)

	var fq := QuadMesh.new()
	fq.size = Vector2(W, H)
	fq.subdivide_depth = 10
	var front := MeshInstance3D.new()
	front.mesh = fq
	_front_mat = face_material(tex(front_id))
	_front_mat.set_shader_parameter("seed", Vector2(randf() * 50.0, randf() * 50.0))
	front.material_override = _front_mat
	front.position.z = THICK / 2 + 0.0005
	_vis.add_child(front)
	_mats.append(_front_mat)

	var back := MeshInstance3D.new()
	back.mesh = fq
	var bkm := face_material(tex(back_id), -1.0)
	back.material_override = bkm
	back.position.z = -THICK / 2 - 0.0005
	back.rotation.y = PI
	_vis.add_child(back)
	_mats.append(bkm)

	_glow = MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(W + 0.18, H + 0.18)
	_glow.mesh = gq
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = _glow_shader
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.position.z = -0.001
	_glow.visible = false
	_vis.add_child(_glow)

	_area = Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(W, H, 0.03)
	cs.shape = sh
	_area.add_child(cs)
	_area.input_ray_pickable = true
	_area.monitoring = false
	_area.monitorable = false
	_area.input_event.connect(_on_input)
	_area.mouse_entered.connect(func(): if not touch_mode: set_hover(true))
	_area.mouse_exited.connect(func(): if not touch_mode: set_hover(false))
	add_child(_area)

func set_front(front_id: String) -> void:
	id = front_id
	_front_mat.set_shader_parameter("tex", tex(front_id))

func set_pickable(on: bool) -> void:
	_area.input_ray_pickable = on

func _on_input(_cam, event, pos, _n, _idx) -> void:
	if event is InputEventMouseMotion:
		var l: Vector3 = global_transform.affine_inverse() * pos
		_ptr = Vector2(clampf(l.x / (W / 2), -1, 1), clampf(l.y / (H / 2), -1, 1))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(self)

func set_hover(on: bool) -> void:
	if on == hovered:
		return
	hovered = on
	if on:
		sheen(0.45)
	else:
		_ptr = Vector2.ZERO

# Toque rápido no celular: um "hover" breve como resposta tátil.
func press_pulse() -> void:
	set_hover(true)
	var t := create_tween()
	t.tween_interval(0.22)
	t.tween_callback(set_hover.bind(false))

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var dt := minf(delta, 1.0 / 30.0)
	var gp := global_position
	if _last_pos == Vector3.INF:
		_last_pos = gp
	var v := (gp - _last_pos) / delta
	_last_pos = gp
	_vel = _vel.lerp(v, minf(1.0, delta * 18.0))
	var lv := global_basis.orthonormalized().inverse() * _vel
	# Flexão: o ar empurra as pontas para trás do movimento (normal da carta).
	var tb := clampf(-lv.z * 0.09, -0.5, 0.5)
	_bend_v += ((tb - _bend) * 260.0 - _bend_v * 15.0) * dt
	_bend += _bend_v * dt
	# Inclinação: a borda que vai na frente "deita" para trás (estilo Balatro).
	var tt := Vector2(clampf(-lv.y * 0.05, -0.3, 0.3), clampf(lv.x * 0.05, -0.3, 0.3))
	_hover = move_toward(_hover, 1.0 if hovered else 0.0, dt * 7.0)
	var hs := _hover * _hover * (3.0 - 2.0 * _hover)  # smoothstep
	# O ponto sob o ponteiro "afunda", como se o dedo apertasse a carta (suavizado: mouse rápido não chicoteia).
	_ptr_s = _ptr_s.lerp(_ptr, minf(1.0, dt * 10.0))
	tt += Vector2(-_ptr_s.y, _ptr_s.x) * 0.2 * hs
	_tilt_v += ((tt - _tilt) * 200.0 - _tilt_v * 14.0) * dt
	_tilt += _tilt_v * dt
	_vis.rotation = Vector3(_tilt.x, _tilt.y, -_tilt.y * 0.4)
	var off := Vector3.ZERO
	if bob:
		var t := Time.get_ticks_msec() / 1000.0
		off.y = sin(t * 1.7 + _phase) * 0.012
		_vis.rotation.z += sin(t * 1.3 + _phase) * 0.012
		off += Vector3(0, 0.1, 0.06) * hs  # na mão: sobe acima das vizinhas
	else:
		off += Vector3(0, 0, 0.05) * hs   # na mesa: descola do feltro
	var sc := 1.0 + 0.07 * hs
	# Anticlipping: carta deitada inclinada/flexionada desce as bordas; sobe o suficiente para não atravessar o feltro.
	var up := global_basis.z.normalized().y
	if not bob and absf(up) > 0.5:
		var drop := (W * 0.5) * absf(sin(_tilt.y)) + (H * 0.5) * absf(sin(_tilt.x)) \
			+ maxf(0.0, -_bend * signf(up)) * (H * 0.5) * (H * 0.5)
		off.z += signf(up) * drop * sc
	_vis.position = off
	_vis.scale = Vector3.ONE * sc
	if absf(_bend - _bend_sent) > 0.0015:
		_bend_sent = _bend
		for m in _mats:
			m.set_shader_parameter("bend", _bend)

func highlight(on: bool, col := Color(1.0, 0.78, 0.35)) -> void:
	if on == _glow_on and (not on or col == _glow_col):
		return
	_glow_on = on
	_glow_col = col
	_glow.visible = on
	if _glow_tw:
		_glow_tw.kill()
	if on:
		_glow_mat.set_shader_parameter("col", col)
		_glow_tw = create_tween().set_loops()
		_glow_tw.tween_method(func(a: float): _glow_mat.set_shader_parameter("col", Color(col, a)), 1.0, 0.35, 0.55).set_trans(Tween.TRANS_SINE)
		_glow_tw.tween_method(func(a: float): _glow_mat.set_shader_parameter("col", Color(col, a)), 0.35, 1.0, 0.55).set_trans(Tween.TRANS_SINE)

func dim(on: bool) -> void:
	var c := Color(0.42, 0.4, 0.42) if on else Color.WHITE
	_front_mat.set_shader_parameter("tint", c)

# Faixa de brilho que atravessa a frente da carta.
func sheen(dur := 0.6) -> void:
	if _sheen_tw:
		_sheen_tw.kill()
	_sheen_tw = create_tween()
	_sheen_tw.tween_method(func(s: float): _front_mat.set_shader_parameter("shine", s), -0.2, 1.25, dur).set_trans(Tween.TRANS_SINE)
	_sheen_tw.tween_callback(func(): _front_mat.set_shader_parameter("shine", -1.0))

# Clarão branco de impacto.
func flash_hit(amt := 1.4) -> void:
	if _flash_tw:
		_flash_tw.kill()
	_flash_tw = create_tween()
	_flash_tw.tween_method(func(f: float): _front_mat.set_shader_parameter("flash", f), amt, 0.0, 0.3).set_ease(Tween.EASE_OUT)

# Sangue na carta: o valor escorre até o alvo (ferimento rápido, limpeza lenta).
func set_gore(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if is_equal_approx(v, _gore):
		return
	if _gore_tw:
		_gore_tw.kill()
	var dur := 0.35 if v > _gore else 1.2
	_gore_tw = create_tween()
	_gore_tw.tween_method(func(g: float):
		_gore = g
		_front_mat.set_shader_parameter("gore", g), _gore, v, dur).set_ease(Tween.EASE_OUT)

func stop_move() -> void:
	if _move_tw:
		_move_tw.kill()

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

# Pequeno "pulo" estilo papelão (squash & stretch). Sempre volta à escala 1 da camada _fx.
func punch(strength := 0.15) -> void:
	if _scale_tw:
		_scale_tw.kill()
	_scale_tw = create_tween()
	_scale_tw.tween_property(_fx, "scale", Vector3(1 + strength, 1 - strength, 1), 0.06)
	_scale_tw.tween_property(_fx, "scale", Vector3(1 - strength * 0.5, 1 + strength * 0.5, 1), 0.08)
	_scale_tw.tween_property(_fx, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK)

func shake(amt := 0.04) -> void:
	if _pos_tw:
		_pos_tw.kill()
	_pos_tw = create_tween()
	for i in 5:
		_pos_tw.tween_property(_fx, "position", Vector3(randf_range(-amt, amt), randf_range(-amt, amt), 0), 0.04)
	_pos_tw.tween_property(_fx, "position", Vector3.ZERO, 0.05)

# Investida na direção de um ponto do mundo (ataques). Retorna o tween; o impacto ocorre em ~0.17s.
func lunge(world_target: Vector3, dist := 0.28) -> Tween:
	if _pos_tw:
		_pos_tw.kill()
	var local := global_transform.affine_inverse() * world_target
	var dir := Vector3(local.x, local.y, 0).normalized()
	var lift := Vector3(0, 0, 0.12)
	_pos_tw = create_tween()
	_pos_tw.tween_property(_fx, "position", -dir * dist * 0.3 + lift * 0.5, 0.08).set_ease(Tween.EASE_OUT)
	_pos_tw.tween_property(_fx, "position", dir * dist + lift, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_pos_tw.tween_property(_fx, "position", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return _pos_tw
