extends Node3D
# Four Souls — mesa 2.5D. Você vs. CPU, regras originais (Base Game V2):
# turno = recarregar + loot 1 · ação (1 loot + virar personagem, 1 compra, 1 ataque) · fim (todos curam).
# Pilha LIFO com prioridade, dado na pilha, combate até alguém morrer, penalidade de morte, 4 almas vence.

const D = preload("res://data.gd")
const FACE_UP := Basis(Vector3.RIGHT, -PI / 2)
const FACE_DOWN := Basis(Vector3.RIGHT, PI / 2)
const GOLD := Color(0.86, 0.68, 0.38)

# Comportamentos especiais de monstros, por id (Consultar data.gd MONSTERS[i][8] para o texto).
const MON_TAG := {
	"bigspider": ["extra_attack_death"],
	"blackbony": ["bony_death"],
	"boomfly": ["boom_death"],
	"dankglobin": ["discard2_death"],
	"delirium": ["aura_roll", "delirium_death"],
	"dinga": ["double6_death"],
	"dople": ["echo_right"],
	"eviltwin": ["echo_left"],
	"greedling": ["greedling_death"],
	"hanger": ["shop_expand_death"],
	"hopper": ["immune6"],
	"horf": ["plus2"],
	"keeperhead": ["keeperhead_coin"],
	"leaper": ["dbl1"],
	"momsdeadhand": ["steal_item_death"],
	"momseye": ["lookhand_death"],
	"momshand": ["end6"],
	"mulliboom": ["mulliboom_death"],
	"mulligan": ["monster_expand_death"],
	"portal": ["extra_attack_death"],
	"psyhorf": ["recharge_death"],
	"ragecreep": ["ragecreep_echo"],
	"ringofflies": ["steal3"],
	"stoney": ["aura_roll", "untargetable", "dies_with_others"],
	"swarmofflies": ["selfdmg5"],
	"wizoob": ["soul_destroy_death"],
	"cursedfatty": ["curse_roll5_discard"],
	"cursedgaper": ["curse_roll4"],
	"cursedhorf": ["curse_roll2_dmg2"],
	"cursedkeeperhead": ["curse_roll1_coin"],
	"cursedmomshand": ["curse_roll6_end"],
	"cursedpsyhorf": ["curse_activate_dmg"],
	"holydinga": ["holy_roll6_heal"],
	"holydip": ["holy_roll1_coin"],
	"holykeeperhead": ["holy_roll4_coin"],
	"holymomseye": ["holy_roll2_recharge"],
	"holysquirt": ["holy_roll5_loot"],
	"carrionqueen": ["immune45"],
	"chub": ["chub"],
	"conquest": ["extra_attack_death"],
	"daddylonglegs": ["dll_roll1"],
	"darkone": ["rage_atk"],
	"death": ["death_kill"],
	"envy": ["extra_attack_death"],
	"famine": ["famine_death"],
	"gemini": ["gemini"],
	"gluttony": ["gluttony6"],
	"greed": ["greed_coin"],
	"gurdyjr": ["gurdyjr"],
	"larryjr": ["larry"],
	"lust": ["lust_thorns"],
	"maskofinfamy": ["mask"],
	"megafatty": ["lifesteal"],
	"peep": ["peep_death"],
	"pestilence": ["pestilence_death"],
	"pin": ["immune6"],
	"pride": ["pride_declare"],
	"ragman": ["ragman_death"],
	"scolex": ["scolex_discard"],
	"sloth": ["sloth_death"],
	"bloat": ["bloat_aoe"],
	"duke": ["duke"],
	"thehaunt": ["haunt"],
	"thelamb": ["lamb_soul"],
	"war": ["rage_atk"],
	"wrath": ["wrath_death"],
	"mom": ["dbl1", "monster_expand_death"],
	"satan": ["satan6"],
}

# Itens que são Trinkets (Loot) cujo efeito fica passivo em jogo.
const MONSTER_SLOTS_MAX := 2

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
var autoplay := false
var autoplay_human := false
var autoplay_turns := 0
var targeting := ""
var target_valid: Array = []
var selected_card: Card3D = null
var slot_labels: Array = []
var monster_discard: Array = []
var treasure_discard: Array = []
var bonus_souls_taken := {}
var pending_extra_turn := -1
const GUPPY_ITEMS := ["guppyshead", "guppyspaw", "guppyscollar", "guppyshairball"]
const TRINKET_IDS := ["bloodypenny", "brokenankh", "cainseye", "counterfeitpenny", "curvedhorn", "goldenhorseshoe", "guppyshairball", "purpleheart", "swallowedpenny", "lostsoul"]

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
	if "--autoplay" in OS.get_cmdline_args() or "--autoplay" in OS.get_cmdline_user_args() \
			or "--autoplay-human" in OS.get_cmdline_args() or "--autoplay-human" in OS.get_cmdline_user_args():
		autoplay = true
		autoplay_human = "--autoplay-human" in OS.get_cmdline_args() or "--autoplay-human" in OS.get_cmdline_user_args()
		Engine.time_scale = 8.0
		_new_game(D.CHARACTER_ORDER[randi() % D.CHARACTER_ORDER.size()])
		if autoplay_human:
			_autoplay_human_loop()
		return
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
		_add_slot_label(s)
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
	var n: int = max(slots.size(), 1)
	var x: float = (s - (n - 1) / 2.0) * 1.1
	return _flat(Vector3(x + depth * 0.04, 0.01 + depth * 0.012, -1.55 - depth * 0.04))

func _shop_xf(s: int) -> Transform3D:
	var n: int = max(shop.size(), 1)
	var x: float = (s - (n - 1) / 2.0) * 1.1
	return _flat(Vector3(x, 0.01, -0.3))

func _add_slot_label(s: int) -> void:
	var lbl := _label3d("ESPAÇO %d" % (s + 1), 22, Color(0.95, 0.85, 0.65, 0.25))
	lbl.rotation.x = -PI / 2
	lbl.position = Vector3((s - (max(slots.size(), s + 2) - 1) / 2.0) * 1.1, 0.002, -1.55)
	table.add_child(lbl)
	slot_labels.append(lbl)

func _relayout_slot_labels() -> void:
	var n: int = max(slot_labels.size(), 1)
	for i in slot_labels.size():
		(slot_labels[i] as Label3D).position = Vector3((i - (n - 1) / 2.0) * 1.1, 0.002, -1.55)

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
	var hb := GridContainer.new()
	hb.columns = 4
	hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hb.add_theme_constant_override("h_separation", 10)
	hb.add_theme_constant_override("v_separation", 10)
	v.add_child(hb)
	for c in D.CHARACTER_ORDER:
		var b := TextureButton.new()
		b.texture_normal = Card3D.tex(c)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(118, 160)
		b.pivot_offset = Vector2(59, 80)
		b.tooltip_text = D.CHARACTERS[c].name
		b.pressed.connect(_new_game.bind(c))
		b.mouse_entered.connect(func(): b.create_tween().tween_property(b, "scale", Vector2(1.08, 1.08), 0.15))
		b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.15))
		hb.add_child(b)
	var t4 := _lbl("Você contra a CPU  ·  primeiro a %d almas vence" % D.SOULS_TO_WIN, 14, Color(0.7, 0.62, 0.52))
	t4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t4)

func _game_end(winner: Dictionary) -> void:
	if game_over:
		return
	game_over = true
	if autoplay:
		print("[autoplay] GAME OVER — winner=%s souls=%d after %d turns" % [winner.name, winner.soul_n, autoplay_turns])
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
		"coins": D.START_COINS, "hand": [], "items": [], "trinkets": [], "souls": [], "soul_n": 0, "char_card": null,
		"char_tapped": false, "loot_plays": 0, "attacks": 0, "bought": 0, "buy_limit": 1, "first_roll": true,
		"temp_atk": 0, "temp_hp": 0, "temp_roll": 0, "prevent_full": 0, "prevent_amt": 0, "reduce_to1": false,
		"shield": 0, "curses": [], "state": {}, "dead": false}

func _new_game(cid: String) -> void:
	overlay.visible = false
	var pool := D.CHARACTER_ORDER.duplicate()
	pool.erase(cid)
	var other: String = pool.pick_random()
	players = [_new_player(0, cid, false), _new_player(1, other, true)]
	if autoplay and not autoplay_human:
		players[0].bot = true
	for k in D.LOOT_DECK:
		for n in D.LOOT_DECK[k]:
			loot_ids.append(k)
	loot_ids.shuffle()
	treasure_ids = D.TREASURE_DECK.duplicate()
	treasure_ids.shuffle()
	monster_ids = D.MONSTERS.keys()
	monster_ids.shuffle()
	slots = [[], []]
	shop = [null, null]
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
		if p.char == "eden":
			# Eden: olha as 3 do topo de tesouros, escolhe 1 (ganha eterno); resto ao fundo.
			var opts: Array = []
			for i in 3:
				if not treasure_ids.is_empty():
					opts.append(treasure_ids.pop_back())
			decks.treasure.set_count(treasure_ids.size())
			var chosen: String = opts[0] if not opts.is_empty() else ""
			if opts.size() > 1:
				if p.i == 0 and not p.bot and not autoplay:
					chosen = await _choose_card(opts, "Eden — escolha seu item inicial")
				else:
					chosen = opts.pick_random()
			for o in opts:
				if o != chosen:
					treasure_ids.push_front(o)
			decks.treasure.set_count(treasure_ids.size())
			if chosen != "":
				_gain_item(p, chosen, Transform3D(FACE_DOWN, Vector3(0, 2.5, -1.0)), true)
		else:
			var start_item: String = str(D.CHARACTERS[p.char].item)
			_gain_item(p, start_item, Transform3D(FACE_DOWN, Vector3(0, 2.5, -1.0)))
		await _wait(0.3)
	for s in shop.size():
		_shop_fill(s)
		await _wait(0.2)
	for i in D.START_LOOT:
		for p in players:
			await _draw_loot(p, 1)
	await _refill_slots(true)
	busy = false
	active = 0
	_turn_loop()

# Escolha visual simples entre algumas cartas (usada por Eden).
func _choose_card(ids: Array, title: String) -> String:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	var result := [""]
	var done := [false]
	for id in ids:
		var b := TextureButton.new()
		b.texture_normal = Card3D.tex(id)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(150, 205)
		b.pressed.connect(func(): result[0] = id; done[0] = true)
		hb.add_child(b)
	_open_custom_panel(title, hb)
	while not done[0]:
		await _wait(0.05)
	_close_inspect()
	return result[0]

# Painel modal genérico (usado para escolhas de setup).
func _open_custom_panel(title: String, content: Control) -> void:
	inspect.visible = true
	insp_tex.texture = null
	insp_title.text = title
	insp_text.text = ""
	for b in insp_btns.get_children():
		b.queue_free()
	_clear_custom_panel()
	var holder := insp_text.get_parent()
	holder.set_meta("custom", content)
	holder.add_child(content)
	holder.move_child(content, 1)

# Libera o conteúdo de painel personalizado, se houver.
func _clear_custom_panel() -> void:
	var holder := insp_text.get_parent()
	if holder.has_meta("custom") and holder.get_meta("custom") != null:
		var c = holder.get_meta("custom")
		holder.set_meta("custom", null)
		if is_instance_valid(c):
			c.queue_free()

func _sync_decks() -> void:
	decks.loot.set_count(loot_ids.size())
	decks.monster.set_count(monster_ids.size())
	decks.treasure.set_count(treasure_ids.size())
	decks.discard.set_count(0)

# =====================================================================
# CARTAS: comprar, posicionar
# =====================================================================
func _draw_loot(p: Dictionary, n := 1) -> void:
	if bool(p.state.get("double_loot", false)):
		n *= 2
	for k in n:
		if bool(p.state.get("compost", false)) and not loot_discard.is_empty():
			var did: String = loot_discard.pop_back()
			decks.discard.set_count(loot_discard.size())
			_loot_to_hand(p, did)
			await _wait(0.16)
			continue
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
		_loot_to_hand(p, id)
		await _wait(0.16)
	_check_bonus_souls()

func _loot_to_hand(p: Dictionary, id: String) -> void:
	var c := Card3D.make(id, "lootback")
	c.zone = "hand"
	c.ref = p
	table.add_child(c)
	c.transform = decks.loot.top_xf()
	c.tapped.connect(_on_card_tapped)
	c.reparent(hand_root if p.i == 0 else opp_hand_root, true)
	p.hand.append(c)
	_layout_hand(p)

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

func _gain_item(p: Dictionary, id: String, from: Transform3D, eternal := false) -> void:
	var c := Card3D.make(id, "itemback" if D.STARTING_ITEMS.has(id) else "treasureback")
	table.add_child(c)
	c.transform = from
	c.zone = "item"
	c.tapped.connect(_on_card_tapped)
	var it := {"id": id, "tapped": false, "card": c, "owner": p, "eternal": eternal or D.ITEMS[id][3], "counters": 0}
	if id == "thedeadcat":
		it.counters = 9
	c.ref = it
	p.items.append(it)
	if id == "breakfast" or id == "dinner":
		p.hp += 1
	if id == "momsshovel":
		it.tapped = true  # entra em jogo desativado
	_layout_items(p)

func _is_eternal(it: Dictionary) -> bool:
	return bool(it.get("eternal", false)) or bool(D.ITEMS[it.id][3])

func _item_of(p: Dictionary, id: String):
	for it in p.items:
		if it.id == id:
			return it
	return null

func _nt(p: Dictionary, id: String) -> int:
	var k := 0
	for t in p.trinkets:
		if t == id:
			k += 1
	return k

func _gain_trinket(p: Dictionary, id: String) -> void:
	p.trinkets.append(id)
	if id == "lostsoul":
		# Lost Soul vira uma alma ao entrar em jogo.
		p.trinkets.erase(id)
		p.soul_n += 1
		_float3d("+1 ALMA", (p.char_card as Card3D).global_position, Color(0.75, 0.9, 1))
	_ui()

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
	for s in slots.size():
		var m = _top(s)
		if m != null and m.uid == u:
			return m
	return null

func _all_mons() -> Array:
	var out := []
	for s in slots.size():
		for m in slots[s]:
			out.append(m)
	return out

func _has_tag(m: Dictionary, tag: String) -> bool:
	return (m.get("tags", []) as Array).has(tag)

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
	return {"id": id, "uid": uid, "hp": d[1], "max": d[1], "eva": d[2], "atk": d[3],
		"slot": s, "card": c, "label": l, "tags": (MON_TAG.get(id, []) as Array).duplicate(),
		"temp_atk": 0, "temp_eva": 0, "hits": 0, "reward_kind": d[9], "text": d[8], "double": false, "prevent_full": 0}

func _update_monster_labels() -> void:
	for s in slots.size():
		for m in slots[s]:
			var l: Label3D = m.label
			l.visible = m == _top(s)
			l.text = "♥ %d/%d" % [max(m.hp, 0), m.max]
			var c: Card3D = m.card
			var fighting: bool = in_combat and combat.get("uid", -1) == m.uid
			if targeting == "":
				c.highlight(fighting, Color(1, 0.25, 0.2))

func _eva(m: Dictionary) -> int:
	var e: int = m.eva + int(m.get("temp_eva", 0))
	if _has_tag(m, "larry") and m.hp <= 2:
		e += 1
	if _has_tag(m, "mask") and m.hp <= 1:
		e += 2
	for s in slots.size():
		for o in slots[s]:
			if _has_tag(o, "aura_roll"):
				e += 1
	var ap: Dictionary = players[active]
	if _n(ap, "babyhaunt") > 0 or (ap.curses as Array).has("curseoftheblind"):
		e += 1
	return e

func _mon_atk(m: Dictionary) -> int:
	return m.atk + int(m.get("temp_atk", 0))

# ---------- Expansões de espaço ----------
func _expand_monster_slots(n: int) -> void:
	for i in n:
		slots.append([])
		_add_slot_label(slots.size() - 1)
	_relayout_slot_labels()
	_ui()

func _expand_shop_slots(n: int) -> void:
	for i in n:
		shop.append(null)
	_ui()

# Revela cartas do deck até os espaços estarem ocupados. Eventos resolvem na hora.
func _refill_slots(setup := false) -> void:
	for s in slots.size():
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
		await _wait(0.4)
		await _event_resolve(id, c)
		_discard_card(c, false)
		return
	var m := _make_mon(id, s, c)
	c.ref = m
	slots[s].append(m)
	_ui()

func _gain_treasure(p: Dictionary, n := 1) -> void:
	for i in n:
		if treasure_ids.is_empty():
			return
		var id: String = treasure_ids.pop_back()
		decks.treasure.set_count(treasure_ids.size())
		_gain_item(p, id, decks.treasure.top_xf())
		await _wait(0.05)

func _search_treasure(match_ids: Array) -> String:
	for i in treasure_ids.size():
		if match_ids.has(treasure_ids[i]):
			var id: String = treasure_ids[i]
			treasure_ids.remove_at(i)
			decks.treasure.set_count(treasure_ids.size())
			return id
	return ""

func _force_discard(p: Dictionary, n: int) -> void:
	for i in n:
		if p.hand.is_empty():
			break
		var c: Card3D = p.hand.pick_random()
		p.hand.erase(c)
		if c == selected_card:
			selected_card = null
		_discard_card(c, true)
	_layout_hand(p)
	_ui()

func _lose_coins(p: Dictionary, n: int) -> void:
	var lost: int = min(p.coins, n)
	p.coins -= lost
	_float3d("-%d¢" % lost, (p.char_card as Card3D).global_position, Color(1, 0.4, 0.3))
	_ui()

func _recharge_first(p: Dictionary) -> bool:
	for it in p.items:
		if it.tapped:
			it.tapped = false
			_layout_items(p)
			return true
	return false

func _recharge_all(p: Dictionary) -> void:
	for it in p.items:
		it.tapped = false
	_layout_items(p)

# ============ EVENTOS ============
func _event_resolve(id: String, c: Card3D) -> void:
	var p: Dictionary = players[active]
	match id:
		"chest":
			await _roll(p, "Chest", func(v: int) -> void: _gain_coins(p, [1, 1, 3, 3, 6, 6][v - 1], c.global_position))
		"chest_2":
			await _roll(p, "Chest", func(v: int) -> void: await _draw_loot(p, [1, 1, 2, 2, 3, 3][v - 1]))
		"cursedchest":
			await _roll(p, "Cursed Chest", func(v: int) -> void:
				if v <= 3: _damage_player(p, 1, null)
				elif v <= 5: _damage_player(p, 2, null)
				else:
					var gid := _search_treasure(GUPPY_ITEMS)
					if gid != "": _gain_item(p, gid, decks.treasure.top_xf()))
		"darkchest":
			await _roll(p, "Dark Chest", func(v: int) -> void:
				if v <= 2: await _draw_loot(p, 1)
				elif v <= 4: _gain_coins(p, 3, c.global_position)
				else: _damage_player(p, 2, null))
		"darkchest_2":
			await _roll(p, "Dark Chest", func(v: int) -> void:
				if v <= 2: _gain_coins(p, 1, c.global_position)
				elif v <= 4: await _draw_loot(p, 2)
				else: _damage_player(p, 2, null))
		"goldchest":
			await _roll(p, "Gold Chest", func(v: int) -> void:
				if v <= 2: await _gain_treasure(p, 1)
				elif v <= 4: await _draw_loot(p, 1)
				else: await _draw_loot(p, 2))
		"secretroom":
			await _roll(p, "Secret Room!", func(v: int) -> void:
				if v == 1: _damage_player(p, 3, null)
				elif v <= 3: _force_discard(p, 2)
				elif v <= 5: _gain_coins(p, 7, c.global_position)
				else: await _gain_treasure(p, 1))
		"trollbombs":
			_damage_player(p, 2, null)
		"megatrollbomb":
			for q in players:
				_damage_player(q, 2, null)
		"icanseeforever":
			await _reorder_top("loot", 6)
			await _draw_loot(p, 1)
		"shopupgrade":
			_expand_shop_slots(2)
			p.attacks += 1
			_toast("Loja ampliada! +1 ataque")
		"weneedtogodeeper":
			for mid in monster_discard.duplicate():
				if not D.EVENTS.has(mid):
					monster_ids.push_back(mid)
					monster_discard.erase(mid)
			decks.monster.set_count(monster_ids.size())
			p.attacks += 1
		"xlfloor":
			_expand_monster_slots(1)
			p.attacks += 1
			_toast("+1 espaço de monstro! +1 ataque")
		"ambush":
			p.attacks += 2
			_toast("Emboscada! Ataque 2 vezes.")
		"greedbang":
			var most := 0
			for q in players:
				most = max(most, q.coins)
			for q in players:
				if q.coins == most:
					_lose_coins(q, q.coins)
		"devildeal":
			await _resolve_devil_deal(p)
		"curseofamnesia", "curseofgreed", "curseofloss", "curseofpain", "curseoftheblind":
			var target: Dictionary = p
			if p.bot:
				target = players[0] if randf() < 0.5 else p
			(target.curses as Array).append(id)
			_toast("%s recebe %s" % [target.name, D.EVENTS[id][0]])
		_:
			pass

func _resolve_devil_deal(p: Dictionary) -> void:
	var choice := 0
	if not p.bot:
		choice = await _choose_option("Devil Deal", ["Descartar (nada)", "Loot 2, 1 de dano", "Tomar 2, buscar Guppy"], 0)
	else:
		choice = 2 if randf() < 0.5 else 1
	match choice:
		0:
			pass
		1:
			await _draw_loot(p, 2)
			_damage_player(p, 1, null)
		2:
			_damage_player(p, 2, null)
			var gid := _search_treasure(GUPPY_ITEMS)
			if gid != "":
				_gain_item(p, gid, decks.treasure.top_xf())

func _choose_option(title: String, options: Array, default_i := 0, bot := false) -> int:
	if bot or autoplay:
		return default_i
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	var res := [default_i]
	var done := [false]
	for i in options.size():
		var b := _btn(options[i], func(): res[0] = i; done[0] = true)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(b)
	_open_custom_panel(title, vb)
	while not done[0]:
		await _wait(0.05)
	_close_inspect()
	return res[0]

# ---------- Dano em monstros ----------
func _damage_monster(m: Dictionary, n: int, by: Dictionary) -> void:
	if _find_mon(m.uid) == null or n <= 0:
		return
	if int(m.get("prevent_full", 0)) > 0:
		m.prevent_full = int(m.prevent_full) - 1
		_float3d("Prevenido", (m.card as Card3D).global_position, Color(0.6, 0.85, 1))
		return
	if _has_tag(m, "duke") and randi_range(1, 6) == 1:
		_toast("The Duke of Flies previne o dano!")
		return
	m.hp -= n
	m.hits = int(m.get("hits", 0)) + 1
	var c: Card3D = m.card
	c.punch(0.2)
	c.shake()
	_float3d("-%d" % n, c.global_position, Color(1, 0.85, 0.3))
	if _has_tag(m, "haunt") and int(m.hits) % 2 == 0:
		m.temp_eva = int(m.get("temp_eva", 0)) + 1
		_toast("The Haunt: +1 dado")
	if _has_tag(m, "rage_atk"):
		m.temp_atk = int(m.get("temp_atk", 0)) + 1
	if _has_tag(m, "echo_right") or _has_tag(m, "echo_left"):
		_damage_player(players[1 - active], n, null)
	if m.hp <= 0:
		_kill_monster(m, by)
	_ui()

# ---------- Morte de monstro ----------
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
	var pos: Vector3 = c.global_position
	# Recompensas
	var roll_val: int = int(m.get("kill_roll", 1))
	var mult: int = 2 if bool(m.get("double", false)) else 1
	if m.reward_kind == "rollcents":
		_gain_coins(by, roll_val * mult, pos)
	elif m.reward_kind == "rollloot":
		await _draw_loot(by, roll_val * mult)
	else:
		if d[4] > 0:
			_gain_coins(by, int(d[4]) * mult, pos)
	if d[5] > 0:
		await _draw_loot(by, int(d[5]))
	for i in int(d[6]):
		await _gain_treasure(by, 1)
	# Alma ou descarte
	if d[7] > 0:
		by.soul_n += int(d[7])
		by.souls.append(c)
		c.zone = "soul"
		c.ref = by
		c.fly_to(_soul_xf(by, by.souls.size() - 1), 0.7, 0.8)
		_float3d("+%d ALMA" % int(d[7]), pos, Color(0.75, 0.9, 1))
	else:
		monster_discard.append(m.id)
		_discard_card(c, false)
	_ui()
	if by.soul_n >= D.SOULS_TO_WIN:
		_game_end(by)
		return
	await _mon_death_effect(m, by)
	# The Midas Touch: cada monstro morto dá 3¢.
	if _n(by, "themidastouch") > 0:
		_gain_coins(by, 3, pos)
	# Stoney: quando outro monstro morre, este também morre.
	for o in _all_mons():
		if _has_tag(o, "dies_with_others"):
			_kill_monster(o, by)
	_ui()

func _mon_death_effect(m: Dictionary, by: Dictionary) -> void:
	if _has_tag(m, "bony_death"):
		_damage_player(by, 1, null)
	if _has_tag(m, "boom_death"):
		for q in players:
			_damage_player(q, 1, null)
	if _has_tag(m, "extra_attack_death"):
		by.attacks += 1
		_toast("Ataque adicional!")
	if _has_tag(m, "discard2_death"):
		_force_discard(_opp(by), 2)
	if _has_tag(m, "greedling_death"):
		_lose_coins(_opp(by), 7)
	if _has_tag(m, "shop_expand_death"):
		_expand_shop_slots(1)
	if _has_tag(m, "monster_expand_death"):
		_expand_monster_slots(1)
	if _has_tag(m, "recharge_death"):
		_recharge_all(by)
	if _has_tag(m, "mulliboom_death"):
		_damage_player(_opp(by), 3, null)
	if _has_tag(m, "steal_item_death"):
		var it = _pick_stealable(_opp(by))
		if it != null:
			_transfer_item(it, by)
	if _has_tag(m, "soul_destroy_death"):
		var o: Dictionary = _opp(by)
		if o.soul_n > 0:
			o.soul_n -= 1
			if not o.souls.is_empty():
				var sc: Card3D = o.souls.pop_back()
				_discard_card(sc, false)
			_toast("%s perdeu uma alma" % o.name)
	if _has_tag(m, "death_kill"):
		_damage_player(_opp(by), 99, null)
	if _has_tag(m, "famine_death"):
		by.state["skip_next"] = true
	if _has_tag(m, "pestilence_death"):
		_damage_player(_opp(by), 2, null)
	if _has_tag(m, "wrath_death"):
		await _roll(by, "Wrath", func(v: int) -> void:
			var dd: int = 1 if v <= 3 else 2
			for q in players:
				_damage_player(q, dd, null))
	if _has_tag(m, "sloth_death"):
		_force_discard(by, by.hand.size())
	if _has_tag(m, "ragman_death"):
		await _roll(by, "Rag Man", func(v: int) -> void:
			if v == 1 or v == 6:
				if not monster_ids.is_empty():
					monster_ids.push_back(m.id))
	if _has_tag(m, "delirium_death"):
		monster_ids.insert(min(6, monster_ids.size()), m.id)
		decks.monster.set_count(monster_ids.size())
	if _has_tag(m, "peep_death"):
		for i in monster_ids.size():
			if monster_ids[i] == "bloat":
				monster_ids.remove_at(i)
				break
		decks.monster.set_count(monster_ids.size())
	if _has_tag(m, "lamb_soul"):
		var o: Dictionary = _opp(by)
		if o.soul_n > 0:
			o.soul_n -= 1
			by.soul_n += 1
			if not o.souls.is_empty():
				var sc: Card3D = o.souls.pop_back()
				sc.ref = by
				by.souls.append(sc)
				sc.fly_to(_soul_xf(by, by.souls.size() - 1), 0.6, 0.6)
			_toast("Alma transferida!")

func _kill_rewards(by: Dictionary, d: Array) -> void:
	pass


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

func _bumbo_level(p: Dictionary) -> int:
	var it = _item_of(p, "bumbo")
	return int(it.counters) if it != null else 0

func _atk(p: Dictionary) -> int:
	var a: int = p.base_atk + _n(p, "brimstone") + _n(p, "ipecac") + p.temp_atk
	if _bumbo_level(p) >= 10:
		a += 1
	if p.first_roll:
		a += _n(p, "championbelt") + _n(p, "polydactyly") + _nt(p, "curvedhorn")
	if p.hand.is_empty():
		a += _n(p, "emptyvessel")
	return a

func _roll_bonus(p: Dictionary, is_attack := false, first := false) -> int:
	var r: int = p.temp_roll
	if is_attack:
		r += _n(p, "meat") + _n(p, "synthoil")
		if p.coins == 0:
			r += _n(p, "emptyvessel")
		if first and _bumbo_level(p) >= 1:
			r += 2
	return r

func _loot_step(p: Dictionary) -> int:
	return 1 + _n(p, "momspurse") + _n(p, "momscoinpurse")

func _shop_price(p: Dictionary) -> int:
	return max(0, D.SHOP_PRICE - 5 * _n(p, "steamysale"))

func _guppy_count(p: Dictionary) -> int:
	var k := 0
	for g in GUPPY_ITEMS:
		k += _n(p, g)
	return k

func _check_bonus_souls() -> void:
	var winner: Dictionary = {}
	for q in players:
		if not bonus_souls_taken.has("soulofgreed") and q.coins >= 25:
			bonus_souls_taken["soulofgreed"] = q.i
			q.soul_n += 1
			_toast("%s ganhou a Alma de Greed!" % q.name)
		if not bonus_souls_taken.has("soulofgluttony") and q.hand.size() >= 10:
			bonus_souls_taken["soulofgluttony"] = q.i
			q.soul_n += 1
			_toast("%s ganhou a Alma de Gluttony!" % q.name)
		if not bonus_souls_taken.has("soulofguppy") and _guppy_count(q) >= 2:
			bonus_souls_taken["soulofguppy"] = q.i
			q.soul_n += 1
			_toast("%s ganhou a Alma de Guppy!" % q.name)
		if q.soul_n >= D.SOULS_TO_WIN and not game_over:
			winner = q
	if not winner.is_empty():
		_game_end(winner)

func _opp(p: Dictionary) -> Dictionary:
	return players[1 - p.i]

func _gain_coins(p: Dictionary, n: int, at: Vector3) -> void:
	if n <= 0 or game_over:
		return
	var bumbo = _item_of(p, "bumbo")
	if bumbo != null:
		bumbo.counters += n
		_float3d("Bum-Bo +%d" % n, at, Color(1, 0.7, 0.3))
		_ui()
		return
	var amt: int = n + _nt(p, "counterfeitpenny")
	p.coins += amt
	_float3d("+%d¢" % amt, at, Color(1, 0.82, 0.3))
	_check_bonus_souls()
	_ui()

func _damage_player(p: Dictionary, n: int, src) -> void:
	if p.dead or n <= 0 or game_over:
		return
	if p.reduce_to1:
		p.reduce_to1 = false
		n = min(n, 1)
	if _n(p, "daddyhaunt") > 0:
		n += 1
	if p.prevent_full > 0:
		p.prevent_full -= 1
		_float3d("Prevenido", (p.char_card as Card3D).global_position, Color(0.6, 0.85, 1))
		if _n(p, "hosthat") > 0:
			_damage_player(_opp(p), 1, null)
		_ui()
		return
	if p.prevent_amt > 0:
		var k: int = min(n, p.prevent_amt)
		p.prevent_amt -= k
		n -= k
		if n <= 0:
			_float3d("Prevenido", (p.char_card as Card3D).global_position, Color(0.6, 0.85, 1))
			_ui()
			return
	if _n(p, "drybaby") > 0:
		n = min(n, 1)
	var dc = _item_of(p, "thedeadcat")
	if dc != null and int(dc.counters) > 0:
		var k2: int = min(n, int(dc.counters))
		dc.counters -= k2
		n -= k2
		if n <= 0:
			_float3d("Prevenido", (p.char_card as Card3D).global_position, Color(0.6, 0.85, 1))
			_ui()
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
	_on_player_damaged(p, n)
	if src != null and src is Dictionary and src.has("tags"):
		_mon_dealt_damage(src, p, n)
	if p.hp <= 0:
		_kill_player(p)
	_ui()

func _on_player_damaged(p: Dictionary, n: int) -> void:
	if _n(p, "fannypack") > 0:
		await _draw_loot(p, 1)
	if _nt(p, "swallowedpenny") > 0:
		p.coins += 1
		_float3d("+1¢", (p.char_card as Card3D).global_position, Color(1, 0.82, 0.3))
	var poop = _item_of(p, "thepoop")
	if poop != null:
		poop.counters += 1
	var camb = _item_of(p, "cambionconception")
	if camb != null:
		camb.counters += n
		if int(camb.counters) >= 6:
			camb.counters -= 6
			await _gain_treasure(p, 1)
	if _n(p, "curseofthetower") > 0:
		await _roll(p, "Curse of the Tower", func(v: int) -> void:
			if v <= 3:
				for q in players:
					if not is_same(q, p):
						_damage_player(q, 1, null)
			else:
				var ms := _all_mons()
				if not ms.is_empty():
					_damage_monster(ms.pick_random(), 1, p))
	if _n(p, "thehabit") > 0 and not bool(p.state.get("habit_used", false)):
		p.state["habit_used"] = true
		_recharge_first(p)

func _mon_dealt_damage(m: Dictionary, p: Dictionary, n: int) -> void:
	if _has_tag(m, "lifesteal"):
		m.hp = min(m.max, m.hp + 1)
	if _has_tag(m, "keeperhead_coin"):
		_lose_coins(p, 2)
	if _has_tag(m, "greed_coin"):
		for q in players:
			_lose_coins(q, 4)
	if _has_tag(m, "scolex_discard"):
		_force_discard(p, 1)
	if _has_tag(m, "bloat_aoe"):
		for q in players:
			if q.i != active and not is_same(q, p):
				_damage_player(q, 1, null)
	if _has_tag(m, "ragecreep_echo") and is_same(p, players[active]):
		_damage_player(players[(active + 1) % players.size()], n, null)

func _pick_stealable(p: Dictionary):
	var arr: Array = p.items.filter(func(it): return not _is_eternal(it))
	return arr[0] if not arr.is_empty() else null

func _transfer_item(it: Dictionary, to: Dictionary) -> void:
	var from: Dictionary = it.owner
	from.items.erase(it)
	it.owner = to
	to.items.append(it)
	_layout_items(from)
	_layout_items(to)
	_ui()

func _steal_random_loot(p: Dictionary, from: Dictionary) -> void:
	if from.hand.is_empty():
		return
	var c: Card3D = from.hand.pick_random()
	from.hand.erase(c)
	if c == selected_card:
		selected_card = null
	c.ref = p
	p.hand.append(c)
	c.reparent(hand_root if p.i == 0 else opp_hand_root, true)
	_layout_hand(from)
	_layout_hand(p)

func _give_loot(p: Dictionary, from: Dictionary) -> void:
	if from.hand.is_empty():
		return
	var c: Card3D = from.hand.pick_random()
	from.hand.erase(c)
	if c == selected_card:
		selected_card = null
	c.ref = p
	p.hand.append(c)
	c.reparent(hand_root if p.i == 0 else opp_hand_root, true)
	_layout_hand(from)
	_layout_hand(p)

func _card_disp_name(id: String) -> String:
	if D.LOOT.has(id):
		return D.LOOT[id][0]
	if D.ITEMS.has(id):
		return D.ITEMS[id][0]
	if D.MONSTERS.has(id):
		return D.MONSTERS[id][0]
	if D.EVENTS.has(id):
		return D.EVENTS[id][0]
	return id

func _pick_order(ids: Array, title: String) -> Array:
	if players[active].bot or autoplay or ids.size() <= 1:
		return ids
	var remaining := ids.duplicate()
	var order: Array = []
	while not remaining.is_empty():
		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 6)
		vb.add_child(_lbl("Escolha a %dª (topo primeiro)" % (order.size() + 1), 14, GOLD, true))
		var picked := [""]
		var done := [false]
		for id in remaining:
			var b := _btn(_card_disp_name(id), func(): picked[0] = id; done[0] = true)
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			b.custom_minimum_size = Vector2(240, 34)
			vb.add_child(b)
		_open_custom_panel(title, vb)
		while not done[0]:
			await _wait(0.05)
		_close_inspect()
		order.append(picked[0])
		remaining.erase(picked[0])
	return order

func _reorder_top(deck_key: String, n: int) -> void:
	var arr: Array
	var dk: Deck3D
	match deck_key:
		"loot": arr = loot_ids; dk = decks.loot
		"monster": arr = monster_ids; dk = decks.monster
		"treasure": arr = treasure_ids; dk = decks.treasure
		_: return
	var cnt: int = min(n, arr.size())
	if cnt <= 0:
		return
	var popped: Array = []
	for i in cnt:
		popped.append(arr.pop_back())
	if players[active].i == 0 and not players[active].bot:
		popped = await _pick_order(popped, "Olhar o topo — " + deck_key)
	for i in range(popped.size() - 1, -1, -1):
		arr.push_back(popped[i])
	dk.set_count(arr.size())

func _peek(deck_key: String) -> String:
	match deck_key:
		"loot":
			if loot_ids.is_empty(): return ""
			return loot_ids.back()
		"monster":
			if monster_ids.is_empty(): return ""
			return monster_ids.back()
		"treasure":
			if treasure_ids.is_empty(): return ""
			return treasure_ids.back()
	return ""

func _kill_player(p: Dictionary) -> void:
	if game_over:
		return
	# Prevenção de morte
	if _n(p, "guppyscollar") > 0:
		var prevented := [false]
		await _roll(p, "Guppy's Collar", func(v: int) -> void:
			if v <= 3: prevented[0] = true)
		if prevented[0]:
			p.hp = _max_hp(p)
			_toast("%s evitou a morte!" % p.name)
			return
	if _nt(p, "brokenankh") > 0:
		var prev2 := [false]
		await _roll(p, "Broken Ankh", func(v: int) -> void:
			if v == 6: prev2[0] = true)
		if prev2[0]:
			p.hp = _max_hp(p)
			_toast("%s evitou a morte!" % p.name)
			return
	p.dead = true
	p.hp = 0
	_toast("%s MORREU" % p.name.to_upper())
	if p.i == 0:
		flash.color = Color(0, 0, 0, 0.85)
		flash.create_tween().tween_property(flash, "color:a", 0.0, 1.4)
	# Antes das penalidades
	if _n(p, "greedsgullet") > 0:
		_gain_coins(p, 8, (p.char_card as Card3D).global_position)
	if _n(p, "suicideking") > 0:
		await _draw_loot(p, 3)
	for q in players:
		if _nt(q, "bloodypenny") > 0:
			await _draw_loot(q, 1)
	# Maldições-atributo voltam (babyhaunt/daddyhaunt entregues a outro jogador)
	for cur in ["babyhaunt", "daddyhaunt"]:
		var ci = _item_of(p, cur)
		if ci != null:
			_transfer_item(ci, _opp(p))
	# Penalidades: 1¢, 1 loot, 1 item não-eterno, tudo virado.
	p.coins = max(0, p.coins - 1)
	if not p.hand.is_empty():
		var c: Card3D = p.hand.pick_random()
		p.hand.erase(c)
		if c == selected_card:
			selected_card = null
		# Shadow: adversário escolhe/ganha o que seria perdido.
		var sh = _opp(p)
		if _n(sh, "shadow") > 0:
			sh.hand.append(c)
			c.ref = sh
			c.reparent(hand_root if sh.i == 0 else opp_hand_root, true)
			_layout_hand(sh)
		else:
			_discard_card(c, true)
		_layout_hand(p)
	var lose: Array = p.items.filter(func(it): return not _is_eternal(it))
	if not lose.is_empty():
		var it: Dictionary = lose.pick_random()
		p.items.erase(it)
		_discard_card(it.card, false)
	for it in p.items:
		it.tapped = true
	p.char_tapped = true
	# Maldições (eventos) vão para descarte.
	if not p.curses.is_empty():
		for cur in p.curses:
			pass
		p.curses.clear()
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
	# Depois das penalidades: Lazarus' Rags
	if _n(p, "lazarusrags") > 0:
		await _gain_treasure(p, 1)

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
		if autoplay:
			autoplay_turns += 1
			print("[autoplay] turn %d  player=%s  hp=%d/%d coins=%d items=%d hand=%d souls=%d" % [autoplay_turns, p.name, p.hp, _max_hp(p), p.coins, p.items.size(), p.hand.size(), p.soul_n])
		await _start_phase(p)
		if game_over: break
		if p.bot:
			await _bot_turn(p)
		else:
			_ui()
			await end_turn_requested
		if game_over: break
		await _end_phase(p)
		if pending_extra_turn == p.i:
			pending_extra_turn = -1
			_toast("%s joga novamente!" % p.name)
		else:
			active = 1 - active

func _start_phase(p: Dictionary) -> void:
	if bool(p.state.get("skip_next", false)):
		p.state["skip_next"] = false
		_toast("%s pula o turno!" % p.name)
		turn_over = true
		return
	_toast("Turno de %s" % p.name if p.bot else "Seu turno")
	for it in p.items:
		it.tapped = false
	p.char_tapped = false
	p.loot_plays = 1 + _n(p, "polydactyly") + _n(p, "bellybutton")
	p.attacks = 1 + _n(p, "championbelt")
	if _bumbo_level(p) >= 25:
		p.attacks = 99
	p.bought = 0
	p.buy_limit = 1 + (1 if _n(p, "theresoptions") > 0 else 0)
	p.first_roll = true
	p.state["habit_used"] = false
	p.reduce_to1 = false
	_layout_items(p)
	_ui()
	await _wait(0.4)
	# Maldições no início do turno
	if p.curses.has("curseofpain"):
		_damage_player(p, 1, null)
	if _n(p, "thecurse") > 0:
		await _reorder_top("monster", 1)
	# Efeitos no início do turno
	if _n(p, "darkbum") > 0:
		await _roll(p, "Dark Bum", func(v: int) -> void:
			if v <= 2: _gain_coins(p, 3, (p.char_card as Card3D).global_position)
			elif v <= 4: await _draw_loot(p, 1)
			else: _damage_player(p, 1, null))
	if _n(p, "monstrostooth") > 0:
		var victim: Dictionary = _opp(p) if not _opp(p).items.is_empty() else p
		var it = _pick_stealable(victim)
		if it != null:
			victim.items.erase(it)
			_discard_card(it.card, false)
			_layout_items(victim)
	if _n(p, "restock") > 0:
		for s in shop.size():
			if shop[s] != null:
				var sc: Card3D = shop[s]
				treasure_discard.append(sc.id)
				sc.queue_free()
				shop[s] = null
		for s in shop.size():
			_shop_fill(s)
	for pair in [["cainseye", "loot"], ["goldenhorseshoe", "treasure"], ["purpleheart", "monster"]]:
		if _nt(p, pair[0]) > 0:
			var top := _peek(pair[1])
			if top != "":
				_toast("%s: topo = %s" % [pair[0], _card_disp_name(top)])
				await _wait(0.4)
	# Passo de loot
	await _draw_loot(p, _loot_step(p))
	_check_bonus_souls()
	_ui()

func _end_phase(p: Dictionary) -> void:
	awaiting_roll = false
	in_combat = false
	# Maldições no fim do turno
	if p.curses.has("curseofgreed"):
		_lose_coins(p, 4)
	if p.curses.has("curseofamnesia"):
		_force_discard(p, 2)
	# Efeitos no fim do turno
	if _n(p, "goathead") > 0 and not p.hand.is_empty():
		var gopts: Array = []
		for i in range(p.hand.size() + 1):
			gopts.append(str(i))
		var gk: int = await _choose_option("Goat Head — quantas cartas de loot descartar?", gopts, 0, p.bot)
		if gk > 0:
			_force_discard(p, gk)
			await _draw_loot(p, gk)
	if _n(p, "edensblessing") > 0 and p.coins == 0:
		_gain_coins(p, 6, (p.char_card as Card3D).global_position)
	if _n(p, "starterdeck") > 0 and p.hand.size() >= 8:
		await _draw_loot(p, 2)
	if _n(p, "thepolaroid") > 0 and p.hand.is_empty():
		await _draw_loot(p, 2)
	if _n(p, "thebluemap") > 0:
		await _reorder_top("treasure", 4)
	if _n(p, "thecompass") > 0:
		await _reorder_top("loot", 4)
	if _n(p, "themap") > 0:
		await _reorder_top("monster", 4)
	# Descarte até o limite de mão
	while p.hand.size() > D.HAND_LIMIT:
		var c: Card3D = p.hand.pop_front()
		_discard_card(c, true)
	# Fim de turno: todos curam, monstros também.
	for q in players:
		q.temp_atk = 0
		q.temp_hp = 0
		q.temp_roll = 0
		q.prevent_full = 0
		q.prevent_amt = 0
		q.reduce_to1 = false
		q.shield = 0
		q.dead = false
		q.hp = _max_hp(q)
	for s in slots.size():
		for m in slots[s]:
			m.hp = m.max
			m.temp_atk = 0
			m.temp_eva = 0
	_layout_hand(p)
	_ui()
	await _refill_slots()
	await _wait(0.3)

func _trinity_blocked(actor: Dictionary) -> bool:
	var cur: Dictionary = players[active]
	return not is_same(actor, cur) and _n(cur, "trinityshield") > 0

func _human_idle() -> bool:
	return active == 0 and not players[0].bot and stack.is_empty() and not busy and not in_combat \
		and not game_over and not turn_over and targeting == "" and not players[0].dead

# Pode o humano agir agora (ativar itens / jogar loot)?
func _human_has_priority() -> bool:
	if game_over or busy or targeting != "" or players[0].dead:
		return false
	if _trinity_blocked(players[0]):
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
	if stack.is_empty() or me.dead or me.bot:
		return false
	if _trinity_blocked(me):
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
	return e.value + e.bonus + _roll_bonus(e.owner, true, bool(e.get("first", false))) >= _eva(m)

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
	await _roll_triggers(p, v)
	_push(e)
	await _run_stack()

func _rand_roll(p: Dictionary) -> int:
	var v := randi_range(1, 6)
	if v == 1:
		for q in players:
			if not is_same(q, p) and _n(q, "dadslostcoin") > 0:
				_toast("Dad's Lost Coin: rerrolar")
				v = randi_range(1, 6)
				break
	if v == 1 and _n(p, "sacredheart") > 0:
		_toast("Sacred Heart: 1 vira 6")
		v = 6
	return v

func _d10_place(_q: Dictionary) -> void:
	for s in slots.size():
		if slots[s].is_empty() and not monster_ids.is_empty():
			await _reveal_into(s)
			return

func _spider_mod(_q: Dictionary) -> void:
	for s in slots.size():
		var m = _top(s)
		if m == null:
			continue
		if in_combat and combat.get("uid", -1) == m.uid:
			continue
		if monster_ids.is_empty():
			return
		slots[s].erase(m)
		monster_discard.append(m.id)
		(m.label as Label3D).queue_free()
		_discard_card(m.card, false)
		await _reveal_into(s)
		return

func _roll_triggers(p: Dictionary, v: int) -> void:
	for q in players:
		if v == 1:
			for i in _n(q, "relic"):
				await _draw_loot(q, 1)
			for it in q.items:
				if it.id == "sackofpennies" and it.tapped:
					it.tapped = false
					_layout_items(q)
		if v == 2:
			if _n(q, "chargedbaby") > 0:
				_recharge_first(q)
			if _n(q, "finger") > 0:
				var o := _opp(q)
				var a = _pick_stealable(q)
				var b = _pick_stealable(o)
				if a != null and b != null:
					_transfer_item(a, o)
					_transfer_item(b, q)
		if v == 3:
			if _n(q, "deadbird") > 0:
				_steal_random_loot(q, _opp(q))
			if _n(q, "thed10") > 0:
				await _d10_place(q)
		if v == 4:
			if _n(q, "momsbox") > 0:
				await _draw_loot(q, 1)
				_force_discard(q, 1)
			if _n(q, "tarotcloth") > 0 and not is_same(q, p):
				_give_loot(q, p)
		if v == 5:
			if _n(q, "eyeofgreed") > 0:
				_gain_coins(q, 3, (q.char_card as Card3D).global_position)
			if _n(q, "spidermod") > 0:
				await _spider_mod(q)
		if v == 6:
			if _n(q, "momsrazor") > 0 and not is_same(q, p):
				_damage_player(p, 1, null)
			if _n(q, "cheesegrater") > 0:
				await _reorder_top("monster", 1)
	# Efeitos de monstros conforme o resultado do dado
	for m in _all_mons():
		if v == 1 and _has_tag(m, "holy_roll1_coin"):
			_gain_coins(p, 1, (p.char_card as Card3D).global_position)
		if v == 1 and _has_tag(m, "curse_roll1_coin"):
			_lose_coins(p, 2)
		if v == 2 and _has_tag(m, "curse_roll2_dmg2"):
			_damage_player(p, 2, null)
		if v == 2 and _has_tag(m, "holy_roll2_recharge"):
			_recharge_first(p)
		if v == 4 and _has_tag(m, "holy_roll4_coin"):
			_gain_coins(p, 2, (p.char_card as Card3D).global_position)
		if v == 4 and _has_tag(m, "curse_roll4"):
			for o in _all_mons():
				o.temp_atk = int(o.temp_atk) + 1
		if v == 5 and _has_tag(m, "holy_roll5_loot"):
			await _draw_loot(p, 1)
		if v == 5 and _has_tag(m, "curse_roll5_discard"):
			_force_discard(p, 1)
		if v == 6 and _has_tag(m, "holy_roll6_heal"):
			p.hp = min(_max_hp(p), p.hp + 1)
		if v == 6 and _has_tag(m, "curse_roll6_end"):
			turn_over = true

func _reroll(e: Dictionary) -> void:
	if not stack.has(e):
		return
	var v := _rand_roll(e.owner)
	e.value = v
	_toast("Rerrolou: %d" % v)
	var to := dice.position + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.1, 0.1))
	await dice.throw(v, dice.position + Vector3(0, 0.8, 0.3), to)
	await _roll_triggers(e.owner, v)
	_ui()

# =====================================================================
# AÇÕES (compartilhadas por humano e CPU)
# =====================================================================
func _act_attack(p: Dictionary, s: int) -> void:
	var m = _top(s)
	if m == null or p.attacks <= 0:
		return
	if _has_tag(m, "untargetable"):
		_toast("%s não pode ser atacado" % D.MONSTERS[m.id][0])
		return
	p.attacks -= 1
	in_combat = true
	combat = {"p": p, "uid": m.uid}
	_toast("%s ataca %s" % [p.name, D.MONSTERS[m.id][0]])
	_ui()
	if _has_tag(m, "pride_declare"):
		_force_discard(_opp(p), 2)
	if _n(p, "bobsbrain") > 0:
		await _roll(p, "Bob's Brain", func(v: int) -> void:
			if v <= 2:
				var ms := _all_mons()
				if not ms.is_empty():
					_damage_monster(ms.pick_random(), 1, p)
			elif v <= 4:
				_damage_player(_opp(p), 1, null)
			else:
				_damage_player(p, 1, null))
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
		await _roll(p, "ataque", on_res, {"attack": true, "mon_uid": mu, "first": p.first_roll})
	in_combat = false
	awaiting_roll = false
	_ui()

func _resolve_attack(p: Dictionary, mu: int, v: int) -> void:
	var m = _find_mon(mu)
	if m == null or p.dead:
		return
	var is_first: bool = p.first_roll
	var total: int = v + _roll_bonus(p, true, is_first)
	var raw: int = v
	var dmg := _atk(p)
	p.first_roll = false
	m.kill_roll = raw
	m.double = _has_tag(m, "double6_death") and raw == 6
	# Gatilhos por valor de rolagem
	if raw == 3 and _has_tag(m, "steal3"):
		_steal_random_loot(p, _opp(p))
	if raw == 5 and _has_tag(m, "selfdmg5"):
		_damage_player(p, 1, null)
	if raw == 1 and _has_tag(m, "dll_roll1"):
		for o in _all_mons():
			o.temp_eva = int(o.temp_eva) + 1
	if raw == 6 and _has_tag(m, "satan6"):
		_damage_player(_opp(p), 99, null)
	if raw == 6 and _has_tag(m, "end6"):
		turn_over = true
	if total >= _eva(m):
		if (_has_tag(m, "immune6") and raw == 6) or (_has_tag(m, "immune45") and (raw == 4 or raw == 5)):
			_toast("%s é imune a essa rolagem" % D.MONSTERS[m.id][0])
			return
		_toast("Acerto! %d de dano" % dmg)
		_damage_monster(m, dmg, p)
		if _has_tag(m, "gluttony6") and raw == 6:
			_damage_player(players[(active + 1) % players.size()], 1, null)
		if _has_tag(m, "lust_thorns"):
			_damage_player(p, 1, null)
	else:
		var d: int = _mon_atk(m)
		if _has_tag(m, "dbl1") and raw == 1:
			d *= 2
		if _has_tag(m, "plus2") and raw == 2:
			d += 1
		if _has_tag(m, "chub") and raw == 1:
			m.hp = min(m.max, m.hp + 2)
		_toast("Errou — %s causa %d" % [D.MONSTERS[m.id][0], d])
		(m.card as Card3D).punch(0.12)
		_damage_player(p, d, m)

func _act_buy(p: Dictionary, s: int) -> void:
	if p.bought >= p.buy_limit:
		return
	var price: int = _shop_price(p) if s >= 0 else D.SHOP_PRICE
	if p.coins < price:
		return
	var from: Transform3D
	var id: String
	if s < 0:
		if treasure_ids.is_empty():
			return
		p.coins -= price
		id = treasure_ids.pop_back()
		decks.treasure.set_count(treasure_ids.size())
		from = decks.treasure.top_xf()
	else:
		if shop[s] == null:
			return
		p.coins -= price
		var c: Card3D = shop[s]
		id = c.id
		from = c.transform
		c.queue_free()
		shop[s] = null
	p.bought += 1
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

func _deal_to_target(target, dmg: int, by: Dictionary) -> void:
	if target == null:
		return
	if target.get("type", "") == "monster":
		_damage_monster(target.m, dmg, by)
	else:
		_damage_player(target.p, dmg, null)

func _loot_effect(p: Dictionary, id: String, target, e: Dictionary) -> Callable:
	var ppos: Vector3 = (p.char_card as Card3D).global_position
	match id:
		"penny", "twocents", "threecents", "fourcents", "nickel", "dime":
			var amt: int = {"penny": 1, "twocents": 2, "threecents": 3, "fourcents": 4, "nickel": 5, "dime": 10}[id]
			return func() -> void: _gain_coins(p, amt, ppos)
		"bomb", "goldbomb":
			var dmg := 3 if id == "goldbomb" else 1
			return func() -> void: _deal_to_target(target, dmg, p)
		"battery":
			return func() -> void: _recharge_first(p)
		"megabattery":
			return func() -> void: _recharge_all(_target_p(target, p))
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
		"diceshard":
			return func() -> void:
				var r = _top_roll()
				if r != null:
					await _reroll(r)
		"pills_blue":
			return func() -> void: await _roll(p, "Pills!", func(v: int) -> void:
				if v <= 2: _gain_coins(p, 4, ppos)
				elif v <= 4: _gain_coins(p, 7, ppos)
				else: _lose_coins(p, 4))
		"pills_orange":
			return func() -> void: await _roll(p, "Pills!", func(v: int) -> void:
				if v <= 2: p.temp_atk += 1
				elif v <= 4: p.temp_hp += 1; p.hp += 1
				else: _damage_player(p, 1, null))
		"pills_red":
			return func() -> void: await _roll(p, "Pills!", func(v: int) -> void:
				if v <= 2: await _draw_loot(p, 1)
				elif v <= 4: await _draw_loot(p, 3)
				else: _force_discard(p, 1))
		"soulheart":
			return func() -> void: _target_p(target, p).prevent_full += 1
		"ofool":
			return func() -> void: _cancel_turn()
		"magician":
			return func() -> void: _set_top_roll(await _choose_roll_number(p))
		"iithehighpriestess":
			return func() -> void: await _roll(p, "High Priestess", func(v: int) -> void: _deal_to_target(target, v, p))
		"iiitheempress":
			return func() -> void:
				var t = _target_p(target, p); t.temp_atk += 1; t.temp_roll += 1
		"ivtheemperor":
			return func() -> void: await _reorder_top("monster", 5)
		"vthehierophant":
			return func() -> void: _target_p(target, p).prevent_amt += 2
		"vithelovers":
			return func() -> void:
				var t = _target_p(target, p); t.temp_hp += 2; t.hp += 2
		"viithechariot":
			return func() -> void:
				var t = _target_p(target, p); t.temp_atk += 1; t.temp_hp += 1; t.hp += 1
		"viiijustice":
			return func() -> void:
				var t = _target_p(target, p)
				while p.hand.size() < t.hand.size(): await _draw_loot(p, 1)
				while p.coins < t.coins: _gain_coins(p, 1, ppos)
		"ixthehermit":
			return func() -> void: await _reorder_top("treasure", 5)
		"wheeloffortune":
			return func() -> void:
				await _roll(p, "Wheel of Fortune", func(v: int) -> void:
					if v == 1: _gain_coins(p, 1, ppos)
					elif v == 2: _damage_player(p, 2, null)
					elif v == 3: await _draw_loot(p, 3)
					elif v == 4: _lose_coins(p, 4)
					elif v == 5: _gain_coins(p, 5, ppos)
					else: await _gain_treasure(p, 1))
		"strength":
			return func() -> void: p.temp_atk += 1; p.attacks += 1
		"xiithehangedman":
			return func() -> void:
				await _reorder_top("monster", 1)
				await _reorder_top("loot", 1)
				await _reorder_top("treasure", 1)
				await _draw_loot(p, 2)
		"xiiideath":
			return func() -> void: _damage_player(_target_p(target, p), 99, null)
		"xivtemperance":
			return func() -> void:
				var c: int = await _choose_option("Temperance", ["1 de dano / +4¢", "2 de dano / +8¢"], 0, p.bot)
				if c == 0:
					_damage_player(p, 1, null); _gain_coins(p, 4, ppos)
				else:
					_damage_player(p, 2, null); _gain_coins(p, 8, ppos)
		"xvthedevil":
			return func() -> void: _devil_loot(p)
		"xvithetower":
			return func() -> void: await _roll(p, "The Tower", func(v: int) -> void:
				if v <= 2:
					for q in players: _damage_player(q, 1, null)
				elif v <= 4:
					for m in _all_mons(): _damage_monster(m, 1, p)
				else:
					for q in players: _damage_player(q, 2, null))
		"xviithestars":
			return func() -> void: await _gain_treasure(p, 1)
		"xviiithemoon":
			return func() -> void: await _reorder_top("loot", 5)
		"xixthesun":
			return func() -> void: _sun_extra_turn(p, e)
		"xxjudgement":
			return func() -> void: _judgement()
		"xxitheworld":
			return func() -> void: await _look_all_hands(p)
		"dagaz":
			return func() -> void: await _dagaz(p, target)
		"ehwaz":
			return func() -> void: await _ehwaz(p)
		"blankrune":
			return func() -> void:
				await _roll(p, "Blank Rune", func(v: int) -> void:
					if v == 1:
						for q in players: _gain_coins(q, 1, (q.char_card as Card3D).global_position)
					elif v == 2:
						for q in players: await _draw_loot(q, 2)
					elif v == 3:
						for q in players: _damage_player(q, 3, null)
					elif v == 4:
						for q in players: _gain_coins(q, 4, (q.char_card as Card3D).global_position)
					elif v == 5:
						for q in players: await _draw_loot(q, 5)
					else:
						for q in players: _gain_coins(q, 6, (q.char_card as Card3D).global_position))
	if TRINKET_IDS.has(id):
		return func() -> void: _gain_trinket(p, id)
	return func() -> void: pass

# ---------- Auxiliares de loot ----------
func _target_p(target, p: Dictionary) -> Dictionary:
	if target is Dictionary and target.get("type", "") == "player":
		return target.p
	return p

func _steal_coins(p: Dictionary, from: Dictionary, n: int) -> void:
	var k: int = min(from.coins, n)
	from.coins -= k
	p.coins += k
	_float3d("+%d¢" % k, (p.char_card as Card3D).global_position, Color(1, 0.82, 0.3))
	_ui()

func _choose_roll_number(p: Dictionary) -> int:
	if p.bot:
		return randi_range(1, 6)
	return await _choose_option("Escolha o número do dado", ["1", "2", "3", "4", "5", "6"], 5, false) + 1

func _set_top_roll(v: int) -> void:
	var r = _top_roll()
	if r != null:
		r.value = v
		_toast("Rolagem definida para %d" % v)

func _cancel_turn() -> void:
	turn_over = true
	for x in stack.duplicate():
		if x.get("card") != null:
			if x.kind == "loot":
				_discard_card(x.card, true)
			else:
				(x.card as Card3D).queue_free()
	stack.clear()
	if active == 0 and not players[0].bot:
		end_turn_requested.emit()

func _devil_loot(p: Dictionary) -> void:
	var mine: Array = p.items.filter(func(it): return not _is_eternal(it))
	if mine.is_empty():
		return
	var it: Dictionary = mine[0]
	p.items.erase(it)
	_discard_card(it.card, false)
	_layout_items(p)
	var steal = _pick_stealable(_opp(p))
	if steal != null:
		_transfer_item(steal, p)
	else:
		for s in shop.size():
			if shop[s] != null:
				var sc: Card3D = shop[s]
				shop[s] = null
				_gain_item(p, sc.id, sc.transform)
				sc.queue_free()
				break

func _sun_extra_turn(p: Dictionary, e: Dictionary) -> void:
	# "Put this on the bottom of the loot deck."
	if loot_discard.has("xixthesun"):
		loot_discard.erase("xixthesun")
		loot_ids.push_front("xixthesun")
		decks.loot.set_count(loot_ids.size())
		decks.discard.set_count(loot_discard.size())
	pending_extra_turn = p.i
	_toast("Turno extra!")

func _judgement() -> void:
	var mx := 0
	for q in players:
		mx = max(mx, q.soul_n)
	for q in players:
		if q.soul_n == mx and q.soul_n > 0:
			q.soul_n -= 1
			if not q.souls.is_empty():
				_discard_card(q.souls.pop_back(), false)
			_toast("%s destruiu uma alma" % q.name)

func _look_all_hands(p: Dictionary) -> void:
	for q in players:
		var names := []
		for c in q.hand:
			names.append(D.LOOT[c.id][0])
		_toast("%s: %s" % [q.name, ", ".join(names) if not names.is_empty() else "(vazia)"])
		await _wait(0.6)
	await _draw_loot(p, 2)

func _dagaz(p: Dictionary, target) -> void:
	if not p.curses.is_empty() or not (_opp(p).curses as Array).is_empty():
		var c: int = await _choose_option("Dagaz", ["Destruir uma maldição", "Prevenir 1 de dano"], 0, p.bot)
		if c == 0:
			if not (_opp(p).curses as Array).is_empty():
				_opp(p).curses.pop_back()
			elif not p.curses.is_empty():
				p.curses.pop_back()
			return
	_target_p(target, p).prevent_amt += 1

func _ehwaz(p: Dictionary) -> void:
	for s in slots.size():
		var m = _top(s)
		if m == null:
			continue
		if in_combat and combat.get("uid", -1) == m.uid:
			continue
		if monster_ids.is_empty():
			break
		slots[s].erase(m)
		monster_discard.append(m.id)
		(m.label as Label3D).queue_free()
		_discard_card(m.card, false)
		await _reveal_into(s)

func _flush(p: Dictionary) -> void:
	var c: int = await _choose_option("Flush!", ["Monstros ao fundo", "Itens da loja ao fundo"], 0, p.bot)
	if c == 0:
		for s in slots.size():
			var m = _top(s)
			if m == null or (in_combat and combat.get("uid", -1) == m.uid):
				continue
			slots[s].erase(m)
			monster_ids.push_front(m.id)
			(m.label as Label3D).queue_free()
			_discard_card(m.card, false)
		decks.monster.set_count(monster_ids.size())
		await _refill_slots()
	else:
		for s in shop.size():
			if shop[s] != null:
				treasure_ids.push_front(shop[s].id)
				shop[s].queue_free()
				shop[s] = null
		decks.treasure.set_count(treasure_ids.size())
		for s in shop.size():
			_shop_fill(s)

func _glass_cannon(p: Dictionary, it: Dictionary) -> void:
	var mine: Array = p.items.filter(func(x): return x != it and not _is_eternal(x))
	if mine.is_empty():
		return
	var victim: Dictionary = mine[0]
	_destroy_item(p, victim)
	await _roll(p, "Glass Cannon", func(v: int) -> void:
		if v <= 5:
			_destroy_item(p, it)
			await _draw_loot(p, 2)
		else:
			it.tapped = false
		_layout_items(p))

func _chaos_card(p: Dictionary, target) -> void:
	var c: int = await _choose_option("Chaos Card", ["Matar jogador/monstro", "Destruir item ou alma"], 0, p.bot)
	if c == 0:
		if target is Dictionary and target.get("type", "") == "monster":
			_damage_monster(target.m, 99, p)
		else:
			_damage_player(_opp(p), 99, null)
	else:
		var s = _pick_stealable(_opp(p))
		if s != null:
			_destroy_item(_opp(p), s)

func _shovel_soul(p: Dictionary) -> void:
	var o: Dictionary = _opp(p)
	if o.soul_n > 0:
		o.soul_n -= 1
		if not o.souls.is_empty():
			var sc: Card3D = o.souls.pop_back()
			sc.ref = p
			p.souls.append(sc)
			p.soul_n += 1
			sc.fly_to(_soul_xf(p, p.souls.size() - 1), 0.7, 0.6)
		_toast("Alma roubada!")

func _pandora(p: Dictionary) -> void:
	await _roll(p, "Pandora's Box", func(v: int) -> void:
		if v == 1:
			_gain_coins(p, 1, (p.char_card as Card3D).global_position)
		elif v == 2:
			_gain_coins(p, 6, (p.char_card as Card3D).global_position)
		elif v == 3:
			var ms := _all_mons()
			if not ms.is_empty(): _damage_monster(ms.pick_random(), 99, p)
		elif v == 4:
			await _draw_loot(p, 3)
		elif v == 5:
			_gain_coins(p, 9, (p.char_card as Card3D).global_position)
		else:
			_become_soul(p))

func _become_soul(p: Dictionary) -> void:
	p.soul_n += 1
	_float3d("+1 ALMA", (p.char_card as Card3D).global_position, Color(0.75, 0.9, 1))
	_check_bonus_souls()

func _potato_peeler() -> void:
	if not monster_ids.is_empty():
		monster_discard.append(monster_ids.pop_back())
		decks.monster.set_count(monster_ids.size())
	if not loot_ids.is_empty():
		loot_discard.append(loot_ids.pop_back())
		decks.loot.set_count(loot_ids.size())
		decks.discard.set_count(loot_discard.size())
	if not treasure_ids.is_empty():
		treasure_discard.append(treasure_ids.pop_back())
		decks.treasure.set_count(treasure_ids.size())

func _remote_detonator(p: Dictionary) -> void:
	var s = _pick_stealable(_opp(p))
	if s != null:
		_destroy_item(_opp(p), s)

func _destroy_item(p: Dictionary, it: Dictionary) -> void:
	if _is_eternal(it):
		return
	# The Chest: se fosse destruído, vira uma alma.
	if it.id == "thechest":
		_item_to_soul(p, it)
		return
	if p.items.has(it):
		p.items.erase(it)
	_discard_card(it.card, false)
	_layout_items(p)

func _item_to_soul(p: Dictionary, it: Dictionary) -> void:
	var c: Card3D = it.card
	if p.items.has(it):
		p.items.erase(it)
	c.ref = p
	c.zone = "soul"
	p.souls.append(c)
	p.soul_n += 1
	_layout_items(p)
	c.fly_to(_soul_xf(p, p.souls.size() - 1), 0.7, 0.6)
	_check_bonus_souls()

func _cancel_ability(p: Dictionary) -> void:
	var tgt = _top_cancelable()
	if tgt == null:
		return
	for x in stack.duplicate():
		if x.uid == tgt.uid:
			stack.erase(x)
			if x.get("card") != null:
				(x.card as Card3D).queue_free()
			_toast("Cancelado: " + x.name)
			break

func _on_item_activated(p: Dictionary, _it: Dictionary) -> void:
	if _n(p, "shinyrock") > 0:
		_gain_coins(p, 1, (p.char_card as Card3D).global_position)
	for m in _all_mons():
		if _has_tag(m, "gurdyjr") and in_combat and is_same(combat.get("p", null), p):
			_damage_player(p, 1, m)
		if _has_tag(m, "curse_activate_dmg"):
			_damage_player(p, 1, m)

func _item_needs_target(id: String) -> bool:
	return id in ["yumheart", "bloodlust", "mrboom", "razorblade", "guppyspaw", "jawbone", "momsbra", "twoofclubs", "thed4"]

func _paid_cost(id: String) -> int:
	return {"batterybum": 4, "goldenrazorblade": 5, "paytoplay": 10, "portableslotmachine": 3}.get(id, 0)

func _paid_usable(it: Dictionary) -> bool:
	var id: String = it.id
	if players[0].coins < _paid_cost(id):
		return false
	if id == "smelter" and players[0].hand.is_empty():
		return false
	if id == "thepoop" and int(it.counters) < 1:
		return false
	if id == "techx" and int(it.counters) < 3:
		return false
	if id == "thebone" and int(it.counters) < 1:
		return false
	if id == "contractfrombelow":
		var mine: int = players[0].items.filter(func(x): return not _is_eternal(x) and x.id != id).size()
		if mine < 2:
			return false
	if id == "donationmachine":
		var mine2: int = players[0].items.filter(func(x): return not _is_eternal(x) and x.id != id).size()
		if mine2 < 1:
			return false
	return true

func _act_paid(p: Dictionary, it: Dictionary, target = null) -> void:
	var id: String = it.id
	var ppos: Vector3 = (p.char_card as Card3D).global_position
	match id:
		"batterybum":
			if p.coins < 4: return
			p.coins -= 4
			_recharge_first(p)
		"goldenrazorblade":
			if p.coins < 5: return
			p.coins -= 5
			_deal_to_target(target, 1, p)
		"paytoplay":
			if p.coins < 10: return
			var s = _pick_stealable(_opp(p))
			if s == null: return
			p.coins -= 10
			_transfer_item(s, p)
		"portableslotmachine":
			if p.coins < 3: return
			p.coins -= 3
			await _roll(p, "Portable Slot Machine", func(v: int) -> void:
				if v <= 3: await _draw_loot(p, 1)
				else: _gain_coins(p, 4, ppos))
		"smelter":
			if p.hand.is_empty(): return
			_force_discard(p, 1)
			_gain_coins(p, 3, ppos)
		"thepoop":
			if int(it.counters) < 1: return
			it.counters = int(it.counters) - 1
			p.prevent_amt += 1
		"techx":
			if int(it.counters) < 3: return
			it.counters = int(it.counters) - 3
			if target != null:
				_deal_to_target(target, 99, p)
			else:
				var ms := _all_mons()
				if not ms.is_empty():
					_damage_monster(ms[0], 99, p)
				else:
					_damage_player(_opp(p), 99, null)
		"thebone":
			var c: int = await _choose_option("The Bone", ["+1 na rolagem (1 ficha)", "1 de dano (2 fichas)", "Vira alma (5 fichas)"], 0, p.bot)
			if c == 0 and int(it.counters) >= 1:
				it.counters = int(it.counters) - 1
				var r = _top_roll()
				if r != null: r.bonus += 1
			elif c == 1 and int(it.counters) >= 2:
				it.counters = int(it.counters) - 2
				if target != null: _deal_to_target(target, 1, p)
				else: _damage_player(_opp(p), 1, null)
			elif c == 2 and int(it.counters) >= 5:
				it.counters = 0
				_item_to_soul(p, it)
		"contractfrombelow":
			var mine: Array = p.items.filter(func(x): return not _is_eternal(x) and x.id != id)
			if mine.size() < 2: return
			_destroy_item(p, mine[0])
			_destroy_item(p, mine[1])
			var s2 = _pick_stealable(_opp(p))
			if s2 != null: _transfer_item(s2, p)
		"donationmachine":
			var mine2: Array = p.items.filter(func(x): return not _is_eternal(x) and x.id != id)
			if mine2.is_empty(): return
			var g: Dictionary = mine2[0]
			p.items.erase(g)
			g.owner = _opp(p)
			_opp(p).items.append(g)
			_layout_items(p)
			_layout_items(_opp(p))
			_gain_coins(p, 8, ppos)
	_ui()

func _act_item(p: Dictionary, it: Dictionary, target = null) -> void:
	if it.tapped or D.ITEMS[it.id][2] == "paid":
		return
	var id: String = it.id
	var ppos: Vector3 = (p.char_card as Card3D).global_position
	var e := {"kind": "ability", "owner": p, "name": D.ITEMS[id][0], "target": target}
	var r = _top_roll()
	match id:
		"d6":
			if r == null: return
			e.fn = func() -> void: await _reroll(r)
		"spoon":
			if r == null: return
			e.fn = func() -> void:
				if stack.has(r): r.bonus += 1; _toast("+1 na rolagem")
		"yumheart":
			e.fn = func() -> void:
				if target is Dictionary and target.get("type", "") == "monster":
					target.m.prevent_full = int(target.m.get("prevent_full", 0)) + 1
				else:
					_target_p(target, p).prevent_full += 1
		"sleightofhand":
			e.fn = func() -> void: await _reorder_top("monster", 5)
		"bookofbelial":
			if r == null: return
			e.fn = func() -> void:
				if stack.has(r): r.bonus += 1
		"foreveralone":
			e.fn = func() -> void: _steal_coins(p, _opp(p), 1)
		"thecurse":
			e.fn = func() -> void:
				if not loot_discard.is_empty():
					var did: String = loot_discard.pop_back()
					loot_ids.push_back(did)
					decks.loot.set_count(loot_ids.size())
					decks.discard.set_count(loot_discard.size())
		"bloodlust":
			e.fn = func() -> void:
				if target is Dictionary and target.get("type", "") == "monster":
					target.m.temp_atk = int(target.m.temp_atk) + 1
				else:
					_target_p(target, p).temp_atk += 1
		"incubus":
			e.fn = func() -> void: await _draw_loot(p, 1); _force_discard(p, 1)
		"blankcard":
			e.fn = func() -> void: p.state["blankcard"] = true
		"booksin":
			e.fn = func() -> void: await _roll(p, "Book of Sin", func(v: int) -> void:
				if v <= 2: _gain_coins(p, 1, ppos)
				elif v <= 4: await _draw_loot(p, 1)
				else: p.temp_hp += 1; p.hp += 1)
		"boomerang":
			e.fn = func() -> void: _steal_random_loot(p, _opp(p))
		"box":
			e.fn = func() -> void: _destroy_item(p, it); p.loot_plays += 99
		"bumfriend":
			e.fn = func() -> void: await _draw_loot(p, 1); _force_discard(p, 1)
		"chaos":
			e.fn = func() -> void: _swap_hands()
		"chaoscard":
			e.fn = func() -> void: _destroy_item(p, it); await _chaos_card(p, target)
		"compost":
			e.fn = func() -> void: p.state["compost"] = true
		"crystalball":
			e.fn = func() -> void: p.state["crystal"] = await _choose_roll_number(p)
		"decoy":
			e.fn = func() -> void:
				var o := _opp(p)
				var s = _pick_stealable(o)
				if s == null: return
				_transfer_item(it, o)
				_transfer_item(s, p)
		"diplopia":
			e.fn = func() -> void: _toast("Diplopia: cópia temporária (aproximado)")
		"flush":
			e.fn = func() -> void: await _flush(p)
		"glasscannon":
			e.fn = func() -> void: await _glass_cannon(p, it)
		"godhead":
			e.fn = func() -> void:
				var n: int = await _choose_option("Godhead", ["1", "6"], 1, p.bot)
				_set_top_roll(1 if n == 0 else 6)
		"guppyshead":
			e.fn = func() -> void: _give_loot(p, _opp(p))
		"guppyspaw":
			e.fn = func() -> void:
				_damage_player(p, 1, null)
				_target_p(target, p).prevent_amt += 2
		"hosthat":
			e.fn = func() -> void: p.prevent_amt += 1
		"jawbone":
			e.fn = func() -> void: _steal_coins(p, _target_p(target, p), 3)
		"luckyfoot":
			if r == null: return
			e.fn = func() -> void:
				if stack.has(r): r.bonus += 2
		"minimush":
			if r == null: return
			e.fn = func() -> void:
				if stack.has(r): r.bonus -= 2
		"modelingclay":
			e.fn = func() -> void: _toast("Modeling Clay: cópia permanente (aproximado)")
		"momsbra":
			e.fn = func() -> void:
				if not (target is Dictionary and target.get("type", "") == "monster"):
					_target_p(target, p).reduce_to1 = true
		"momsshovel":
			e.fn = func() -> void: _destroy_item(p, it); _shovel_soul(p)
		"monstermanual":
			e.fn = func() -> void: p.attacks += 1
		"mrboom":
			e.fn = func() -> void:
				if target is Dictionary and target.get("type", "") == "monster":
					_damage_monster(target.m, 1, p)
		"mysterysack":
			e.fn = func() -> void: await _roll(p, "Mystery Sack", func(v: int) -> void:
				if v <= 2: await _draw_loot(p, 1)
				else: _gain_coins(p, 4, ppos))
		"no":
			e.fn = func() -> void: _cancel_ability(p)
		"pandorasbox":
			e.fn = func() -> void: _destroy_item(p, it); await _pandora(p)
		"placebo":
			e.fn = func() -> void: _toast("Placebo: cópia de ↷ (aproximado)")
		"potatopeeler":
			e.fn = func() -> void: _potato_peeler()
		"razorblade":
			e.fn = func() -> void: _damage_player(_target_p(target, p), 1, null)
		"remotedetonator":
			e.fn = func() -> void: _remote_detonator(p)
		"sackhead":
			e.fn = func() -> void: await _reorder_top("loot", 1)
		"sackofpennies":
			e.fn = func() -> void: _gain_coins(p, 1, ppos)
		"techx":
			e.fn = func() -> void: it.counters = int(it.counters) + 1
		"thebattery":
			e.fn = func() -> void: _recharge_first(p)
		"thed100":
			e.fn = func() -> void:
				await _roll(p, "The D100", func(v: int) -> void:
					if v == 1: await _draw_loot(p, 1)
					elif v == 2: await _draw_loot(p, 2)
					elif v == 3: _gain_coins(p, 3, ppos)
					elif v == 4: _gain_coins(p, 4, ppos)
					elif v == 5: p.temp_hp += 1; p.hp += 1
					else: p.temp_atk += 1)
		"thed20":
			e.fn = func() -> void: _toast("The D20: rerrolar item (aproximado)")
		"thed4":
			e.fn = func() -> void: _destroy_item(p, it); _recharge_all(_target_p(target, p))
		"theshovel":
			e.fn = func() -> void:
				for i in range(monster_discard.size() - 1, -1, -1):
					if not D.EVENTS.has(monster_discard[i]):
						monster_ids.push_back(monster_discard[i])
						monster_discard.remove_at(i)
						decks.monster.set_count(monster_ids.size())
						break
		"twoofclubs":
			e.fn = func() -> void: _target_p(target, p).state["double_loot"] = true
		_:
			return
	it.tapped = true
	_layout_items(p)
	_on_item_activated(p, it)
	var ghost := Card3D.make(id, "treasureback")
	table.add_child(ghost)
	ghost.transform = (it.card as Card3D).transform
	e.card = ghost
	_toast("%s ativa %s" % [p.name, D.ITEMS[id][0]])
	_push(e)
	await _run_stack()

func _swap_hands() -> void:
	var a: Dictionary = players[0]
	var b: Dictionary = players[1]
	var ha: Array = a.hand
	a.hand = b.hand
	b.hand = ha
	for c in a.hand:
		c.ref = a
		c.reparent(hand_root, true)
	for c in b.hand:
		c.ref = b
		c.reparent(opp_hand_root, true)
	_layout_hand(a)
	_layout_hand(b)
	_ui()

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
			if is_same(it.owner, me):
				var mode: String = info[2]
				if mode in ["tap", "both"]:
					btns.append(["ATIVAR", func(): _close_inspect(); _human_item(it), not it.tapped and _human_has_priority() and _item_usable(it.id)])
				if mode in ["paid", "both"]:
					btns.append(["PAGAR", func(): _close_inspect(); _human_item_paid(it), _human_has_priority() and _paid_usable(it)])
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
			if String(d[8]) != "":
				txt += "\n" + String(d[8])
			var rew := []
			if d[4]: rew.append("%d¢" % d[4])
			if d[5]: rew.append("loot %d" % d[5])
			if d[6]: rew.append("%d tesouro" % d[6])
			if d[7]: rew.append("%d alma" % d[7])
			if String(d[9]) == "rollcents": rew.append("¢ (por rolagem)")
			elif String(d[9]) == "rollloot": rew.append("loot (por rolagem)")
			if not rew.is_empty():
				txt += "\nRecompensa: " + ", ".join(rew)
			var is_top: bool = _find_mon(m.uid) != null
			_open_inspect(m.id, d[0], txt, [["ATACAR", func(): _close_inspect(); _act_attack(me, m.slot), is_top and _human_idle() and me.attacks > 0]])
		"shop":
			var s: int = c.ref
			var info: Array = D.ITEMS[c.id]
			var pr: int = _shop_price(me)
			_open_inspect(c.id, info[0], info[1], [["COMPRAR · %d¢" % pr, func(): _close_inspect(); _act_buy(me, s), _human_idle() and not me.bought and me.coins >= pr]])
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
	if id in ["d6", "spoon", "bookofbelial", "luckyfoot", "minimush", "godhead"]:
		return _top_roll() != null
	if id == "no":
		return _top_cancelable() != null
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
	var me: Dictionary = players[0]
	var target = null
	if _item_needs_target(it.id):
		target = await _choose_target("Escolha o alvo de " + D.ITEMS[it.id][0])
		if target == null:
			return
	await _act_item(me, it, target)

func _paid_needs_target(id: String) -> bool:
	return id in ["goldenrazorblade", "techx", "thebone"]

func _human_item_paid(it: Dictionary) -> void:
	var me: Dictionary = players[0]
	var target = null
	if _paid_needs_target(it.id):
		target = await _choose_target("Escolha o alvo de " + D.ITEMS[it.id][0])
		if target == null:
			return
	await _act_paid(me, it, target)

func _open_inspect(tex_id: String, title: String, text: String, btns: Array) -> void:
	inspect.visible = true
	insp_tex.texture = Card3D.tex(tex_id)
	insp_title.text = title
	insp_text.text = text
	_clear_custom_panel()
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
	for s in slots.size():
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
		var s := -1
		for i in shop.size():
			if shop[i] != null:
				s = i
				break
		if s >= 0:
			await _act_buy(p, s)
			await _wait(0.5)
	# Ataque(s)
	while not turn_over and not game_over and p.attacks > 0 and not p.dead:
		var best := -1
		var best_score := -999.0
		for s in slots.size():
			var m = _top(s)
			if m == null or _has_tag(m, "untargetable"):
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
			for s in slots.size():
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
	if _trinity_blocked(b):
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

# =====================================================================
# AUTOPLAY (teste headless) — só ativo com --autoplay / --autoplay-human
# =====================================================================
var sim_busy := false

# Dirige o jogador humano automaticamente, respondendo aos prompts e
# acionando cartas pelos mesmos caminhos usados pela interface.
func _autoplay_human_loop() -> void:
	await _wait(1.2)
	while not game_over:
		await _wait(0.2)
		if game_over:
			break
		if targeting != "":
			if not target_valid.is_empty():
				target_chosen.emit(target_valid[randi() % target_valid.size()])
			continue
		if waiting_priority:
			priority_event.emit("pass")
			continue
		if awaiting_roll:
			roll_requested.emit()
			continue
		if active == 0 and not busy and stack.is_empty() and not in_combat and not game_over and not sim_busy:
			if turn_over:
				end_turn_requested.emit()
				continue
			if _human_idle():
				_sim_human_action(players[0])

func _sim_human_action(me: Dictionary) -> void:
	sim_busy = true
	if not me.char_tapped and randf() < 0.35:
		_act_tap_char(me)
		await _wait(0.3)
	var guard := 0
	while me.attacks > 0 and not turn_over and not game_over and guard < 4:
		guard += 1
		var s := _sim_pick_monster()
		if s < 0:
			break
		await _act_attack(me, s)
		await _wait(0.3)
	for it in me.items.duplicate():
		if turn_over or game_over:
			break
		if it.tapped:
			continue
		var mode: String = D.ITEMS[it.id][2]
		if mode in ["tap", "both"] and randf() < 0.5:
			await _human_item(it)
		elif mode == "paid" and randf() < 0.5:
			await _human_item_paid(it)
		await _wait(0.2)
	guard = 0
	while _human_can_play_loot() and guard < 3 and not turn_over:
		guard += 1
		var c = _sim_pick_loot(me)
		if c == null:
			break
		await _human_play_loot(c)
		await _wait(0.2)
	for i in shop.size():
		if shop[i] != null and me.coins >= _shop_price(me) and not turn_over:
			await _act_buy(me, i)
			break
	if active == 0 and not turn_over and not game_over:
		end_turn_requested.emit()
	sim_busy = false

func _sim_pick_monster() -> int:
	var best := -1
	for s in slots.size():
		var m = _top(s)
		if m != null and not _has_tag(m, "untargetable"):
			best = s
			break
	return best

func _sim_pick_loot(me: Dictionary):
	for c in me.hand:
		if _loot_playable(c.id):
			return c
	return null

