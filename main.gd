extends Node3D
# Four Souls — mesa 2.5D. Você vs. CPU, regras originais (Base Game V2):
# turno = recarregar + loot 1 · ação (1 loot + virar personagem, 1 compra, 1 ataque) · fim (todos curam).
# Pilha LIFO com prioridade, dado na pilha, combate até alguém morrer, penalidade de morte, 4 almas vence.

const D = preload("res://data.gd")
const FACE_UP := Basis(Vector3.RIGHT, -PI / 2)
const FACE_DOWN := Basis(Vector3.RIGHT, PI / 2)
const GOLD := Color(0.86, 0.68, 0.38)

signal priority_event(kind: String)
signal end_turn_requested
signal roll_requested
signal target_chosen(t)

# ---------------- Mundo ----------------
var font_b: FontFile
var font_r: FontFile
var cam: Camera3D
var cam_base: Vector3
var table: Node3D
var hand_root: Node3D
var opp_hand_root: Node3D
var lamp: SpotLight3D
var flames: Array = []
var dice: Dice3D
var decks := {}
var discard_cards: Array = []

# ---------------- Estado ----------------
var players: Array = []
var active := 0
var loot_ids: Array = []
var loot_discard: Array = []
var monster_ids: Array = []
var treasure_ids: Array = []
var slots: Array = [[], []]
var shop: Array = [null, null]
var stack: Array = []
var uid := 0
var stack_running := false
var waiting_priority := false
var awaiting_roll := false
var in_combat := false
var combat := {}
var busy := false
var turn_over := false
var game_over := false
var targeting := ""
var target_valid: Array = []
var selected_card: Card3D = null

# ---------------- HUD ----------------
var hud: CanvasLayer
var plates: Array = []
var phase_lbl: Label
var hint_lbl: Label
var toast_lbl: Label
var stack_panel: PanelContainer
var stack_list: Label
var pass_btn: Button
var action_btn: Button
var prompt_panel: PanelContainer
var prompt_lbl: Label
var inspect: Control
var insp_tex: TextureRect
var insp_title: Label
var insp_text: Label
var insp_btns: HBoxContainer
var flash: ColorRect
var overlay: Control

func _ready() -> void:
	randomize()
	var fallback := FontFile.new()
	fallback.load_dynamic_font("res://fonts/DejaVuSans.ttf")
	font_b = load("res://fonts/NotoSerif-Bold.ttf")
	font_r = load("res://fonts/NotoSerif-Regular.ttf")
	font_b.fallbacks = [fallback]
	font_r.fallbacks = [fallback]
	get_viewport().physics_object_picking = true
	_build_world()
	_build_hud()
	_show_select()

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if lamp:
		lamp.light_energy = 5.0 * (1.0 + 0.035 * sin(t * 6.3) + 0.025 * sin(t * 17.1))
	for f in flames:
		var l: OmniLight3D = f[1]
		l.light_energy = 0.9 + 0.25 * sin(t * 11.0 + f[2]) + 0.15 * sin(t * 23.0 + f[2])
		var m: Node3D = f[0]
		m.scale = Vector3(1, 1.0 + 0.15 * sin(t * 13.0 + f[2]), 1)

# =====================================================================
# MUNDO 3D
# =====================================================================
func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.008, 0.006)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.38, 0.3)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.03, 0.02)
	env.fog_density = 0.035
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 56
	cam.position = Vector3(0, 4.45, 0.75)
	add_child(cam)
	cam.look_at(Vector3(0, 0, -0.95))
	cam_base = cam.position

	hand_root = Node3D.new()
	hand_root.position = Vector3(-0.1, -1.5, -2.1)
	cam.add_child(hand_root)

	lamp = SpotLight3D.new()
	lamp.position = Vector3(0, 4.2, -0.4)
	lamp.rotation.x = -PI / 2
	lamp.spot_angle = 50
	lamp.spot_range = 9
	lamp.spot_attenuation = 0.7
	lamp.light_color = Color(1.0, 0.82, 0.6)
	lamp.light_energy = 5.0
	lamp.shadow_enabled = true
	lamp.shadow_blur = 1.5
	add_child(lamp)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-1.0, 0.3, 0)
	fill.light_color = Color(0.55, 0.6, 0.8)
	fill.light_energy = 0.18
	add_child(fill)

	# Mesa + feltro
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = load("res://table.jpg")
	tm.uv1_scale = Vector3(2.2, 2.2, 1)
	tm.roughness = 0.8
	tm.albedo_color = Color(0.75, 0.62, 0.52)
	var tbl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	tbl.mesh = pm
	tbl.material_override = tm
	tbl.position = Vector3(0, -0.002, -0.6)
	add_child(tbl)
	var felt_border := _plane(Vector2(4.75, 5.85), Color(0.32, 0.22, 0.12), 0.6)
	felt_border.position = Vector3(0, -0.001, -0.95)
	add_child(felt_border)
	var felt := _plane(Vector2(4.6, 5.7), Color(0.11, 0.06, 0.055), 1.0)
	felt.position = Vector3(0, 0.0, -0.95)
	add_child(felt)

	table = Node3D.new()
	add_child(table)

	# Velas
	for p in [Vector3(-2.6, 0, -3.6), Vector3(2.65, 0, -2.0), Vector3(-2.7, 0, 0.6)]:
		_candle(p)

	# Poeira na luz
	var dust := GPUParticles3D.new()
	dust.amount = 70
	dust.lifetime = 10.0
	dust.preprocess = 10.0
	var ppm := ParticleProcessMaterial.new()
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ppm.emission_box_extents = Vector3(2.2, 1.4, 2.2)
	ppm.direction = Vector3(0, 1, 0)
	ppm.spread = 180
	ppm.initial_velocity_min = 0.01
	ppm.initial_velocity_max = 0.05
	ppm.gravity = Vector3(0, 0.004, 0)
	dust.process_material = ppm
	var dq := QuadMesh.new()
	dq.size = Vector2(0.012, 0.012)
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.albedo_color = Color(1, 0.85, 0.6, 0.35)
	dq.material = dmat
	dust.draw_pass_1 = dq
	dust.position = Vector3(0, 1.6, -0.5)
	add_child(dust)

	# Decks
	for d in [["monster", "monsterback", "MONSTROS", Vector3(-1.65, 0, -1.55)],
			["treasure", "treasureback", "TESOUROS", Vector3(-1.65, 0, -0.3)],
			["loot", "lootback", "LOOT", Vector3(1.65, 0, -0.3)],
			["discard", "lootback", "DESCARTE", Vector3(1.65, 0, -1.55)]]:
		var dk := Deck3D.new()
		table.add_child(dk)
		dk.setup(d[1], d[2], font_b)
		dk.position = d[3]
		decks[d[0]] = dk
		dk.tapped.connect(_on_deck_tapped.bind(d[0]))
	for s in 2:
		var lbl := _label3d("ESPAÇO %d" % (s + 1), 22, Color(0.95, 0.85, 0.65, 0.25))
		lbl.rotation.x = -PI / 2
		lbl.position = Vector3(-0.55 + s * 1.1, 0.002, -1.55)
		table.add_child(lbl)
	var shop_lbl := _label3d("LOJA · 10¢", 22, Color(0.95, 0.85, 0.65, 0.4))
	shop_lbl.rotation.x = -PI / 2
	shop_lbl.position = Vector3(0, 0.002, 0.22)
	table.add_child(shop_lbl)

	opp_hand_root = Node3D.new()
	opp_hand_root.position = Vector3(0, 0.55, -4.0)
	opp_hand_root.rotation = Vector3(-0.35, PI, 0)
	table.add_child(opp_hand_root)

	dice = Dice3D.new()
	dice.visible = false
	table.add_child(dice)

func _plane(sz: Vector2, col: Color, rough: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = sz
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	mi.material_override = m
	return mi

func _candle(pos: Vector3) -> void:
	var h := randf_range(0.35, 0.6)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.075
	cm.bottom_radius = 0.085
	cm.height = h
	body.mesh = cm
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.9, 0.85, 0.72)
	wax.roughness = 0.6
	wax.subsurf_scatter_enabled = false
	body.material_override = wax
	body.position = pos + Vector3(0, h / 2, 0)
	add_child(body)
	var flame := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.11
	flame.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.7, 0.3)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.55, 0.2)
	fm.emission_energy_multiplier = 6.0
	flame.material_override = fm
	flame.position = pos + Vector3(0, h + 0.06, 0)
	add_child(flame)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.omni_range = 2.8
	l.position = pos + Vector3(0, h + 0.15, 0)
	add_child(l)
	flames.append([flame, l, randf() * 10.0])

func _label3d(txt: String, sz: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font = font_b
	l.font_size = sz
	l.pixel_size = 0.0035
	l.modulate = col
	l.outline_size = 0
	return l

# ---------- Transforms de zonas (espaço da mesa) ----------
func _flat(pos: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * FACE_UP, pos)

func _row_x(i: int, n: int, x0: float, x1: float) -> float:
	if n <= 1:
		return x0
	return x0 + (x1 - x0) * float(i) / float(max(n - 1, 3))

func _char_xf(p: Dictionary) -> Transform3D:
	var tapped: bool = p.char_tapped
	if p.i == 0:
		return _flat(Vector3(-1.65, 0.01, 0.95), -PI / 2 if tapped else 0.0)
	return _flat(Vector3(1.65, 0.01, -3.0), PI + (-PI / 2 if tapped else 0.0))

func _item_xf(p: Dictionary, i: int) -> Transform3D:
	var n: int = p.items.size()
	var it: Dictionary = p.items[i]
	var yaw := -PI / 2 if it.tapped else 0.0
	var sc := 0.85
	if p.i == 0:
		var xf := _flat(Vector3(_row_x(i, n, -0.75, 1.05), 0.01 + i * 0.003, 0.95), yaw)
		return xf.scaled_local(Vector3.ONE * sc)
	var bx := _flat(Vector3(_row_x(i, n, 0.75, -1.05), 0.01 + i * 0.003, -3.0), PI + yaw)
	return bx.scaled_local(Vector3.ONE * sc)

func _soul_xf(p: Dictionary, i: int) -> Transform3D:
	if p.i == 0:
		return _flat(Vector3(2.05 + i * 0.05, 0.01 + i * 0.01, 1.1), 0.25).scaled_local(Vector3.ONE * 0.7)
	return _flat(Vector3(-2.05 - i * 0.05, 0.01 + i * 0.01, -3.15), PI + 0.25).scaled_local(Vector3.ONE * 0.7)

func _slot_xf(s: int, depth: int) -> Transform3D:
	return _flat(Vector3(-0.55 + s * 1.1 + depth * 0.04, 0.01 + depth * 0.012, -1.55 - depth * 0.04))

func _shop_xf(s: int) -> Transform3D:
	return _flat(Vector3(-0.55 + s * 1.1, 0.01, -0.3))

func _stack_xf(i: int) -> Transform3D:
	var pos := Vector3(-0.35 + i * 0.22, 1.25 + i * 0.03, 0.15 + i * 0.03)
	var b := Basis.looking_at(pos - cam.position).scaled(Vector3.ONE * 0.85)
	return Transform3D(b, pos)

func _hand_xf(i: int, n: int, sel: bool) -> Transform3D:
	var spread: float = min(0.15, 0.85 / max(n, 1))
	var a := (i - (n - 1) / 2.0) * spread
	var r := 3.2
	var pos := Vector3(sin(a) * r, cos(a) * r - r, i * 0.006)
	var sc := 0.74
	if sel:
		pos += Vector3(0, 0.42, 0.25)
		sc = 0.95
	return Transform3D(Basis(Vector3.BACK, -a).scaled(Vector3.ONE * sc), pos)

func _opp_hand_xf(i: int, n: int) -> Transform3D:
	var spread: float = min(0.14, 0.7 / max(n, 1))
	var a := (i - (n - 1) / 2.0) * spread
	var r := 2.5
	var pos := Vector3(sin(a) * r, cos(a) * r - r, -i * 0.006)
	return Transform3D(Basis(Vector3.BACK, -a).scaled(Vector3.ONE * 0.55), pos)

# =====================================================================
# HUD 2D
# =====================================================================
func _panel_style(border: Color, alpha := 0.82) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.03, 0.025, alpha)
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	return sb

func _lbl(txt: String, sz: int, col := Color(0.93, 0.88, 0.8), bold := false) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font_b if bold else font_r)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

func _btn(txt: String, cb: Callable, primary := true) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_override("font", font_b)
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(150, 50)
	var n := _panel_style(GOLD if primary else Color(0.5, 0.42, 0.32), 0.92)
	n.bg_color = Color(0.32, 0.12, 0.08, 0.95) if primary else Color(0.08, 0.06, 0.05, 0.95)
	var h := n.duplicate()
	h.bg_color = n.bg_color.lightened(0.15)
	var dis := n.duplicate()
	dis.bg_color = Color(0.1, 0.09, 0.08, 0.7)
	dis.border_color = Color(0.3, 0.27, 0.22)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.98, 0.9, 0.75))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.38))
	b.pressed.connect(cb)
	return b

func _build_hud() -> void:
	var post := CanvasLayer.new()
	post.layer = 0
	add_child(post)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment(){
	float d = distance(UV, vec2(0.5, 0.45));
	float v = smoothstep(0.32, 0.85, d) * 0.85;
	float g = (h(UV * 731.0 + fract(TIME * 7.0)) - 0.5) * 0.06;
	COLOR = vec4(vec3(0.0) + g, v + abs(g));
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vig.material = sm
	post.add_child(vig)

	hud = CanvasLayer.new()
	hud.layer = 1
	add_child(hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.6, 0, 0, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	# Placas dos jogadores
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 12
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	for i in 2:
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		pc.add_child(v)
		var name_l := _lbl("", 13, GOLD, true)
		var stats_l := _lbl("", 19, Color(0.95, 0.9, 0.82), true)
		v.add_child(name_l)
		v.add_child(stats_l)
		if i == 1:
			name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			stats_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top.add_child(pc)
		plates.append([pc, name_l, stats_l])

	phase_lbl = _lbl("", 14, Color(0.9, 0.8, 0.6), true)
	phase_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	phase_lbl.offset_top = 86
	phase_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_lbl.add_theme_constant_override("outline_size", 6)
	phase_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(phase_lbl)

	toast_lbl = _lbl("", 22, Color(1, 0.93, 0.8), true)
	toast_lbl.set_anchors_preset(Control.PRESET_CENTER)
	toast_lbl.offset_left = -260
	toast_lbl.offset_right = 260
	toast_lbl.offset_top = -40
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_lbl.add_theme_constant_override("outline_size", 10)
	toast_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_lbl.modulate.a = 0
	toast_lbl.add_theme_stylebox_override("normal", _panel_style(Color(0.86, 0.68, 0.38, 0.5), 0.88))
	toast_lbl.offset_left = -190
	toast_lbl.offset_right = 190
	toast_lbl.add_theme_font_size_override("font_size", 18)
	root.add_child(toast_lbl)

	# Pilha
	stack_panel = PanelContainer.new()
	stack_panel.add_theme_stylebox_override("panel", _panel_style(GOLD))
	stack_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stack_panel.offset_left = -170
	stack_panel.offset_right = 170
	stack_panel.offset_top = 140
	stack_panel.visible = false
	root.add_child(stack_panel)
	var sv := VBoxContainer.new()
	stack_panel.add_child(sv)
	sv.add_child(_lbl("PILHA", 12, GOLD, true))
	stack_list = _lbl("", 14)
	stack_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack_list.custom_minimum_size = Vector2(300, 0)
	sv.add_child(stack_list)
	pass_btn = _btn("PASSAR", _on_pass)
	sv.add_child(pass_btn)

	hint_lbl = _lbl("", 14, Color(0.85, 0.78, 0.66))
	hint_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_lbl.offset_left = -260
	hint_lbl.offset_right = 260
	hint_lbl.offset_top = 112
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_constant_override("outline_size", 6)
	hint_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_lbl)

	action_btn = _btn("ENCERRAR TURNO", _on_action)
	action_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_btn.offset_left = -196
	action_btn.offset_right = -14
	action_btn.offset_top = -66
	action_btn.offset_bottom = -14
	action_btn.visible = false
	root.add_child(action_btn)

	# Prompt de alvo
	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", _panel_style(GOLD))
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prompt_panel.offset_left = -200
	prompt_panel.offset_right = 200
	prompt_panel.offset_top = 112
	prompt_panel.visible = false
	root.add_child(prompt_panel)
	var ph := HBoxContainer.new()
	prompt_panel.add_child(ph)
	prompt_lbl = _lbl("", 16, Color(1, 0.92, 0.75), true)
	prompt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ph.add_child(prompt_lbl)
	var cb := _btn("CANCELAR", func(): target_chosen.emit(null), false)
	cb.custom_minimum_size = Vector2(110, 40)
	ph.add_child(cb)

	# Inspeção de carta
	inspect = ColorRect.new()
	(inspect as ColorRect).color = Color(0, 0, 0, 0.78)
	inspect.set_anchors_preset(Control.PRESET_FULL_RECT)
	inspect.visible = false
	inspect.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_inspect())
	root.add_child(inspect)
	var iv := VBoxContainer.new()
	iv.set_anchors_preset(Control.PRESET_FULL_RECT)
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	iv.add_theme_constant_override("separation", 12)
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect.add_child(iv)
	insp_tex = TextureRect.new()
	insp_tex.custom_minimum_size = Vector2(340, 464)
	insp_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	insp_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	insp_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iv.add_child(insp_tex)
	insp_title = _lbl("", 22, GOLD, true)
	insp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(insp_title)
	insp_text = _lbl("", 16)
	insp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	insp_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	insp_text.custom_minimum_size = Vector2(460, 0)
	insp_text.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	iv.add_child(insp_text)
	insp_btns = HBoxContainer.new()
	insp_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	insp_btns.add_theme_constant_override("separation", 12)
	iv.add_child(insp_btns)

	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color(0.02, 0.012, 0.01, 0.94)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	root.add_child(overlay)

func _toast(msg: String) -> void:
	toast_lbl.text = msg
	var t := toast_lbl.create_tween()
	t.tween_property(toast_lbl, "modulate:a", 1.0, 0.15)
	t.tween_interval(1.1)
	t.tween_property(toast_lbl, "modulate:a", 0.0, 0.4)

func _ui() -> void:
	if players.is_empty():
		return
	for i in 2:
		var p: Dictionary = players[i]
		var pl: Array = plates[i]
		var pc: PanelContainer = pl[0]
		pc.add_theme_stylebox_override("panel", _panel_style(GOLD if active == i else Color(0.35, 0.3, 0.25)))
		(pl[1] as Label).text = ("VOCÊ · " if i == 0 else "CPU · ") + p.name.to_upper()
		(pl[2] as Label).text = "♥ %d/%d   ¢ %d   ✦ %d/%d" % [max(p.hp, 0), _max_hp(p), p.coins, p.soul_n, D.SOULS_TO_WIN]
	var me: Dictionary = players[0]
	phase_lbl.text = ("—  SEU TURNO  —" if active == 0 else "—  TURNO DE %s  —" % players[active].name.to_upper()) if not game_over else ""
	# Pilha
	stack_panel.visible = not stack.is_empty()
	var lines := []
	for i in range(stack.size() - 1, -1, -1):
		lines.append(("▸ " if i == stack.size() - 1 else "   ") + _entry_text(stack[i]))
	stack_list.text = "\n".join(lines)
	pass_btn.visible = waiting_priority
	# Botão de ação
	action_btn.visible = false
	if active == 0 and not game_over and targeting == "":
		if awaiting_roll:
			action_btn.visible = true
			action_btn.text = "ROLAR ATAQUE"
			action_btn.disabled = busy or not stack.is_empty()
		elif _human_idle():
			action_btn.visible = true
			action_btn.text = "ENCERRAR TURNO"
			action_btn.disabled = false
	# Dica
	var hint := ""
	if waiting_priority:
		hint = "Você tem prioridade — responda ou passe."
	elif awaiting_roll:
		hint = "Combate em andamento. Use itens ou role de novo."
	elif _human_idle():
		var parts := []
		if me.attacks > 0: parts.append("toque num monstro para atacar")
		if me.loot_plays > 0 and not me.hand.is_empty(): parts.append("jogue um loot")
		if not me.bought and me.coins >= D.SHOP_PRICE: parts.append("compre na loja")
		hint = ", ".join(parts)
		if hint != "": hint = hint[0].to_upper() + hint.substr(1) + "."
	hint_lbl.text = hint
	_update_monster_labels()

func _entry_text(e: Dictionary) -> String:
	if e.kind == "roll":
		var v: int = e.value + e.bonus
		return "%s rolou %d%s — %s" % [e.owner.name, v, " (+%d)" % e.bonus if e.bonus else "", e.name]
	return "%s: %s" % [e.owner.name, e.name]

func _float3d(txt: String, pos: Vector3, col: Color) -> void:
	var l := _label3d(txt, 64, col)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 18
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.position = pos + Vector3(0, 0.3, 0)
	l.no_depth_test = true
	table.add_child(l)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", pos.y + 1.0, 1.0).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.5)
	t.chain().tween_callback(l.queue_free)

func _cam_shake(amt := 0.08) -> void:
	var t := create_tween()
	for i in 6:
		t.tween_property(cam, "position", cam_base + Vector3(randf_range(-amt, amt), randf_range(-amt, amt), 0), 0.035)
	t.tween_property(cam, "position", cam_base, 0.05)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

# =====================================================================
# SELEÇÃO / FIM
# =====================================================================
func _show_select() -> void:
	overlay.visible = true
	for c in overlay.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	overlay.add_child(v)
	var t1 := _lbl("THE BINDING OF ISAAC", 16, GOLD, true)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)
	var t2 := _lbl("FOUR SOULS", 46, Color(0.95, 0.9, 0.8), true)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)
	var t3 := _lbl("Escolha seu personagem", 16, Color(0.8, 0.72, 0.6))
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t3)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	v.add_child(hb)
	for c in D.CHARACTERS:
		var b := TextureButton.new()
		b.texture_normal = Card3D.tex(c)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(220, 300)
		b.pivot_offset = Vector2(110, 150)
		b.pressed.connect(_new_game.bind(c))
		b.mouse_entered.connect(func(): b.create_tween().tween_property(b, "scale", Vector2(1.05, 1.05), 0.15))
		b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.15))
		hb.add_child(b)
	var t4 := _lbl("Você contra a CPU  ·  primeiro a %d almas vence" % D.SOULS_TO_WIN, 14, Color(0.7, 0.62, 0.52))
	t4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t4)

func _game_end(winner: Dictionary) -> void:
	if game_over:
		return
	game_over = true
	waiting_priority = false
	awaiting_roll = false
	await _wait(1.2)
	overlay.visible = true
	overlay.modulate.a = 0
	overlay.create_tween().tween_property(overlay, "modulate:a", 1.0, 0.6)
	for c in overlay.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	overlay.add_child(v)
	var won: bool = winner.i == 0
	var t := _lbl("VITÓRIA" if won else "DERROTA", 52, GOLD if won else Color(0.8, 0.25, 0.2), true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _lbl("%s reuniu %d almas." % [winner.name, winner.soul_n], 18)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var b := _btn("JOGAR NOVAMENTE", func(): get_tree().reload_current_scene())
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)

# =====================================================================
# SETUP DA PARTIDA
# =====================================================================
func _new_player(i: int, cid: String, bot: bool) -> Dictionary:
	var c: Dictionary = D.CHARACTERS[cid]
	return {"i": i, "char": cid, "name": c.name, "bot": bot, "hp": c.hp, "base_hp": c.hp, "base_atk": c.atk,
		"coins": D.START_COINS, "hand": [], "items": [], "souls": [], "soul_n": 0, "char_card": null,
		"char_tapped": false, "loot_plays": 0, "attacks": 0, "bought": false, "first_roll": true,
		"temp_atk": 0, "temp_hp": 0, "shield": 0, "dead": false}

func _new_game(cid: String) -> void:
	overlay.visible = false
	var other: String = "maggy" if cid == "isaac" else "isaac"
	players = [_new_player(0, cid, false), _new_player(1, other, true)]
	for k in D.LOOT_DECK:
		for n in D.LOOT_DECK[k]:
			loot_ids.append(k)
	loot_ids.shuffle()
	treasure_ids = D.TREASURE_DECK.duplicate()
	treasure_ids.shuffle()
	monster_ids = D.MONSTERS.keys() + D.MONSTER_EXTRA
	monster_ids.shuffle()
	_sync_decks()
	busy = true
	for p in players:
		var cc := Card3D.make(p.char, "charback")
		table.add_child(cc)
		cc.ref = p
		cc.zone = "char"
		cc.transform = Transform3D(FACE_DOWN, Vector3(0, 2.5, -1.0))
		cc.tapped.connect(_on_card_tapped)
		p.char_card = cc
		cc.fly_to(_char_xf(p), 0.6, 0.3)
		var start_item: String = D.CHARACTERS[p.char].item
		_gain_item(p, start_item, Transform3D(FACE_DOWN, Vector3(0, 2.5, -1.0)))
		await _wait(0.3)
	for s in 2:
		_shop_fill(s)
		await _wait(0.2)
	for i in D.START_LOOT:
		for p in players:
			await _draw_loot(p, 1)
	await _refill_slots(true)
	busy = false
	active = 0
	_turn_loop()

func _sync_decks() -> void:
	decks.loot.set_count(loot_ids.size())
	decks.monster.set_count(monster_ids.size())
	decks.treasure.set_count(treasure_ids.size())
	decks.discard.set_count(0)

# =====================================================================
# CARTAS: comprar, posicionar
# =====================================================================
func _draw_loot(p: Dictionary, n := 1) -> void:
	for k in n:
		if loot_ids.is_empty():
			if loot_discard.is_empty():
				return
			loot_ids = loot_discard.duplicate()
			loot_ids.shuffle()
			loot_discard.clear()
			for c in discard_cards:
				c.queue_free()
			discard_cards.clear()
		var id: String = loot_ids.pop_back()
		decks.loot.set_count(loot_ids.size())
		var c := Card3D.make(id, "lootback")
		c.zone = "hand"
		c.ref = p
		table.add_child(c)
		c.transform = decks.loot.top_xf()
		c.tapped.connect(_on_card_tapped)
		c.reparent(hand_root if p.i == 0 else opp_hand_root, true)
		p.hand.append(c)
		_layout_hand(p)
		await _wait(0.16)

func _layout_hand(p: Dictionary) -> void:
	var n: int = p.hand.size()
	for i in n:
		var c: Card3D = p.hand[i]
		if p.i == 0:
			c.fly_to(_hand_xf(i, n, c == selected_card), 0.35, 0.15)
		else:
			c.fly_to(_opp_hand_xf(i, n), 0.35, 0.1)

func _layout_items(p: Dictionary) -> void:
	for i in p.items.size():
		var it: Dictionary = p.items[i]
		(it.card as Card3D).fly_to(_item_xf(p, i), 0.35, 0.1)
	(p.char_card as Card3D).fly_to(_char_xf(p), 0.3, 0.05)

func _layout_stack() -> void:
	var i := 0
	for e in stack:
		if e.get("card") != null:
			(e.card as Card3D).fly_to(_stack_xf(i), 0.35, 0.2)
			i += 1

func _gain_item(p: Dictionary, id: String, from: Transform3D) -> void:
	var c := Card3D.make(id, "itemback" if id in ["d6", "yumheart"] else "treasureback")
	table.add_child(c)
	c.transform = from
	c.zone = "item"
	c.tapped.connect(_on_card_tapped)
	var it := {"id": id, "tapped": false, "card": c, "owner": p}
	c.ref = it
	p.items.append(it)
	if id == "breakfast" or id == "dinner":
		p.hp += 1
	_layout_items(p)

func _discard_card(c: Card3D, to_loot_pile: bool) -> void:
	if c.get_parent() != table:
		c.reparent(table, true)
	c.highlight(false)
	if to_loot_pile:
		loot_discard.append(c.id)
		decks.discard.set_count(loot_discard.size())
		c.zone = "discard"
		discard_cards.append(c)
		c.fly_to(_flat(decks.discard.position + Vector3(randf_range(-0.04, 0.04), 0.015 + loot_discard.size() * 0.004, randf_range(-0.04, 0.04)), randf_range(-0.12, 0.12)), 0.4, 0.3)
		if discard_cards.size() > 8:
			discard_cards.pop_front().queue_free()
	else:
		c.zone = "gone"
		var t := c.fly_to(Transform3D(FACE_UP, Vector3(-3.4, 0.3, -1.0)), 0.5, 0.4)
		t.finished.connect(c.queue_free)

func _shop_fill(s: int) -> void:
	if shop[s] != null or treasure_ids.is_empty():
		return
	var id: String = treasure_ids.pop_back()
	decks.treasure.set_count(treasure_ids.size())
	var c := Card3D.make(id, "treasureback")
	table.add_child(c)
	c.transform = decks.treasure.top_xf()
	c.zone = "shop"
	c.ref = s
	c.tapped.connect(_on_card_tapped)
	shop[s] = c
	c.fly_to(_shop_xf(s), 0.5, 0.4)

# =====================================================================
# MONSTROS
# =====================================================================
func _top(s: int):
	return slots[s].back() if not slots[s].is_empty() else null

func _find_mon(u: int):
	for s in 2:
		var m = _top(s)
		if m != null and m.uid == u:
			return m
	return null

func _make_mon(id: String, s: int, c: Card3D) -> Dictionary:
	var d: Array = D.MONSTERS[id]
	uid += 1
	var l := _label3d("", 40, Color(1, 0.92, 0.85))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 14
	l.outline_modulate = Color(0.1, 0, 0, 0.95)
	l.position = Vector3(0, -Card3D.H / 2 - 0.04, 0.12)
	l.no_depth_test = true
	c.add_child(l)
	return {"id": id, "uid": uid, "hp": d[1], "max": d[1], "eva": d[2], "atk": d[3], "tag": d[8], "slot": s, "card": c, "label": l}

func _update_monster_labels() -> void:
	for s in 2:
		for m in slots[s]:
			var l: Label3D = m.label
			l.visible = m == _top(s)
			l.text = "♥ %d/%d" % [max(m.hp, 0), m.max]
			var c: Card3D = m.card
			var fighting: bool = in_combat and combat.get("uid", -1) == m.uid
			if targeting == "":
				c.highlight(fighting, Color(1, 0.25, 0.2))

func _eva(m: Dictionary) -> int:
	return m.eva + (1 if m.tag == "larry" and m.hp <= 2 else 0)

# Revela cartas do deck até os espaços estarem ocupados. Eventos resolvem na hora.
func _refill_slots(setup := false) -> void:
	for s in 2:
		while slots[s].is_empty() and not monster_ids.is_empty() and not game_over:
			await _reveal_into(s, setup)

func _reveal_into(s: int, setup := false) -> void:
	var id: String = monster_ids.pop_back()
	decks.monster.set_count(monster_ids.size())
	var c := Card3D.make(id, "monsterback")
	table.add_child(c)
	c.transform = decks.monster.top_xf()
	c.zone = "monster"
	c.tapped.connect(_on_card_tapped)
	var depth: int = slots[s].size()
	await c.fly_to(_slot_xf(s, depth), 0.55, 0.5).finished
	c.punch(0.1)
	if D.EVENTS.has(id):
		if setup:
			# Na preparação, eventos voltam para o fundo do deck.
			monster_ids.push_front(id)
			decks.monster.set_count(monster_ids.size())
			_discard_card(c, false)
			return
		_toast("Evento: " + D.EVENTS[id][0])
		await _wait(0.5)
		var p: Dictionary = players[active]
		var on_res := func(v: int) -> void:
			var gain: int = [1, 1, 3, 3, 6, 6][v - 1]
			_gain_coins(p, gain, c.global_position)
		await _roll(p, "Chest", on_res)
		_discard_card(c, false)
		return
	var m := _make_mon(id, s, c)
	c.ref = m
	slots[s].append(m)
	_ui()

func _damage_monster(m: Dictionary, n: int, by: Dictionary) -> void:
	if _find_mon(m.uid) == null or n <= 0:
		return
	if m.tag == "duke" and randi_range(1, 6) == 1:
		_toast("The Duke of Flies previne o dano!")
		return
	m.hp -= n
	var c: Card3D = m.card
	c.punch(0.2)
	c.shake()
	_float3d("-%d" % n, c.global_position, Color(1, 0.85, 0.3))
	if m.hp <= 0:
		_kill_monster(m, by)
	_ui()

func _kill_monster(m: Dictionary, by: Dictionary) -> void:
	var s: int = m.slot
	slots[s].erase(m)
	var d: Array = D.MONSTERS[m.id]
	if in_combat and combat.get("uid", -1) == m.uid:
		in_combat = false
		if awaiting_roll:
			roll_requested.emit()
	_toast("%s derrotou %s!" % [by.name, d[0]])
	var c: Card3D = m.card
	(m.label as Label3D).queue_free()
	c.highlight(false)
	if d[4] > 0:
		_gain_coins(by, d[4], c.global_position)
	if d[7] > 0:
		by.soul_n += d[7]
		by.souls.append(c)
		c.zone = "soul"
		c.ref = by
		c.fly_to(_soul_xf(by, by.souls.size() - 1), 0.7, 0.8)
		_float3d("+%d ALMA" % d[7], c.global_position, Color(0.75, 0.9, 1))
	else:
		_discard_card(c, false)
	if m.tag == "boom":
		for p in players:
			_damage_player(p, 1, null)
	if m.tag == "bony":
		_damage_player(by, 1, null)
	_ui()
	if by.soul_n >= D.SOULS_TO_WIN:
		_game_end(by)
		return
	_kill_rewards(by, d)

func _kill_rewards(by: Dictionary, d: Array) -> void:
	await _wait(0.3)
	if d[5] > 0:
		await _draw_loot(by, d[5])
	for i in d[6]:
		if not treasure_ids.is_empty():
			var id: String = treasure_ids.pop_back()
			decks.treasure.set_count(treasure_ids.size())
			_gain_item(by, id, decks.treasure.top_xf())
	_ui()

# =====================================================================
# JOGADORES
# =====================================================================
func _n(p: Dictionary, id: String) -> int:
	var k := 0
	for it in p.items:
		if it.id == id:
			k += 1
	return k

func _max_hp(p: Dictionary) -> int:
	return p.base_hp + _n(p, "breakfast") + _n(p, "dinner") + p.temp_hp

func _atk(p: Dictionary) -> int:
	var a: int = p.base_atk + _n(p, "brimstone") + p.temp_atk
	if p.first_roll:
		a += _n(p, "championbelt") + _n(p, "polydactyly")
	return a

func _opp(p: Dictionary) -> Dictionary:
	return players[1 - p.i]

func _gain_coins(p: Dictionary, n: int, at: Vector3) -> void:
	p.coins += n
	_float3d("+%d¢" % n, at, Color(1, 0.82, 0.3))
	_ui()

func _damage_player(p: Dictionary, n: int, src) -> void:
	if p.dead or n <= 0 or game_over:
		return
	if p.shield > 0:
		p.shield -= 1
		_float3d("Prevenido", (p.char_card as Card3D).global_position, Color(0.6, 0.85, 1))
		return
	p.hp -= n
	var cc: Card3D = p.char_card
	cc.punch(0.2)
	_float3d("-%d ♥" % n, cc.global_position, Color(1, 0.25, 0.2))
	if p.i == 0:
		flash.color.a = 0.4
		flash.create_tween().tween_property(flash, "color:a", 0.0, 0.45)
		_cam_shake()
	else:
		cc.shake()
	if src != null and src.tag == "lifesteal":
		src.hp = min(src.max, src.hp + 1)
	if p.hp <= 0:
		_kill_player(p)
	_ui()

func _kill_player(p: Dictionary) -> void:
	p.dead = true
	p.hp = 0
	_toast("%s MORREU" % p.name.to_upper())
	if p.i == 0:
		flash.color = Color(0, 0, 0, 0.85)
		flash.create_tween().tween_property(flash, "color:a", 0.0, 1.4)
	# Penalidades: 1¢, 1 loot, 1 item não-eterno, tudo virado.
	p.coins = max(0, p.coins - 1)
	if not p.hand.is_empty():
		var c: Card3D = p.hand.pick_random()
		p.hand.erase(c)
		if c == selected_card:
			selected_card = null
		_discard_card(c, true)
		_layout_hand(p)
	var lose: Array = p.items.filter(func(it): return not D.ITEMS[it.id][3])
	if not lose.is_empty():
		var it: Dictionary = lose.pick_random()
		p.items.erase(it)
		_discard_card(it.card, false)
	for it in p.items:
		it.tapped = true
	p.char_tapped = true
	_layout_items(p)
	if in_combat and is_same(combat.p, p):
		in_combat = false
		if awaiting_roll:
			roll_requested.emit()
	if p.i == active:
		turn_over = true
		for e in stack:
			if e.get("card") != null and e.kind == "loot":
				_discard_card(e.card, true)
			elif e.get("card") != null:
				(e.card as Card3D).queue_free()
		stack.clear()
		if p.i == 0:
			_force_end_turn()

func _force_end_turn() -> void:
	while stack_running or busy:
		await _wait(0.1)
	await _wait(0.4)
	end_turn_requested.emit()

# =====================================================================
# TURNOS
# =====================================================================
func _turn_loop() -> void:
	while not game_over:
		var p: Dictionary = players[active]
		turn_over = false
		await _start_phase(p)
		if game_over: break
		if p.bot:
			await _bot_turn(p)
		else:
			_ui()
			await end_turn_requested
		if game_over: break
		await _end_phase(p)
		active = 1 - active

func _start_phase(p: Dictionary) -> void:
	_toast("Turno de %s" % p.name if p.bot else "Seu turno")
	for it in p.items:
		it.tapped = false
	p.char_tapped = false
	p.loot_plays = 1 + _n(p, "polydactyly")
	p.attacks = 1 + _n(p, "championbelt")
	p.bought = false
	p.first_roll = true
	_layout_items(p)
	_ui()
	await _wait(0.5)
	await _draw_loot(p, 1)
	_ui()

func _end_phase(p: Dictionary) -> void:
	awaiting_roll = false
	in_combat = false
	# Descarte até o limite de mão
	while p.hand.size() > D.HAND_LIMIT:
		var c: Card3D = p.hand.pop_front()
		_discard_card(c, true)
	# Fim de turno: todos curam, monstros também.
	for q in players:
		q.temp_atk = 0
		q.temp_hp = 0
		q.shield = 0
		q.dead = false
		q.hp = _max_hp(q)
	for s in 2:
		for m in slots[s]:
			m.hp = m.max
	_layout_hand(p)
	_ui()
	await _refill_slots()
	await _wait(0.3)

func _human_idle() -> bool:
	return active == 0 and not players[0].bot and stack.is_empty() and not busy and not in_combat \
		and not game_over and not turn_over and targeting == "" and not players[0].dead

# Pode o humano agir agora (ativar itens / jogar loot)?
func _human_has_priority() -> bool:
	if game_over or busy or targeting != "" or players[0].dead:
		return false
	if waiting_priority:
		return true
	return active == 0 and stack.is_empty() and (not in_combat or awaiting_roll) and not turn_over

func _human_can_play_loot() -> bool:
	var me: Dictionary = players[0]
	if not _human_has_priority() or me.hand.is_empty():
		return false
	if active == 0:
		return me.loot_plays > 0 or not me.char_tapped
	return not me.char_tapped

# =====================================================================
# PILHA E PRIORIDADE
# =====================================================================
func _push(e: Dictionary) -> void:
	uid += 1
	e.uid = uid
	if not e.has("bonus"):
		e.bonus = 0
	stack.append(e)
	_layout_stack()
	_ui()
	if waiting_priority:
		priority_event.emit("push")

func _run_stack() -> void:
	if stack_running:
		return
	stack_running = true
	while not stack.is_empty() and not game_over:
		_ui()
		await _wait(0.35)
		if _human_relevant():
			waiting_priority = true
			_ui()
			var r: String = await priority_event
			waiting_priority = false
			if r == "push":
				continue
		if game_over:
			break
		if _bot_respond():
			await _wait(0.5)
			continue
		if stack.is_empty():
			break
		var e: Dictionary = stack.pop_back()
		_ui()
		await _resolve(e)
		_layout_stack()
	stack_running = false
	_ui()
	if not game_over:
		await _refill_slots()

func _on_pass() -> void:
	if waiting_priority:
		priority_event.emit("pass")

# O humano só recebe prioridade quando tem uma resposta que importa (auto-pass inteligente).
func _human_relevant() -> bool:
	var me: Dictionary = players[0]
	if stack.is_empty() or me.dead:
		return false
	var top: Dictionary = stack.back()
	var loot_ok: bool = (active == 0 and me.loot_plays > 0) or not me.char_tapped
	if top.kind == "roll":
		for it in me.items:
			if not it.tapped and it.id in ["d6", "spoon"]:
				return true
		if loot_ok and me.hand.any(func(c): return c.id == "diceshard"):
			return true
	if not is_same(top.owner, me) and top.kind in ["loot", "ability"]:
		if loot_ok and me.hand.any(func(c): return c.id == "butterbean"):
			return true
	if _threatens(top, me):
		for it in me.items:
			if not it.tapped and it.id == "yumheart":
				return true
		if loot_ok and me.hand.any(func(c): return c.id == "soulheart"):
			return true
	return false

func _threatens(e: Dictionary, p: Dictionary) -> bool:
	if e.kind == "roll" and e.get("attack", false) and is_same(e.owner, p):
		return not _roll_hits(e)
	if e.get("target") is Dictionary and e.target.get("type", "") == "player" and is_same(e.target.p, p):
		return true
	return false

func _roll_hits(e: Dictionary) -> bool:
	var m = _find_mon(e.get("mon_uid", -1))
	if m == null:
		return false
	return e.value + e.bonus + _n(e.owner, "meat") + _n(e.owner, "synthoil") >= _eva(m)

func _top_roll():
	for i in range(stack.size() - 1, -1, -1):
		if stack[i].kind == "roll":
			return stack[i]
	return null

func _top_cancelable(except_uid := -1):
	for i in range(stack.size() - 1, -1, -1):
		var e: Dictionary = stack[i]
		if e.kind in ["loot", "ability"] and e.uid != except_uid:
			return e
	return null

func _resolve(e: Dictionary) -> void:
	match e.kind:
		"roll":
			var v: int = clampi(e.value + e.bonus, 1, 6) if not e.get("attack", false) else e.value + e.bonus
			await e.on_res.call(v)
		"loot":
			_discard_card(e.card, true)
			if e.get("valid") != null and not e.valid.call():
				_toast("%s não tem efeito" % e.name)
			else:
				await e.fn.call()
		"ability":
			if e.get("card") != null:
				var c: Card3D = e.card
				var t := c.create_tween()
				t.tween_property(c, "scale", Vector3.ONE * 0.01, 0.25)
				t.tween_callback(c.queue_free)
			if e.get("valid") != null and not e.valid.call():
				_toast("%s não tem efeito" % e.name)
			else:
				await e.fn.call()
	_ui()

# ---------- Rolagens ----------
func _roll(p: Dictionary, name: String, on_res: Callable, extra := {}) -> void:
	var v := _rand_roll(p)
	busy = true
	_ui()
	var from := (p.char_card as Card3D).position + Vector3(0, 1.0, -0.3 if p.i == 0 else 0.3)
	var to := Vector3(randf_range(-0.3, 0.3), Dice3D.S / 2, randf_range(-1.0, -0.85))
	await dice.throw(v, from, to)
	busy = false
	var e := {"kind": "roll", "owner": p, "name": name, "value": v, "on_res": on_res}
	e.merge(extra)
	_roll_triggers(p, v)
	_push(e)
	await _run_stack()

func _rand_roll(p: Dictionary) -> int:
	var v := randi_range(1, 6)
	if v == 1 and _n(p, "sacredheart") > 0:
		_toast("Sacred Heart: 1 vira 6")
		v = 6
	return v

func _roll_triggers(p: Dictionary, v: int) -> void:
	for q in players:
		if v == 1:
			for i in _n(q, "relic"):
				_draw_loot(q, 1)
			for it in q.items:
				if it.id == "sackofpennies" and it.tapped:
					it.tapped = false
					_layout_items(q)
		if v == 6 and not is_same(q, p):
			for i in _n(q, "momsrazor"):
				_damage_player(p, 1, null)

func _reroll(e: Dictionary) -> void:
	if not stack.has(e):
		return
	var v := _rand_roll(e.owner)
	e.value = v
	_toast("Rerrolou: %d" % v)
	var to := dice.position + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.1, 0.1))
	await dice.throw(v, dice.position + Vector3(0, 0.8, 0.3), to)
	_roll_triggers(e.owner, v)
	_ui()

# =====================================================================
# AÇÕES (compartilhadas por humano e CPU)
# =====================================================================
func _act_attack(p: Dictionary, s: int) -> void:
	var m = _top(s)
	if m == null or p.attacks <= 0:
		return
	p.attacks -= 1
	in_combat = true
	combat = {"p": p, "uid": m.uid}
	_toast("%s ataca %s" % [p.name, D.MONSTERS[m.id][0]])
	_ui()
	var first := true
	while in_combat and not p.dead and not game_over and _find_mon(combat.uid) != null:
		if not first:
			if p.bot:
				await _wait(0.6)
			else:
				awaiting_roll = true
				_ui()
				await roll_requested
				awaiting_roll = false
				if not in_combat or p.dead or _find_mon(combat.uid) == null:
					break
		first = false
		var mu: int = combat.uid
		var on_res := func(v: int) -> void: _resolve_attack(p, mu, v)
		await _roll(p, "ataque", on_res, {"attack": true, "mon_uid": mu})
	in_combat = false
	awaiting_roll = false
	_ui()

func _resolve_attack(p: Dictionary, mu: int, v: int) -> void:
	var m = _find_mon(mu)
	if m == null or p.dead:
		return
	var total: int = v + _n(p, "meat") + _n(p, "synthoil")
	var raw: int = v
	var dmg := _atk(p)
	p.first_roll = false
	if total >= _eva(m):
		if (m.tag == "immune6" and raw == 6) or (m.tag == "immune45" and (raw == 4 or raw == 5)):
			_toast("%s é imune a essa rolagem" % D.MONSTERS[m.id][0])
			return
		_toast("Acerto! %d de dano" % dmg)
		if _n(p, "brimstone") > 0:
			_damage_player(_opp(p), _n(p, "brimstone"), null)
		_damage_monster(m, dmg, p)
	else:
		var d: int = m.atk
		if m.tag == "dbl1" and raw == 1:
			d *= 2
		if m.tag == "plus2" and raw == 2:
			d += 1
		if m.tag == "chub" and raw == 1:
			m.hp = min(m.max, m.hp + 2)
		_toast("Errou — %s causa %d" % [D.MONSTERS[m.id][0], d])
		(m.card as Card3D).punch(0.12)
		_damage_player(p, d, m)

func _act_buy(p: Dictionary, s: int) -> void:
	if p.bought or p.coins < D.SHOP_PRICE:
		return
	p.coins -= D.SHOP_PRICE
	p.bought = true
	var from: Transform3D
	var id: String
	if s < 0:
		if treasure_ids.is_empty():
			return
		id = treasure_ids.pop_back()
		decks.treasure.set_count(treasure_ids.size())
		from = decks.treasure.top_xf()
	else:
		var c: Card3D = shop[s]
		id = c.id
		from = c.transform
		c.queue_free()
		shop[s] = null
	_toast("%s comprou %s" % [p.name, D.ITEMS[id][0]])
	_gain_item(p, id, from)
	_ui()
	await _wait(0.4)
	if s >= 0:
		_shop_fill(s)

func _act_tap_char(p: Dictionary) -> void:
	if p.char_tapped:
		return
	p.char_tapped = true
	p.loot_plays += 1
	_layout_items(p)
	_ui()

# Joga um loot. `target` já escolhido quando o loot precisa de alvo.
func _act_play_loot(p: Dictionary, c: Card3D, target = null) -> void:
	if p.i == active and p.loot_plays > 0:
		p.loot_plays -= 1
	elif not p.char_tapped:
		p.char_tapped = true
		_layout_items(p)
	else:
		return
	p.hand.erase(c)
	if c == selected_card:
		selected_card = null
	c.reparent(table, true)
	c.zone = "stack"
	_layout_hand(p)
	var id: String = c.id
	var e := {"kind": "loot", "owner": p, "name": D.LOOT[id][0], "card": c, "target": target}
	e.fn = _loot_effect(p, id, target, e)
	if target is Dictionary and target.type == "monster":
		var mu: int = target.m.uid
		e.valid = func() -> bool: return _find_mon(mu) != null
	_toast("%s joga %s" % [p.name, D.LOOT[id][0]])
	_push(e)
	await _run_stack()

func _loot_effect(p: Dictionary, id: String, target, e: Dictionary) -> Callable:
	match id:
		"penny", "twocents", "threecents", "fourcents", "nickel", "dime":
			var amt: int = {"penny": 1, "twocents": 2, "threecents": 3, "fourcents": 4, "nickel": 5, "dime": 10}[id]
			return func() -> void: _gain_coins(p, amt, (p.char_card as Card3D).global_position)
		"bomb", "goldbomb":
			var dmg := 3 if id == "goldbomb" else 1
			return func() -> void: _deal_to_target(target, dmg, p)
		"battery":
			return func() -> void:
				for it in p.items:
					if it.tapped and D.ITEMS[it.id][2] == "tap":
						it.tapped = false
						break
				_layout_items(p)
		"megabattery":
			return func() -> void:
				for it in p.items:
					it.tapped = false
				_layout_items(p)
		"diceshard":
			return func() -> void:
				var r = _top_roll()
				if r != null:
					await _reroll(r)
		"butterbean":
			var tgt = _top_cancelable(-1)
			var tu: int = tgt.uid if tgt != null else -1
			return func() -> void:
				for x in stack:
					if x.uid == tu:
						stack.erase(x)
						if x.get("card") != null:
							_discard_card(x.card, x.kind == "loot")
						_toast("Cancelado: " + x.name)
						break
		"soulheart":
			return func() -> void: p.shield += 1
		"strength":
			return func() -> void:
				p.temp_atk += 1
				p.attacks += 1
		"pills":
			var res := func(v: int) -> void:
				if v <= 2:
					p.temp_atk += 1
					_toast("Pills: +1⚔")
				elif v <= 4:
					p.temp_hp += 1
					p.hp += 1
					_toast("Pills: +1♥")
				else:
					_toast("Pills: ai!")
					_damage_player(p, 1, null)
			return func() -> void: await _roll(p, "Pills!", res)
	return func() -> void: pass

func _deal_to_target(target, dmg: int, by: Dictionary) -> void:
	if target == null:
		return
	if target.type == "monster":
		_damage_monster(target.m, dmg, by)
	else:
		_damage_player(target.p, dmg, null)

func _act_item(p: Dictionary, it: Dictionary, target = null) -> void:
	if it.tapped or D.ITEMS[it.id][2] != "tap":
		return
	var id: String = it.id
	var e := {"kind": "ability", "owner": p, "name": D.ITEMS[id][0], "target": target}
	match id:
		"d6":
			var r = _top_roll()
			if r == null:
				return
			e.fn = func() -> void: await _reroll(r)
		"spoon":
			var r = _top_roll()
			if r == null:
				return
			e.fn = func() -> void:
				if stack.has(r):
					r.bonus += 1
					_toast("+1 na rolagem")
		"yumheart":
			e.fn = func() -> void: p.shield += 1
		"booksin":
			var res := func(v: int) -> void:
				if v <= 2:
					_gain_coins(p, 1, (p.char_card as Card3D).global_position)
				elif v <= 4:
					await _draw_loot(p, 1)
				else:
					p.temp_hp += 1
					p.hp += 1
			e.fn = func() -> void: await _roll(p, "Book of Sin", res)
		"guppyshead":
			e.fn = func() -> void:
				var o := _opp(p)
				if o.hand.is_empty():
					return
				var c: Card3D = o.hand.pick_random()
				o.hand.erase(c)
				if c == selected_card:
					selected_card = null
				c.reparent(hand_root if p.i == 0 else opp_hand_root, true)
				c.ref = p
				p.hand.append(c)
				_layout_hand(o)
				_layout_hand(p)
		"razorblade":
			var o := _opp(p)
			e.fn = func() -> void: _damage_player(o, 1, null)
		"sackofpennies":
			e.fn = func() -> void: _gain_coins(p, 1, (p.char_card as Card3D).global_position)
	it.tapped = true
	_layout_items(p)
	# Cópia fantasma do item sobe para a pilha.
	var ghost := Card3D.make(id, "treasureback")
	table.add_child(ghost)
	ghost.transform = (it.card as Card3D).transform
	e.card = ghost
	if in_combat and is_same(combat.p, p):
		var m = _find_mon(combat.uid)
		if m != null and m.tag == "gurdyjr":
			_damage_player(p, 1, m)
	_toast("%s ativa %s" % [p.name, D.ITEMS[id][0]])
	_push(e)
	await _run_stack()

# =====================================================================
# INPUT DO HUMANO
# =====================================================================
func _on_action() -> void:
	if awaiting_roll:
		roll_requested.emit()
	elif _human_idle():
		end_turn_requested.emit()

func _on_deck_tapped(_d: Deck3D, kind: String) -> void:
	if targeting != "" or overlay.visible:
		return
	match kind:
		"treasure":
			_open_inspect("treasureback", "Deck de Tesouros", "%d cartas. Compre a carta do topo às cegas por %d¢." % [treasure_ids.size(), D.SHOP_PRICE],
				[["COMPRAR TOPO · 10¢", func(): _close_inspect(); _act_buy(players[0], -1), _human_idle() and not players[0].bought and players[0].coins >= D.SHOP_PRICE]])
		"monster":
			_open_inspect("monsterback", "Deck de Monstros", "%d cartas. Monstros, bosses e eventos." % monster_ids.size(), [])
		"loot":
			_open_inspect("lootback", "Deck de Loot", "%d cartas." % loot_ids.size(), [])
		"discard":
			_open_inspect("lootback", "Descarte", "%d cartas." % loot_discard.size(), [])

func _on_card_tapped(c: Card3D) -> void:
	if overlay.visible or game_over:
		return
	if targeting != "":
		for t in target_valid:
			if t.card == c:
				target_chosen.emit(t)
				return
		return
	var me: Dictionary = players[0]
	match c.zone:
		"hand":
			if not is_same(c.ref, me):
				return
			if selected_card != c:
				selected_card = c
				_layout_hand(me)
			var info: Array = D.LOOT[c.id]
			_open_inspect(c.id, info[0], info[1], [["JOGAR", func(): _close_inspect(); _human_play_loot(c), _human_can_play_loot() and _loot_playable(c.id)]])
		"item":
			var it: Dictionary = c.ref
			var info: Array = D.ITEMS[it.id]
			var btns := []
			if is_same(it.owner, me) and info[2] == "tap":
				btns.append(["ATIVAR", func(): _close_inspect(); _human_item(it), not it.tapped and _human_has_priority() and _item_usable(it.id)])
			_open_inspect(it.id, info[0] + ("  (virado)" if it.tapped else ""), info[1] + ("\nEterno." if info[3] else ""), btns)
		"char":
			var p: Dictionary = c.ref
			var txt := "♥ %d/%d   ⚔ %d   ¢ %d\nVire: jogue um loot adicional (pode ser feito no turno de qualquer jogador)." % [max(p.hp, 0), _max_hp(p), _atk(p), p.coins]
			var btns := []
			if is_same(p, me):
				btns.append(["VIRAR (+1 LOOT)", func(): _close_inspect(); _act_tap_char(me), not me.char_tapped and _human_has_priority() and active == 0])
			_open_inspect(p.char, p.name, txt, btns)
		"monster":
			var m = c.ref
			if m == null or not (m is Dictionary) or not m.has("uid"):
				return
			var d: Array = D.MONSTERS[m.id]
			var txt := "♥ %d/%d   Evasão %d+   ⚔ %d" % [max(m.hp, 0), m.max, _eva(m), m.atk]
			if m.tag != "":
				txt += "\n" + D.TAG_TEXT[m.tag]
			var rew := []
			if d[4]: rew.append("%d¢" % d[4])
			if d[5]: rew.append("loot %d" % d[5])
			if d[6]: rew.append("%d tesouro" % d[6])
			if d[7]: rew.append("%d alma" % d[7])
			txt += "\nRecompensa: " + ", ".join(rew)
			var is_top: bool = _find_mon(m.uid) != null
			_open_inspect(m.id, d[0], txt, [["ATACAR", func(): _close_inspect(); _act_attack(me, m.slot), is_top and _human_idle() and me.attacks > 0]])
		"shop":
			var s: int = c.ref
			var info: Array = D.ITEMS[c.id]
			_open_inspect(c.id, info[0], info[1], [["COMPRAR · 10¢", func(): _close_inspect(); _act_buy(me, s), _human_idle() and not me.bought and me.coins >= D.SHOP_PRICE]])
		"soul":
			_open_inspect(c.id, D.MONSTERS[c.id][0], "Alma de %s." % c.ref.name, [])
		"stack", "discard":
			if D.LOOT.has(c.id):
				_open_inspect(c.id, D.LOOT[c.id][0], D.LOOT[c.id][1], [])

func _loot_playable(id: String) -> bool:
	match D.LOOT[id][2]:
		"roll":
			return _top_roll() != null
		"cancel":
			return _top_cancelable() != null
	return true

func _item_usable(id: String) -> bool:
	if id in ["d6", "spoon"]:
		return _top_roll() != null
	return true

func _human_play_loot(c: Card3D) -> void:
	var me: Dictionary = players[0]
	var target = null
	if D.LOOT[c.id][2] == "any":
		target = await _choose_target("Escolha o alvo de " + D.LOOT[c.id][0])
		if target == null:
			return
	if not _human_can_play_loot():
		return
	await _act_play_loot(me, c, target)

func _human_item(it: Dictionary) -> void:
	await _act_item(players[0], it)

func _open_inspect(tex_id: String, title: String, text: String, btns: Array) -> void:
	inspect.visible = true
	insp_tex.texture = Card3D.tex(tex_id)
	insp_title.text = title
	insp_text.text = text
	for b in insp_btns.get_children():
		b.queue_free()
	for b in btns:
		var bt := _btn(b[0], b[1])
		bt.disabled = not b[2]
		insp_btns.add_child(bt)
	var close := _btn("FECHAR", _close_inspect, false)
	insp_btns.add_child(close)
	insp_tex.pivot_offset = insp_tex.custom_minimum_size / 2
	insp_tex.scale = Vector2(0.85, 0.85)
	insp_tex.create_tween().tween_property(insp_tex, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)

func _close_inspect() -> void:
	inspect.visible = false
	if selected_card != null:
		selected_card = null
		_layout_hand(players[0])

func _choose_target(msg: String):
	target_valid = []
	for s in 2:
		var m = _top(s)
		if m != null:
			target_valid.append({"type": "monster", "m": m, "card": m.card})
	for p in players:
		if not p.dead:
			target_valid.append({"type": "player", "p": p, "card": p.char_card})
	targeting = msg
	prompt_lbl.text = msg
	prompt_panel.visible = true
	for t in target_valid:
		(t.card as Card3D).highlight(true)
	_ui()
	var r = await target_chosen
	for t in target_valid:
		(t.card as Card3D).highlight(false)
	targeting = ""
	prompt_panel.visible = false
	target_valid = []
	_ui()
	return r

# =====================================================================
# CPU
# =====================================================================
func _bot_turn(p: Dictionary) -> void:
	await _wait(0.8)
	# Strength antes de atacar, moedas e bombas oportunas.
	var guard := 0
	while not turn_over and not game_over and guard < 4:
		guard += 1
		var pick := _bot_pick_loot(p)
		if pick.is_empty():
			break
		if p.loot_plays <= 0 and p.char_tapped:
			break
		await _act_play_loot(p, pick.card, pick.get("target"))
		await _wait(0.5)
	# Itens ativos úteis
	for it in p.items.duplicate():
		if turn_over or game_over:
			break
		if it.tapped:
			continue
		var use := false
		match it.id:
			"booksin", "sackofpennies": use = true
			"guppyshead": use = not players[0].hand.is_empty()
			"razorblade": use = players[0].hp <= 1 or randf() < 0.5
		if use:
			await _act_item(p, it)
			await _wait(0.4)
	# Compra
	if not turn_over and not game_over and p.coins >= D.SHOP_PRICE:
		var s := 0 if shop[0] != null else (1 if shop[1] != null else -1)
		await _act_buy(p, s)
		await _wait(0.5)
	# Ataque(s)
	while not turn_over and not game_over and p.attacks > 0 and not p.dead:
		var best := -1
		var best_score := -999.0
		for s in 2:
			var m = _top(s)
			if m == null:
				continue
			var d: Array = D.MONSTERS[m.id]
			var hit_p: float = clampf((7.0 - _eva(m) + _n(p, "meat") + _n(p, "synthoil")) / 6.0, 0.05, 1.0)
			var score: float = d[7] * 6.0 + d[4] * 0.4 + d[5] * 0.8 + d[6] * 2.0 + hit_p * 4.0 - m.hp * 0.8 - m.atk * 0.5
			if score > best_score:
				best_score = score
				best = s
		if best < 0:
			break
		await _act_attack(p, best)
		await _wait(0.6)
	await _wait(0.5)

func _bot_pick_loot(p: Dictionary) -> Dictionary:
	if p.loot_plays <= 0 and p.char_tapped:
		return {}
	for c in p.hand:
		if c.id in ["penny", "twocents", "threecents", "fourcents", "nickel", "dime", "strength", "megabattery"]:
			return {"card": c}
	for c in p.hand:
		if c.id in ["bomb", "goldbomb"]:
			var dmg := 3 if c.id == "goldbomb" else 1
			for s in 2:
				var m = _top(s)
				if m != null and m.hp <= dmg:
					return {"card": c, "target": {"type": "monster", "m": m, "card": m.card}}
			var me: Dictionary = players[0]
			if me.hp <= dmg and not me.dead:
				return {"card": c, "target": {"type": "player", "p": me, "card": me.char_card}}
	return {}

# Resposta da CPU quando tem prioridade. Retorna true se colocou algo na pilha.
func _bot_respond() -> bool:
	var b: Dictionary = players[1]
	if b.dead or stack.is_empty():
		return false
	var top: Dictionary = stack.back()
	if top.kind == "roll" and top.get("attack", false):
		var hits := _roll_hits(top)
		var mine: bool = is_same(top.owner, b)
		var m = _find_mon(top.get("mon_uid", -1))
		var boss: bool = m != null and D.MONSTERS[m.id][7] > 0
		if (mine and not hits) or (not mine and hits and boss and m.hp <= _atk(top.owner)):
			for it in b.items:
				if it.id == "d6" and not it.tapped:
					_act_item(b, it)
					return true
			if mine and top.value + top.bonus + 1 + _n(b, "meat") + _n(b, "synthoil") >= _eva(m):
				for it in b.items:
					if it.id == "spoon" and not it.tapped:
						_act_item(b, it)
						return true
		if mine and not hits and m != null and m.atk >= b.hp:
			for it in b.items:
				if it.id == "yumheart" and not it.tapped and b.shield == 0:
					_act_item(b, it)
					return true
	return false
