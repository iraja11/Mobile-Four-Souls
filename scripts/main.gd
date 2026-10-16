extends Node3D
# Four Souls — mesa 2.5D. Você vs. CPU, regras originais (Base Game V2):
# turno = recarregar + loot 1 · ação (1 loot + virar personagem, 1 compra, 1 ataque) · fim (todos curam).
# Pilha LIFO com prioridade, dado na pilha, combate até alguém morrer, penalidade de morte, 4 almas vence.

const D = preload("res://scripts/data.gd")
const Sel = preload("res://scripts/select.gd")  # escolha de personagem + perfil (sequência)
const XP = preload("res://scripts/xp.gd")  # cartas das expansões (FS+, Requiem, Summer, Anniversary)
const FACE_UP := Basis(Vector3.RIGHT, -PI / 2)
const FACE_DOWN := Basis(Vector3.RIGHT, PI / 2)

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
	# Expansões que reaproveitam comportamentos acima (o resto fica em xp.gd, por id).
	"flaminghopper": ["immune6"],
	"sucker": ["boom_death"],
	"charmedkeeper": ["keeperhead_coin"],
	"charmedfatty": ["scolex_discard"],
	"guttedfatty": ["monster_expand_death"],
	"mulligoon": ["noheal"],
	"shopkeeper": ["untargetable"],
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
var font_ui: FontFile  # Upheaval, a mesma do menu
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
const GUPPY_ITEMS := ["guppyshead", "guppyspaw", "guppyscollar", "guppyshairball", "guppyseye"]
var refilling := false
# Expansões: salas (Requiem), alvos atacáveis que não são monstros, estado por turno.
var xp
var room_ids: Array = []
var room_discard: Array = []
var rooms: Array = []        # {id, card, tapped, counters, state}
var xtargets: Array = []     # pseudo-monstros: itens/salas/almas/jogadores atacáveis
var monster_died := false    # algum monstro morreu neste turno (troca de sala no fim)
var combat_damage := false   # o dano em curso é de combate

# ---------------- Game feel ----------------
const HAND_HALF := 0.62        # meia-largura útil da mão (espaço da câmera), deixa o botão livre
var trauma := 0.0              # tremor de câmera (decai; deslocamento ∝ trauma²)
var cam_focus := Vector3.ZERO
var cam_focus_target := Vector3.ZERO
var hitstop_n := 0
var time_base := 1.0           # escala de tempo "normal" (testes automatizados aceleram)
var fx_mats := {}
var soft_tex: GradientTexture2D
var drag_card: Card3D = null
var drag_from := Vector2.ZERO
var drag_active := false

# ---------------- HUD ----------------
var hud: CanvasLayer
var plates: Array = []
var hint_lbl: Label
var stack_panel: PanelContainer
var stack_list: RichTextLabel
var pass_btn: Button
var action_btn: Button
var prompt_panel: PanelContainer
var prompt_lbl: Label
var inspect: Control
var insp_tex: TextureRect
var insp_title: Label
var insp_text: RichTextLabel
var insp_note: PanelContainer
var insp_box: VBoxContainer
var insp_forced := false  # escolha obrigatória: tocar fora não fecha
var insp_btns: HBoxContainer
var flash: ColorRect
var overlay: Control
var feed: VBoxContainer
var banner: Control
var banner_band: Panel
var banner_lbl: Label
var plate_prev: Array = [[], []]
var hud_root: Control
var vig_mat: ShaderMaterial
var danger_on := false
var blood_texs: Array = []
var blood_decals: Array = []
const MAX_DECALS := 28
# Gotas temáticas quando o personagem se fere (Isaac chora, Maggy... sangra corações).
const CHAR_DROPS := {"isaac": Color(0.55, 0.8, 1.0, 0.95), "maggy": Color(1.0, 0.45, 0.6, 0.95)}

func _ready() -> void:
	randomize()
	Engine.time_scale = time_base  # um hit-stop interrompido por "jogar novamente" não pode vazar
	Card3D.touch_mode = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	var fallback := FontFile.new()
	fallback.load_dynamic_font("res://assets/fonts/DejaVuSans.ttf")
	font_b = load("res://assets/fonts/NotoSerif-Bold.ttf")
	font_r = load("res://assets/fonts/NotoSerif-Regular.ttf")
	font_b.fallbacks = [fallback]
	font_r.fallbacks = [fallback]
	font_ui = load("res://assets/fonts/Upheaval.ttf")
	font_ui.fallbacks = [fallback]
	get_viewport().physics_object_picking = true
	xp = XP.new(self)
	_build_world()
	_build_hud()
	if "--autoplay" in OS.get_cmdline_args() or "--autoplay" in OS.get_cmdline_user_args() \
			or "--autoplay-human" in OS.get_cmdline_args() or "--autoplay-human" in OS.get_cmdline_user_args():
		autoplay = true
		autoplay_human = "--autoplay-human" in OS.get_cmdline_args() or "--autoplay-human" in OS.get_cmdline_user_args()
		time_base = 10.0
		Engine.time_scale = time_base
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--seed="):
				seed(int(a.trim_prefix("--seed=")))
		_new_game(D.CHARACTER_ORDER[randi() % D.CHARACTER_ORDER.size()])
		_autoplay_shots()
		if autoplay_human:
			_autoplay_human_loop()
		return
	_fade_in()
	_new_game(Sel.pick())

# Véu preto que some depois dos primeiros quadros (a seleção sai em fade para preto; sem isso a troca de cena piscava cinza).
func _fade_in() -> void:
	var veil := CanvasLayer.new()
	veil.layer = 100
	add_child(veil)
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(r)
	for i in 3:  # espera a compilação de shaders dos primeiros quadros
		await get_tree().process_frame
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.45)
	tw.tween_callback(veil.queue_free)

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if lamp:
		lamp.light_energy = 5.0 * (1.0 + 0.035 * sin(t * 6.3) + 0.025 * sin(t * 17.1))
	for f in flames:
		var l: OmniLight3D = f[1]
		l.light_energy = 0.9 + 0.25 * sin(t * 11.0 + f[2]) + 0.15 * sin(t * 23.0 + f[2])
		var m: Node3D = f[0]
		m.scale = Vector3(1, 1.0 + 0.15 * sin(t * 13.0 + f[2]), 1)
	# Câmera: respiração sutil + foco de combate + tremor por trauma (independe da escala de tempo).
	if cam:
		var rd := delta / maxf(Engine.time_scale, 0.001)
		trauma = maxf(0.0, trauma - rd * 1.6)
		cam_focus = cam_focus.lerp(cam_focus_target, minf(1.0, rd * 4.0))
		var sh := trauma * trauma * 0.045  # discreto: o foco é satisfação, não impacto bruto
		var breathe := Vector3(sin(t * 0.37) * 0.012, sin(t * 0.53) * 0.008, 0)
		var jit := Vector3(sin(t * 47.0) + sin(t * 71.0) * 0.5, sin(t * 53.0 + 2.0) + sin(t * 83.0) * 0.5, 0) * sh
		cam.position = cam_base + cam_focus + breathe + jit
		cam.rotation.z = sin(t * 61.0 + 4.0) * sh * 0.3

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

	soft_tex = GradientTexture2D.new()
	soft_tex.fill = GradientTexture2D.FILL_RADIAL
	soft_tex.fill_from = Vector2(0.5, 0.5)
	soft_tex.fill_to = Vector2(1.0, 0.5)
	soft_tex.width = 64
	soft_tex.height = 64
	var sg := Gradient.new()
	sg.set_color(0, Color(1, 1, 1, 1))
	sg.set_color(1, Color(1, 1, 1, 0))
	sg.add_point(0.35, Color(1, 1, 1, 0.55))
	soft_tex.gradient = sg

	hand_root = Node3D.new()
	# Mão deslocada à esquerda: o botão de ação fica livre no canto inferior direito.
	hand_root.position = Vector3(-0.24, -1.5, -2.1)
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

	# Mesa: tábuas do tabuleiro do TBOI em escala real (antes esticadas ~18 u e borradas), com relevo
	# tirado da própria luminância e veio fino procedural; tapete costurado com as zonas impressas.
	var tbl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	tbl.mesh = pm
	tbl.material_override = _table_material()
	tbl.position = Vector3(0, -0.002, -0.6)
	add_child(tbl)
	var felt := MeshInstance3D.new()
	var fpm := PlaneMesh.new()
	fpm.size = Vector2(4.75, 5.85)
	felt.mesh = fpm
	felt.material_override = _mat_material()
	felt.position = Vector3(0, 0.0, -0.95)
	add_child(felt)
	# Camada 2 = superfícies que recebem respingos (decals não mancham as cartas, que ficam só na camada 1).
	for s in [tbl, felt]:
		s.layers = 3
	for k in 5:
		blood_texs.append(_splat_tex(k * 7919 + 13))

	table = Node3D.new()
	add_child(table)

	# Velas em pratos (grupos de alturas diferentes) e moedas largadas nas margens.
	# Ficam na faixa de madeira do topo: nas laterais a perspectiva "deita" tudo que é vertical.
	_candle_dish(Vector3(-2.0, 0, -4.5), 3)
	_candle_dish(Vector3(2.3, 0, -4.75), 1)
	_coin_pile(Vector3(1.5, 0, -4.25), 6)
	_coin_pile(Vector3(-1.05, 0, -4.15), 2)

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
			["discard", "lootback", "DESCARTE", Vector3(1.65, 0, -1.55)],
			["room", "roomback", "SALAS", Vector3(-1.65, 0, -2.42)]]:
		var dk := Deck3D.new()
		table.add_child(dk)
		dk.setup(d[1], d[2], font_ui)
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
	opp_hand_root.position = Vector3(0, 0.95, -3.4)
	opp_hand_root.rotation = Vector3(-0.55, PI, 0)
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

func _table_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 wp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
float lum(vec2 uv) { return dot(texture(tex, uv).rgb, vec3(0.33)); }
void fragment() {
	// 10 × 5 u por cópia, centrada sob o tapete; espelhada para não emendar.
	vec2 uv = (wp - vec2(0.0, -1.0)) / vec2(10.0, 5.0) + 0.5;
	uv = abs(mod(uv + 1.0, 2.0) - 1.0);
	vec3 c = texture(tex, uv).rgb;
	// Veio fino ao longo das tábuas + manchas grandes: esconde a baixa resolução da textura.
	float grain = n(vec2(wp.x * 3.0, wp.y * 60.0)) * 0.6 + n(vec2(wp.x * 9.0, wp.y * 160.0)) * 0.4;
	float blot = n(wp * 0.9) * 0.6 + n(wp * 2.7) * 0.4;
	c *= mix(0.82, 1.08, grain) * mix(0.75, 1.05, blot);
	ALBEDO = c * vec3(0.78, 0.64, 0.54);
	vec2 e = vec2(1.5 / 1080.0, 1.5 / 540.0);
	float dx = lum(uv + vec2(e.x, 0.0)) - lum(uv - vec2(e.x, 0.0));
	float dy = lum(uv + vec2(0.0, e.y)) - lum(uv - vec2(0.0, e.y));
	NORMAL_MAP = normalize(vec3(-dx * 6.0, -dy * 6.0, 1.0)) * 0.5 + 0.5;
	ROUGHNESS = mix(0.55, 0.85, grain);
	SPECULAR = 0.35;
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tex", load("res://assets/table.jpg"))
	return m

# Tapete de jogo: tecido bordô quase preto, borda enrolada com costura dourada, zonas impressas
# (cantos de moldura em tinta desbotada) e um selo de pentagrama apagado entre monstros e loja.
func _mat_material() -> ShaderMaterial:
	var zones := []  # [cx, cz, meia-largura, meia-altura]
	var cw := Card3D.W / 2 + 0.06
	var chh := Card3D.H / 2 + 0.06
	for c in [Vector2(-1.65, -1.55), Vector2(-1.65, -0.3), Vector2(1.65, -0.3), Vector2(1.65, -1.55),
			Vector2(-0.55, -1.55), Vector2(0.55, -1.55), Vector2(-0.55, -0.3), Vector2(0.55, -0.3),
			Vector2(-1.65, 0.95), Vector2(1.65, -3.0)]:
		zones.append([c.x, c.y, cw, chh])
	zones.append([0.15, 0.95, 1.18, chh * 0.9])    # seus itens
	zones.append([-0.15, -3.0, 1.18, chh * 0.9])   # itens da CPU
	var zs := PackedStringArray()
	for z in zones:
		zs.append("vec4(%f, %f, %f, %f)" % z)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
const int NZ = %d;
const vec4 Z[NZ] = vec4[NZ](%s);
const vec2 CEN = vec2(0.0, -0.95);
const vec2 HALF = vec2(2.375, 2.925);
varying vec2 wp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float box(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
float seg(vec2 p, vec2 a, vec2 b) { vec2 pa = p - a, ba = b - a; return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0)); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 p = wp - CEN;
	float aa = fwidth(p.x) * 1.5;
	// Tecido: trama fina (some com a distância) + manchas de uso, mais claro no meio onde se joga.
	float weave = (sin(wp.x * 420.0) * sin(wp.y * 420.0)) * (1.0 - smoothstep(0.004, 0.012, aa));
	float mott = n(wp * 1.3) * 0.5 + n(wp * 4.0) * 0.3 + n(wp * 13.0) * 0.2;
	vec3 base = vec3(0.07, 0.022, 0.02) * mix(0.8, 1.15, mott) * (1.0 + weave * 0.06);
	base *= mix(1.12, 0.8, smoothstep(0.6, 1.0, length(p / HALF)));
	float ink = 0.0;
	// Zonas: moldura arredondada fraca + cantos marcados.
	for (int i = 0; i < NZ; i++) {
		vec2 q = p + CEN - Z[i].xy;
		float d = box(q, Z[i].zw, 0.05);
		float line = 1.0 - smoothstep(0.0, 0.006 + aa, abs(d));
		vec2 cq = abs(q) - (Z[i].zw - 0.12);
		float corner = step(0.0, cq.x) * step(0.0, cq.y);
		ink = max(ink, line * mix(0.28, 0.85, corner));
	}
	// Selo apagado: círculo duplo + pentagrama entre monstros e loja.
	vec2 s = wp - vec2(0.0, -0.93);
	float r = length(s);
	float sig = 1.0 - smoothstep(0.0, 0.007 + aa, abs(r - 0.36));
	sig = max(sig, 1.0 - smoothstep(0.0, 0.005 + aa, abs(r - 0.33)));
	for (int k = 0; k < 5; k++) {
		float a0 = 6.2831853 * float(k) / 5.0 - 1.5707963;
		float a1 = 6.2831853 * float(k + 2) / 5.0 - 1.5707963;
		sig = max(sig, 1.0 - smoothstep(0.0, 0.005 + aa, seg(s, 0.33 * vec2(cos(a0), -sin(a0)), 0.33 * vec2(cos(a1), -sin(a1)))));
	}
	ink = max(ink, sig * 0.35);
	vec3 col = mix(base, vec3(0.5, 0.33, 0.2), ink * 0.32 * mix(0.6, 1.0, mott));
	// Borda enrolada (mais escura e com volume) e costura tracejada dourada.
	float de = -box(p, HALF, 0.12);
	float rim = 1.0 - smoothstep(0.0, 0.09, de);
	col *= 1.0 - rim * 0.45;
	float st = 1.0 - smoothstep(0.0, 0.009 + aa, abs(de - 0.13));
	float dash = step(0.45, fract((abs(p.x) > HALF.x - 0.25 ? p.y : p.x) * 14.0));
	col = mix(col, vec3(0.62, 0.45, 0.22), st * dash * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	NORMAL_MAP = normalize(vec3(weave * 0.08, weave * 0.08, 1.0)) * 0.5 + 0.5;
}""" % [zones.size(), ", ".join(zs)]
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _wax_mat() -> StandardMaterial3D:
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.72, 0.64, 0.5)
	wax.roughness = 0.45
	wax.rim_enabled = true
	wax.rim = 0.4
	wax.rim_tint = 0.8
	# Cera translúcida: deixa a luz "vazar" perto da chama.
	wax.backlight_enabled = true
	wax.backlight = Color(0.45, 0.22, 0.08)
	return wax

# Prato de ferro com `n` velas de alturas diferentes, poça de cera e pingos.
func _candle_dish(pos: Vector3, n: int) -> void:
	var dish := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.2 + 0.05 * n
	dm.bottom_radius = 0.17 + 0.05 * n
	dm.height = 0.035
	dish.mesh = dm
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.13, 0.11)
	iron.metallic = 0.8
	iron.roughness = 0.45
	dish.material_override = iron
	dish.position = pos + Vector3(0, 0.017, 0)
	add_child(dish)
	var pool := MeshInstance3D.new()
	var pmm := CylinderMesh.new()
	pmm.top_radius = dm.top_radius * 0.8
	pmm.bottom_radius = dm.top_radius * 0.82
	pmm.height = 0.012
	pool.mesh = pmm
	pool.material_override = _wax_mat()
	pool.position = pos + Vector3(0, 0.04, 0)
	add_child(pool)
	var offs := [Vector3.ZERO] if n == 1 else [Vector3(-0.09, 0, 0.04), Vector3(0.1, 0, -0.03), Vector3(0.0, 0, 0.12)]
	for k in n:
		_candle(pos + offs[k] + Vector3(0, 0.045, 0), [0.6, 0.38, 0.27][k] * randf_range(0.85, 1.1))

func _candle(pos: Vector3, h: float) -> void:
	var wax := _wax_mat()
	var r := randf_range(0.065, 0.08)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.95
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 20
	body.mesh = cm
	body.material_override = wax
	body.position = pos + Vector3(0, h / 2, 0)
	add_child(body)
	# Borda derretida no topo + escorridos descendo pelo corpo.
	var lip := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.7
	tm.outer_radius = r * 1.02
	tm.rings = 16
	lip.mesh = tm
	lip.material_override = wax
	lip.position = pos + Vector3(0, h - 0.005, 0)
	lip.scale = Vector3(1, 0.45, 1)
	add_child(lip)
	for k in randi_range(3, 5):
		var a := randf() * TAU
		var dl := randf_range(0.06, h * 0.7)
		var drip := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = randf_range(0.009, 0.016)
		cap.height = dl
		drip.mesh = cap
		drip.material_override = wax
		drip.position = pos + Vector3(cos(a) * r * 0.96, h - dl / 2 + 0.01, sin(a) * r * 0.96)
		add_child(drip)
	var wick := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.004
	wm.bottom_radius = 0.005
	wm.height = 0.04
	wick.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.05, 0.04, 0.03)
	wick.material_override = wmat
	wick.position = pos + Vector3(0, h + 0.015, 0)
	add_child(wick)
	# Chama: lágrima em shader (núcleo azul na base, corpo laranja, ponta que tremula) + halo.
	var flame := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.13, 0.28)
	flame.mesh = q
	var fs := Shader.new()
	fs.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float ph = 0.0;
void vertex() {
	// Billboard: a câmera olha de cima, então "para cima na tela" lê como chama de pé.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float t = TIME * 9.0 + ph;
	VERTEX.x += (sin(t) * 0.6 + sin(t * 2.3) * 0.4) * 0.018 * smoothstep(-0.04, 0.14, VERTEX.y);
}
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float y = 1.0 - UV.y;
	float w = mix(0.75, 0.0, pow(y, 1.3)) * (0.6 + 0.4 * smoothstep(0.0, 0.25, y));
	float d = abs(uv.x) / max(w, 0.001);
	float a = (1.0 - smoothstep(0.55, 1.0, d)) * smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(0.85, 1.0, y));
	vec3 core = vec3(0.35, 0.5, 1.0);
	vec3 body = mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.92, 0.6), 1.0 - d);
	vec3 c = mix(core, body, smoothstep(0.05, 0.3, y));
	ALBEDO = c * a * 3.2;
}"""
	var fm := ShaderMaterial.new()
	fm.shader = fs
	fm.set_shader_parameter("ph", randf() * 10.0)
	flame.material_override = fm
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = pos + Vector3(0, h + 0.11, 0)
	add_child(flame)
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(0.8, 0.8)
	halo.mesh = hq
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_texture = soft_tex
	hm.albedo_color = Color(1.0, 0.5, 0.18, 0.35)
	hm.no_depth_test = false
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = pos + Vector3(0, h + 0.1, 0)
	add_child(halo)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.omni_range = 2.8
	l.position = pos + Vector3(0, h + 0.15, 0)
	add_child(l)
	flames.append([flame, l, randf() * 10.0])
	# Brasas subindo da chama
	var em := CPUParticles3D.new()
	em.amount = 5
	em.lifetime = 1.6
	em.preprocess = 2.0
	em.direction = Vector3.UP
	em.spread = 18
	em.initial_velocity_min = 0.08
	em.initial_velocity_max = 0.22
	em.gravity = Vector3(0, 0.05, 0)
	em.scale_amount_min = 0.012
	em.scale_amount_max = 0.03
	em.color = Color(1.0, 0.55, 0.2)
	em.color_ramp = _fade_ramp()
	em.mesh = _fx_quad(true)
	em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	em.position = pos + Vector3(0, h + 0.12, 0)
	add_child(em)

# Moedas largadas: pilha torta (n > 2) ou soltas, douradas e gastas.
func _coin_pile(pos: Vector3, n: int) -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.78, 0.55, 0.18)
	gold.metallic = 0.9
	gold.roughness = 0.38
	var cm := CylinderMesh.new()
	cm.top_radius = 0.075
	cm.bottom_radius = 0.075
	cm.height = 0.014
	cm.radial_segments = 20
	for k in n:
		var c := MeshInstance3D.new()
		c.mesh = cm
		c.material_override = gold
		if n > 2 and k < 3:
			c.position = pos + Vector3(randf_range(-0.012, 0.012), 0.008 + k * 0.0145, randf_range(-0.012, 0.012))
			c.rotation = Vector3(randf_range(-0.04, 0.04), randf() * TAU, randf_range(-0.04, 0.04))
		else:
			var a := randf() * TAU
			c.position = pos + Vector3(cos(a), 0, sin(a)) * randf_range(0.12, 0.2) + Vector3(0, 0.008, 0)
			c.rotation = Vector3(randf_range(-0.05, 0.05), randf() * TAU, 0)
		add_child(c)

func _label3d(txt: String, sz: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font = font_ui
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

# Salas (Requiem): cartas horizontais numa fileira entre os monstros e os itens do oponente.
func _room_xf(i: int) -> Transform3D:
	var n: int = max(rooms.size(), 1)
	var x: float = (i - (n - 1) / 2.0) * 0.95
	return _flat(Vector3(x, 0.01, -2.33), PI / 2).scaled_local(Vector3.ONE * 0.8)

func _stack_xf(i: int) -> Transform3D:
	var pos := Vector3(-0.35 + i * 0.22, 1.25 + i * 0.03, 0.15 + i * 0.03)
	var b := Basis.looking_at(pos - cam.position).scaled(Vector3.ONE * 0.85)
	return Transform3D(b, pos)

func _hand_xf(i: int, n: int, sel: bool) -> Transform3D:
	# O leque sempre cabe na largura útil da tela (antes cartas saíam pelas bordas com 5+ na mão).
	var r := 3.2
	var max_total := 2.0 * asin(HAND_HALF / r)
	var spread: float = min(0.15, max_total / max(n - 1, 1))
	var a := (i - (n - 1) / 2.0) * spread
	var pos := Vector3(sin(a) * r, cos(a) * r - r, i * 0.006)
	var sc := 0.74
	if sel:
		pos += Vector3(0, 0.42, 0.25)
		sc = 0.95
	return Transform3D(Basis(Vector3.BACK, -a).scaled(Vector3.ONE * sc), pos)

func _opp_hand_xf(i: int, n: int) -> Transform3D:
	var r := 3.0
	var spread: float = min(0.2, 1.2 / max(n - 1, 1))
	var a := (i - (n - 1) / 2.0) * spread
	var pos := Vector3(sin(a) * r, cos(a) * r - r, -i * 0.006)
	return Transform3D(Basis(Vector3.BACK, -a).scaled(Vector3.ONE * 1.15), pos)

# =====================================================================
# HUD 2D
# =====================================================================
# Mesmo vocabulário visual do menu/seleção: papel do TBOI (recortes de seedentry.png), tinta e Upheaval.
const HUD := "res://assets/ui/hud/"
const INK := Color8(55, 43, 44)
const INK_HOT := Color8(140, 32, 44)
const INK_SOFT := Color8(110, 88, 90)
const INK_BLUE := Color8(42, 72, 120)
const INK_GREEN := Color8(40, 96, 52)
const PAPER := Color8(233, 218, 223)

# Papel rasgado como nine-patch: "paper" = folha grande (2×, inspeção/faixa); "paper_s" = a mesma folha 1×
# (placas, botões, pilha); "scrap" = retalho pardo 1× (botões secundários, avisos). `pad` soma à borda rasgada.
const PAPER_M := {"paper": [32, 40, 24, 36], "paper_s": [15, 20, 11, 18], "scrap": [9, 12, 7, 11]}

func _paper(kind := "paper_s", tint := Color.WHITE, pad := Vector2(6, 2)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(HUD + kind + ".png")
	var m: Array = PAPER_M[kind]
	sb.texture_margin_left = m[0]
	sb.texture_margin_right = m[1]
	sb.texture_margin_top = m[2]
	sb.texture_margin_bottom = m[3]
	sb.content_margin_left = m[0] + pad.x
	sb.content_margin_right = m[1] + pad.x - 4
	sb.content_margin_top = m[2] + pad.y - 3
	sb.content_margin_bottom = m[3] + pad.y - 5
	sb.modulate_color = tint
	return sb

func _lbl(txt: String, sz: int, col := Color(0.93, 0.88, 0.8), bold := false) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font_b if bold else font_r)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

# Rótulo na fonte do menu (Upheaval); `outline` > 0 para texto solto sobre a mesa.
func _ulbl(txt: String, sz: int, col := INK, outline := 0) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font_ui)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.03, 0.015, 0.01, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _icon(file: String, sz: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(HUD + file)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(sz, sz)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

# Ícones embutidos em RichTextLabel: coração, moeda, espada, caveira e faces do dado vermelho.
func _ic(name: String, sz := 20) -> String:
	match name:
		"sword":
			return "[img=%dx%d]res://assets/ui/select/sword.png[/img]" % [sz, sz]
	return "[img=%dx%d]%s%s.png[/img]" % [sz, sz, HUD, name]

func _ic_die(v: int, sz := 20) -> String:
	return "[img=%dx%d region=%d,0,128,128]%sdie.png[/img]" % [sz, sz, (clampi(v, 1, 6) - 1) * 128, HUD]

# Carta em 2D com os mesmos cantos arredondados (e espessura sugerida) da Card3D.
var _card_mat_cache: ShaderMaterial
func _card_mat() -> ShaderMaterial:
	if _card_mat_cache:
		return _card_mat_cache
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec2 rad = vec2(%f, %f);
uniform float shine = -1.0;
void fragment() {
	vec2 q = abs(UV - 0.5) - (vec2(0.5) - rad);
	float d = length(max(q / rad, 0.0)) - 1.0;
	float aa = fwidth(d) * 1.2;
	vec4 c = COLOR;  // já é textura × modulate
	// Borda fina mais escura + leve verniz no alto: lê como cartão, não como png colado.
	float rim = min(min(UV.x, 1.0 - UV.x) / rad.x, min(UV.y, 1.0 - UV.y) / rad.y);
	float e = min(rim, -d);
	c.rgb *= mix(0.7, 1.0, smoothstep(0.2, 0.6, e));
	// Fio claro de papelão na borda, como a espessura da Card3D no campo.
	c.rgb = mix(c.rgb, vec3(0.86, 0.82, 0.74) * mix(0.8, 1.0, UV.y), 1.0 - smoothstep(0.17, 0.23, e));
	c.rgb += vec3(1.0, 0.95, 0.85) * 0.05 * smoothstep(0.55, 0.0, UV.y);
	float diag = (UV.x + UV.y) * 0.5;
	c.rgb += vec3(1.0, 0.92, 0.75) * 0.5 * (1.0 - smoothstep(0.0, 0.07, abs(diag - shine)));
	c.a *= 1.0 - smoothstep(-aa, aa, d);
	COLOR = c;
}""" % [Card3D.RADIUS / Card3D.W, Card3D.RADIUS / Card3D.H]
	_card_mat_cache = ShaderMaterial.new()
	_card_mat_cache.shader = sh
	return _card_mat_cache

func _rich(sz: int, col := INK, f: Font = null) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_override("normal_font", f if f else font_r)
	r.add_theme_font_override("bold_font", f if f else font_b)
	r.add_theme_font_size_override("normal_font_size", sz)
	r.add_theme_font_size_override("bold_font_size", sz)
	r.add_theme_color_override("default_color", col)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# Cores dos avisos foram pensadas para fundo escuro; no papel viram tinta do mesmo "sentido".
func _ink_of(c: Color) -> Color:
	if c.r > c.g + 0.25 and c.r > c.b + 0.2:
		return INK_HOT
	if c.b > c.r + 0.1:
		return INK_BLUE
	if c.g > c.r + 0.1:
		return INK_GREEN
	return INK

func _btn(txt: String, cb: Callable, primary := true) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_override("font", font_ui)
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(150, 52)
	var kind := "paper_s" if primary else "scrap"
	var n := _paper(kind)
	var h := _paper(kind, Color(1.0, 0.94, 0.9))
	var pr := _paper(kind, Color(0.86, 0.78, 0.76))
	var dis := _paper(kind, Color(0.7, 0.66, 0.66, 0.8))
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, INK_HOT if primary else INK)
	b.add_theme_color_override("font_disabled_color", Color8(95, 80, 82))
	b.pressed.connect(Sfx.play.bind("ui_click"))
	b.pressed.connect(cb)
	# Resposta tátil: afunda ao tocar, volta com mola.
	b.button_down.connect(func():
		b.pivot_offset = b.size / 2
		b.create_tween().tween_property(b, "scale", Vector2(0.92, 0.92), 0.06))
	b.button_up.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b

# Pulso de atenção num botão (prioridade, rolar ataque): o papel "esquenta" em vermelho.
func _set_pulse(b: Button, on: bool) -> void:
	var tw: Tween = b.get_meta("pulse_tw") if b.has_meta("pulse_tw") else null
	if on == (tw != null and tw.is_valid()):
		return
	if tw:
		tw.kill()
		b.remove_meta("pulse_tw")
		b.self_modulate = Color.WHITE
	if on:
		tw = b.create_tween().set_loops()
		tw.tween_property(b, "self_modulate", Color(1.0, 0.72, 0.68), 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "self_modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)
		b.set_meta("pulse_tw", tw)

# Almas em direção às 4: bolinhas cheias/vazias leem mais rápido que "2/4".
class SoulPips extends Control:
	var n := 0:
		set(v):
			n = v
			queue_redraw()
	var total := 4

	func _init() -> void:
		custom_minimum_size = Vector2(4 * 14 + 2, 22)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for k in total:
			var c := Vector2(7 + k * 14, size.y / 2)
			if k < n:
				draw_circle(c, 6.5, Color8(55, 43, 44))
				draw_circle(c, 4.8, Color8(150, 200, 240))
				draw_circle(c + Vector2(-1.5, -1.5), 1.8, Color(1, 1, 1, 0.85))
			else:
				draw_circle(c, 3.0, Color8(110, 88, 90, 110))

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
uniform float danger = 0.0;
void fragment(){
	float d = distance(UV, vec2(0.5, 0.45));
	float v = smoothstep(0.32, 0.85, d) * 0.85;
	float g = (h(UV * 731.0 + fract(TIME * 7.0)) - 0.5) * 0.06;
	// Batimento (tum-tum) nas bordas quando o jogador está com 1 de vida.
	float ph = mod(TIME, 1.15);
	float beat = exp(-ph * 9.0) + 0.7 * exp(-max(ph - 0.24, 0.0) * 9.0) * step(0.24, ph);
	float red = clamp(danger * (0.3 + 0.7 * beat) * smoothstep(0.25, 0.8, d), 0.0, 1.0);
	COLOR = vec4(mix(vec3(0.0) + g, vec3(0.45, 0.0, 0.02), red), clamp(v + abs(g) + red * 0.5, 0.0, 1.0));
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vig.material = sm
	vig_mat = sm
	sm.set_shader_parameter("danger", 0.0)
	post.add_child(vig)

	hud = CanvasLayer.new()
	hud.layer = 1
	add_child(hud)
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.6, 0, 0, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	hud_root = root
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

	# Placas dos jogadores: bilhetes de papel; a tachinha marca de quem é o turno.
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -62
	top.offset_top = 8
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	for i in 2:
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_theme_stylebox_override("panel", _paper("paper_s", Color.WHITE, Vector2(2, 0)))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		pc.add_child(v)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		var name_l := _ulbl("", 17, INK_SOFT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var skull := _icon("skull.png", 18)
		skull.visible = false
		head.add_child(name_l)
		head.add_child(skull)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var hp_l := _ulbl("", 24, INK)
		var coin_l := _ulbl("", 24, INK)
		var souls := SoulPips.new()
		row.add_child(_icon("heart.png", 22))
		row.add_child(hp_l)
		row.add_child(_gap(8))
		row.add_child(_icon("coin.png", 21))
		row.add_child(coin_l)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sp)
		row.add_child(souls)
		v.add_child(head)
		v.add_child(row)
		var tack := Sel.Tack.new()
		tack.position = Vector2(0, 7)
		tack.scale = Vector2(0.7, 0.7)
		tack.visible = false
		pc.add_child(tack)
		top.add_child(pc)
		plates.append({"pc": pc, "name": name_l, "hp": hp_l, "coin": coin_l, "souls": souls, "skull": skull, "row": row, "tack": tack})
	# Menu de pausa (antes não havia como sair da partida sem fechar o jogo).
	var menu_b := _btn("II", _open_pause, false)
	menu_b.custom_minimum_size = Vector2(50, 50)
	menu_b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_b.offset_left = -58
	menu_b.offset_right = -6
	menu_b.offset_top = 14
	menu_b.offset_bottom = 64
	root.add_child(menu_b)

	# Feed de mensagens: retalhos de papel sob a faixa de turno, até 3, cada um some sozinho.
	feed = VBoxContainer.new()
	feed.set_anchors_preset(Control.PRESET_CENTER_TOP)
	feed.offset_left = -210
	feed.offset_right = 210
	feed.offset_top = 80
	feed.offset_bottom = 170
	feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	feed.add_theme_constant_override("separation", 2)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feed)

	# Faixa de turno: tira de papel que atravessa a tela.
	banner = Control.new()
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	root.add_child(banner)
	banner_band = Panel.new()
	banner_band.add_theme_stylebox_override("panel", _paper("paper"))
	banner_band.anchor_left = 0
	banner_band.anchor_right = 1
	banner_band.anchor_top = 0.43
	banner_band.anchor_bottom = 0.43
	banner_band.offset_left = -14
	banner_band.offset_right = 14
	banner_band.offset_top = -44
	banner_band.offset_bottom = 44
	banner_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(banner_band)
	banner_lbl = _ulbl("", 40, INK_HOT)
	banner_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_band.add_child(banner_lbl)

	# Pilha: bilhete com a ordem de resolução (topo primeiro) e o PASSAR.
	stack_panel = PanelContainer.new()
	stack_panel.add_theme_stylebox_override("panel", _paper("paper_s", Color.WHITE, Vector2(8, 4)))
	stack_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stack_panel.offset_left = -180
	stack_panel.offset_right = 180
	stack_panel.offset_top = 132
	stack_panel.visible = false
	root.add_child(stack_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	stack_panel.add_child(sv)
	sv.add_child(_ulbl("PILHA · resolve de cima para baixo", 16, INK_SOFT))
	stack_list = _rich(16)
	stack_list.custom_minimum_size = Vector2(316, 0)
	sv.add_child(stack_list)
	pass_btn = _btn("PASSAR", _on_pass)
	pass_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sv.add_child(pass_btn)

	hint_lbl = _ulbl("", 18, PAPER, 6)
	hint_lbl.anchor_left = 0
	hint_lbl.anchor_right = 1
	hint_lbl.anchor_top = 0.69
	hint_lbl.anchor_bottom = 0.69
	hint_lbl.offset_left = 12
	hint_lbl.offset_right = -12
	hint_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint_lbl)

	# Botão estreito de duas linhas no canto: a mão (deslocada à esquerda) não fica embaixo dele.
	action_btn = _btn("ENCERRAR\nTURNO", _on_action)
	action_btn.add_theme_font_size_override("font_size", 21)
	action_btn.custom_minimum_size = Vector2(118, 70)
	action_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_btn.offset_left = -126
	action_btn.offset_right = -8
	action_btn.offset_top = -82
	action_btn.offset_bottom = -12
	action_btn.visible = false
	root.add_child(action_btn)

	# Prompt de alvo
	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", _paper("paper_s", Color.WHITE, Vector2(6, 2)))
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prompt_panel.offset_left = -220
	prompt_panel.offset_right = 220
	prompt_panel.offset_top = 104
	prompt_panel.visible = false
	root.add_child(prompt_panel)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 8)
	prompt_panel.add_child(ph)
	prompt_lbl = _ulbl("", 20, INK_HOT)
	prompt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ph.add_child(prompt_lbl)
	var cb := _btn("CANCELAR", func(): target_chosen.emit(null), false)
	cb.custom_minimum_size = Vector2(120, 48)
	ph.add_child(cb)

	# Inspeção de carta: carta grande, título na fonte do menu, texto num bilhete com ícones.
	inspect = ColorRect.new()
	(inspect as ColorRect).color = Color(0, 0, 0, 0.78)
	inspect.set_anchors_preset(Control.PRESET_FULL_RECT)
	inspect.visible = false
	inspect.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and not insp_forced:
			_close_inspect())
	root.add_child(inspect)
	insp_box = VBoxContainer.new()
	insp_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	insp_box.offset_left = 16
	insp_box.offset_right = -16
	insp_box.alignment = BoxContainer.ALIGNMENT_CENTER
	insp_box.add_theme_constant_override("separation", 10)
	insp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect.add_child(insp_box)
	insp_tex = TextureRect.new()
	insp_tex.material = _card_mat().duplicate()
	# Sombra projetada atrás da carta (a carta "flutua" sobre a mesa escurecida).
	var shadow := Panel.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0, 0, 0, 0.55)
	ssb.set_corner_radius_all(int(Card3D.RADIUS / Card3D.W * 360))
	ssb.shadow_color = Color(0, 0, 0, 0.55)
	ssb.shadow_size = 22
	ssb.shadow_offset = Vector2(8, 14)
	shadow.add_theme_stylebox_override("panel", ssb)
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = 4
	shadow.offset_right = -4
	shadow.offset_top = 4
	shadow.offset_bottom = -4
	shadow.show_behind_parent = true
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	insp_tex.add_child(shadow)
	insp_tex.custom_minimum_size = Vector2(360, 492)
	insp_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	insp_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	insp_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	insp_box.add_child(insp_tex)
	insp_title = _ulbl("", 32, PAPER, 8)
	insp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	insp_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	insp_box.add_child(insp_title)
	insp_note = PanelContainer.new()
	insp_note.add_theme_stylebox_override("panel", _paper("paper", Color.WHITE, Vector2(4, 0)))
	insp_note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	insp_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	insp_box.add_child(insp_note)
	insp_text = _rich(21, INK, font_ui)
	insp_text.add_theme_constant_override("line_separation", 2)
	insp_text.custom_minimum_size = Vector2(420, 0)
	insp_note.add_child(insp_text)
	insp_btns = HBoxContainer.new()
	insp_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	insp_btns.add_theme_constant_override("separation", 10)
	insp_box.add_child(insp_btns)

	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color(0.02, 0.012, 0.01, 0.94)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	root.add_child(overlay)

func _gap(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _open_pause() -> void:
	if game_over or overlay.visible:
		return
	if inspect.visible and insp_forced:
		return
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	for o in [["CONTINUAR", _close_inspect, true], ["DESISTIR E IR AO MENU", _to_menu, false]]:
		var b := _btn(o[0], o[1], o[2])
		b.custom_minimum_size = Vector2(300, 56)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(b)
	_open_custom_panel("PAUSA", vb)
	insp_forced = false

func _apply_safe_area() -> void:
	# Notch / barra de gestos no celular: afasta o HUD das bordas inseguras.
	if hud_root == null or not OS.has_feature("mobile"):
		return
	var safe := DisplayServer.get_display_safe_area()
	var scr := Vector2(DisplayServer.screen_get_size())
	var vis := get_viewport().get_visible_rect().size
	if scr.x <= 0 or scr.y <= 0:
		return
	var k := vis / scr
	hud_root.offset_left = safe.position.x * k.x
	hud_root.offset_top = safe.position.y * k.y
	hud_root.offset_right = -(scr.x - safe.end.x) * k.x
	hud_root.offset_bottom = -(scr.y - safe.end.y) * k.y

func _toast(msg: String, col := Color(1, 0.93, 0.8)) -> void:
	if autoplay:
		print("[log] ", msg)  # log legível das partidas headless
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _paper("scrap", Color.WHITE, Vector2(8, 2)))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := _ulbl(msg, 19, _ink_of(col))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if msg.length() > 30:
		# Só quebra linha com largura definida; num container encolhido o autowrap vira uma letra por linha.
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 360
	pc.add_child(l)
	feed.add_child(pc)
	while feed.get_child_count() > 2:
		var old := feed.get_child(0)
		feed.remove_child(old)
		old.queue_free()
	pc.modulate.a = 0
	pc.scale = Vector2(0.8, 0.8)
	var t := pc.create_tween()
	t.tween_callback(func():
		pc.pivot_offset = pc.size / 2
		pc.rotation = randf_range(-0.025, 0.025))
	t.tween_property(pc, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(pc, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(2.2)
	t.tween_property(pc, "modulate:a", 0.0, 0.35)
	t.tween_callback(pc.queue_free)

func _banner(msg: String, col := Color(1, 0.9, 0.7)) -> void:
	banner.visible = true
	banner_lbl.text = msg
	banner_lbl.add_theme_color_override("font_color", _ink_of(col))
	var w := get_viewport().get_visible_rect().size.x
	banner_band.pivot_offset = Vector2(w / 2, 44)
	banner_band.scale = Vector2(1, 0)
	banner_lbl.position.x = -w
	var t := banner.create_tween()
	t.tween_property(banner_band, "scale:y", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(banner_lbl, "position:x", 0.0, 0.38).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.55)
	t.tween_property(banner_lbl, "position:x", w, 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(banner_band, "scale:y", 0.0, 0.2).set_delay(0.12)
	t.tween_callback(func(): banner.visible = false)

func _ui() -> void:
	if players.is_empty():
		return
	for i in 2:
		var p: Dictionary = players[i]
		var pl: Dictionary = plates[i]
		var mine: bool = active == i and not game_over
		(pl.pc as Control).self_modulate = Color.WHITE if mine else Color(0.78, 0.74, 0.74)
		(pl.tack as Control).visible = mine
		(pl.tack as Control).position.x = (pl.pc as Control).size.x - 30
		(pl.name as Label).text = ("VOCÊ · " if i == 0 else "CPU · ") + p.name.to_upper()
		(pl.name as Label).add_theme_color_override("font_color", INK_HOT if mine else INK_SOFT)
		(pl.skull as Control).visible = p.dead
		(pl.hp as Label).text = "%d/%d" % [max(p.hp, 0), _max_hp(p)]
		(pl.hp as Label).add_theme_color_override("font_color", INK_HOT if p.hp <= 1 else INK)
		(pl.coin as Label).text = str(p.coins)
		(pl.souls as SoulPips).total = D.SOULS_TO_WIN
		(pl.souls as SoulPips).n = p.soul_n
		_plate_feedback(i, pl.row, [max(p.hp, 0), p.coins, p.soul_n])
	var me: Dictionary = players[0]
	var danger: bool = me.hp == 1 and not me.dead and not game_over
	if danger != danger_on:
		danger_on = danger
		var from: float = vig_mat.get_shader_parameter("danger")
		create_tween().tween_method(func(x: float): vig_mat.set_shader_parameter("danger", x), from, 1.0 if danger else 0.0, 0.6)
	# Pilha
	stack_panel.visible = not stack.is_empty()
	var lines := []
	for i in range(stack.size() - 1, -1, -1):
		var top: bool = i == stack.size() - 1
		var t := _entry_text(stack[i])
		lines.append(("[b]%s[/b]" % t) if top else "[color=#6e585a]%s[/color]" % t)
	stack_list.text = "\n".join(lines)
	pass_btn.visible = waiting_priority
	_set_pulse(pass_btn, waiting_priority)
	# A pilha e o prompt ocupam o lugar da dica e do feed: nada se sobrepõe.
	feed.visible = stack.is_empty() and targeting == ""
	# Botão de ação
	action_btn.visible = false
	var roll_ready := false
	if active == 0 and not game_over and targeting == "":
		if awaiting_roll:
			action_btn.visible = true
			action_btn.text = "ROLAR\nATAQUE"
			action_btn.disabled = busy or not stack.is_empty()
			roll_ready = not action_btn.disabled
		elif _human_idle():
			action_btn.visible = true
			action_btn.text = "ENCERRAR\nTURNO"
			action_btn.disabled = false
	_set_pulse(action_btn, roll_ready)
	# Dica (some quando a pilha está aberta: o bilhete já diz o que fazer)
	var hint := ""
	if waiting_priority:
		hint = ""
	elif awaiting_roll:
		hint = ""
	elif _human_idle():
		var parts := []
		if me.loot_plays > 0 and not me.hand.is_empty(): parts.append("")
		if me.bought < me.buy_limit and me.coins >= D.SHOP_PRICE: parts.append("")
		hint = " ".join(parts)
		if hint != "": hint = hint[0].to_upper() + hint.substr(1) + ""
	hint_lbl.text = hint
	hint_lbl.visible = stack.is_empty() and targeting == ""
	_update_monster_labels()

func _entry_text(e: Dictionary) -> String:
	var who: String = "Você" if e.owner.i == 0 else e.owner.name
	if e.kind == "roll":
		var b := " [color=#284878]+%d[/color]" % e.bonus if e.bonus else ""
		return "%s %s%s → %d · %s" % [who, _ic_die(e.value, 20), b, e.value + e.bonus, e.name]
	return "%s: %s" % [who, e.name]

func _plate_feedback(i: int, l: Control, now: Array) -> void:
	var prev: Array = plate_prev[i]
	plate_prev[i] = now
	if prev.is_empty() or prev == now:
		return
	var col := Color(1.15, 1.05, 0.8)
	var amt := 1.12
	if now[0] < prev[0]:
		col = Color(1.6, 0.45, 0.4)
		amt = 1.2
	elif now[2] > prev[2]:
		col = Color(0.8, 1.2, 1.7)
		amt = 1.35
	elif now[0] > prev[0]:
		col = Color(0.8, 1.4, 0.8)
		Sfx.play("heal")
	l.pivot_offset = Vector2(0, l.size.y / 2)
	l.modulate = col
	l.scale = Vector2(amt, amt)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate", Color.WHITE, 0.5)

func _float3d(txt: String, pos: Vector3, col: Color, big := false) -> void:
	if txt == "Prevenido":
		Sfx.play("prevent")
	elif txt == "ERROU" or txt == "IMUNE":
		Sfx.play("block")
	var l := _label3d(txt, 84 if big else 64, col)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 22 if big else 18
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.position = pos + Vector3(randf_range(-0.08, 0.08), 0.3, 0)
	l.no_depth_test = true
	l.scale = Vector3.ONE * 0.3
	table.add_child(l)
	# Pop (cresce além e assenta), sobe e some.
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector3.ONE * 1.25, 0.1).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector3.ONE, 0.12)
	var t2 := l.create_tween().set_parallel()
	t2.tween_property(l, "position:y", pos.y + 1.0, 1.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t2.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.65)
	t2.chain().tween_callback(l.queue_free)

# Tremor de câmera aditivo (modelo de "trauma"); decai em _process.
func _cam_shake(amt := 0.45) -> void:
	trauma = minf(1.0, trauma + amt)

# Congela o tempo por um instante para dar peso a impactos.
func _hitstop(dur := 0.06) -> void:
	hitstop_n += 1
	Engine.time_scale = time_base * 0.05
	await get_tree().create_timer(dur, true, false, true).timeout
	hitstop_n -= 1
	if hitstop_n == 0:
		Engine.time_scale = time_base

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

# ---------- Partículas ----------
func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	return g

func _fx_quad(additive: bool) -> QuadMesh:
	var key := "add" if additive else "mix"
	if not fx_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true  # sem isso o billboard descarta a escala e cada partícula vira um quad de 1 m
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = soft_tex
		m.disable_receive_shadows = true
		var q := QuadMesh.new()
		q.material = m
		fx_mats[key] = q
	return fx_mats[key]

# Explosão de partículas genérica (faíscas, sangue, poeira, almas).
func _burst(pos: Vector3, col: Color, n: int, speed: float, size: float, grav := -3.0, life := 0.6, additive := true, spread := 180.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = n
	p.lifetime = life
	p.explosiveness = 0.95
	p.randomness = 0.4
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, grav, 0)
	p.damping_min = speed * 0.3
	p.damping_max = speed * 0.8
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0))
	p.scale_amount_curve = sc
	p.color = col
	p.color_ramp = _fade_ramp()
	p.mesh = _fx_quad(additive)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	table.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)

# Textura de respingo procedural: poça central, lóbulos, gotículas e escorridos.
func _splat_tex(sd: int) -> Array:
	var sz := 128
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var c := Vector2(sz / 2.0, sz / 2.0)
	var blobs := [[c, rng.randf_range(16, 24)]]
	for i in 7:
		blobs.append([c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8, 22), rng.randf_range(6, 13)])
	for i in 16:
		blobs.append([c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(28, 58), rng.randf_range(1.2, 4.0)])
	for i in 3:
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var r := rng.randf_range(5, 7)
		for k in 8:
			blobs.append([c + dir * (18 + k * 5.0), r])
			r *= 0.82
	var alpha := PackedFloat32Array()
	alpha.resize(sz * sz)
	for b in blobs:
		var p: Vector2 = b[0]
		var r: float = b[1]
		for y in range(maxi(0, int(p.y - r - 1)), mini(sz, int(p.y + r + 2))):
			for x in range(maxi(0, int(p.x - r - 1)), mini(sz, int(p.x + r + 2))):
				var a := clampf((1.0 - Vector2(x, y).distance_to(p) / r) * 3.0, 0.0, 1.0)
				var idx := y * sz + x
				alpha[idx] = maxf(alpha[idx], a)
	# Albedo vermelho saturado (no feltro escuro, vermelho escuro some) + ORM "molhado" para pegar brilho.
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var orm := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in sz:
		for x in sz:
			var a := alpha[y * sz + x]
			img.set_pixel(x, y, Color(0.4 + 0.12 * a, 0.015, 0.025, a))
			orm.set_pixel(x, y, Color(1.0, 0.12, 0.0, a))
	img.generate_mipmaps()
	orm.generate_mipmaps()
	return [ImageTexture.create_from_image(img), ImageTexture.create_from_image(orm)]

# Respingo de sangue que fica no feltro: abre rápido, seca devagar; os mais antigos somem.
func _splat(pos: Vector3, size := 0.9, delay := 0.0) -> void:
	var d := Decal.new()
	var tx: Array = blood_texs.pick_random()
	d.texture_albedo = tx[0]
	d.texture_orm = tx[1]
	d.size = Vector3(size, 0.4, size)
	d.cull_mask = 2
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.modulate = Color(1, 1, 1, 0)
	d.rotation.y = randf() * TAU
	table.add_child(d)
	d.position = Vector3(pos.x, 0.1, pos.z)
	d.scale = Vector3.ONE * 0.4
	blood_decals.append(d)
	while blood_decals.size() > MAX_DECALS:
		var old: Decal = blood_decals.pop_front()
		var ot := old.create_tween()
		ot.tween_property(old, "modulate:a", 0.0, 1.5)
		ot.tween_callback(old.queue_free)
	var t := d.create_tween()
	t.tween_interval(delay)
	t.tween_property(d, "modulate", Color(1, 1, 1, 0.95), 0.08)
	t.parallel().tween_property(d, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(d, "modulate", Color(0.7, 0.55, 0.55, 0.85), 25.0)  # seca e escurece

# Respingos ao redor de uma carta (embaixo dela ficariam escondidos).
func _splat_around(at: Vector3, n: int, size := 0.3, delay := 0.0) -> void:
	for i in n:
		var off := Vector2.from_angle(randf() * TAU) * randf_range(0.3, 0.55)
		_splat(at + Vector3(off.x, 0, off.y), size * randf_range(0.7, 1.3), delay + i * 0.06)

func _puff(pos: Vector3, n := 10) -> void:
	_burst(pos + Vector3(0, 0.03, 0), Color(0.55, 0.45, 0.38, 0.5), n, 0.9, 0.16, 0.25, 0.7, false, 80.0)

# Moedas físicas saltam da origem e voam até o personagem de quem ganhou.
func _coin_fly(from: Vector3, p: Dictionary, n: int) -> void:
	if not fx_mats.has("coin"):
		var cm := CylinderMesh.new()
		cm.top_radius = 0.055
		cm.bottom_radius = 0.055
		cm.height = 0.012
		cm.radial_segments = 16
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.76, 0.28)
		m.metallic = 0.9
		m.roughness = 0.3
		m.emission_enabled = true
		m.emission = Color(0.6, 0.38, 0.08)
		cm.material = m
		fx_mats["coin"] = cm
	var to: Vector3 = (p.char_card as Card3D).global_position + Vector3(0, 0.05, 0)
	for i in mini(n, 10):
		var c := MeshInstance3D.new()
		c.mesh = fx_mats["coin"]
		table.add_child(c)
		c.global_position = from
		c.scale = Vector3.ZERO
		var mid := from.lerp(to, 0.4) + Vector3(randf_range(-0.5, 0.5), randf_range(0.7, 1.2), randf_range(-0.3, 0.3))
		var spin := Vector3(randf_range(6, 14), randf_range(2, 6), 0)
		var step := func(t: float) -> void:
			var a := from.lerp(mid, t)
			var b := mid.lerp(to, t)
			c.global_position = a.lerp(b, t)
			c.rotation = spin * t
		var tw := c.create_tween()
		tw.tween_interval(i * 0.055)
		tw.tween_property(c, "scale", Vector3.ONE, 0.08)
		tw.tween_method(step, 0.0, 1.0, randf_range(0.5, 0.65)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			Sfx.play("coin", 1.0 + i * 0.06)  # sobe o tom a cada moeda
			_burst(to, Color(1, 0.8, 0.3), 5, 1.2, 0.05, -2.0, 0.3)
			(p.char_card as Card3D).punch(0.04)
			c.queue_free())

# =====================================================================
# FIM DE JOGO (a seleção de personagem é select.tscn)
# =====================================================================
func _to_menu() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

# Brasas/confete 2D subindo do rodapé (telas de seleção e fim).
func _embers2d(col: Color, n := 40) -> CPUParticles2D:
	var vs := get_viewport().get_visible_rect().size
	var e := CPUParticles2D.new()
	e.amount = n
	e.lifetime = 5.0
	e.preprocess = 5.0
	e.texture = soft_tex
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = Vector2(vs.x / 2, 10)
	e.position = Vector2(vs.x / 2, vs.y + 10)
	e.direction = Vector2(0, -1)
	e.spread = 20
	e.gravity = Vector2(0, -12)
	e.initial_velocity_min = 40
	e.initial_velocity_max = 120
	e.scale_amount_min = 0.06
	e.scale_amount_max = 0.18
	e.color = col
	e.color_ramp = _fade_ramp()
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	e.material = cm
	return e

func _game_end(winner: Dictionary) -> void:
	if game_over:
		return
	game_over = true
	if autoplay:
		print("[autoplay] GAME OVER — winner=%s souls=%d after %d turns" % [winner.name, winner.soul_n, autoplay_turns])
		for q in players:
			print("[autoplay]   %s items=%s" % [q.name, q.items.map(func(it): return it.id)])
		get_tree().quit()
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
	if not autoplay:
		Sel.record(won, players[0].char)
	Sfx.play("victory" if won else "defeat")
	overlay.add_child(_embers2d(Color(1.0, 0.75, 0.3) if won else Color(0.8, 0.15, 0.1), 60 if won else 30))
	var t := _ulbl("VITÓRIA" if won else "DERROTA", 64, PAPER if won else Color8(200, 50, 60), 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	t.scale = Vector2(2.2, 2.2)
	t.modulate.a = 0
	var tt := t.create_tween()
	tt.tween_interval(0.25)
	tt.tween_callback(func(): t.pivot_offset = t.size / 2)
	tt.tween_property(t, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tt.parallel().tween_property(t, "modulate:a", 1.0, 0.25)
	var s := _ulbl("%s reuniu %d almas." % [winner.name, winner.soul_n], 22, PAPER, 6)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(_btn("JOGAR NOVAMENTE", func(): get_tree().reload_current_scene()))
	row.add_child(_btn("PERSONAGEM", func(): get_tree().change_scene_to_file("res://select.tscn"), false))
	v.add_child(row)

# =====================================================================
# SETUP DA PARTIDA
# =====================================================================
func _new_player(i: int, cid: String, bot: bool) -> Dictionary:
	var c: Dictionary = D.CHARACTERS[cid]
	return {"i": i, "char": cid, "name": c.name, "bot": bot, "hp": c.hp, "base_hp": c.hp, "base_atk": c.atk,
		"coins": D.START_COINS, "hand": [], "items": [], "souls": [], "soul_n": 0, "char_card": null,
		"char_tapped": false, "loot_plays": 0, "attacks": 0, "bought": 0, "buy_limit": 1, "first_roll": true,
		"temp_atk": 0, "temp_hp": 0, "temp_roll": 0, "prevent_full": 0, "prevent_amt": 0, "reduce_to1": false,
		"shield": 0, "curses": [], "state": {}, "dead": false}

func _new_game(cid: String) -> void:
	if not players.is_empty():
		return
	overlay.visible = false
	var pool: Array = D.CHARACTER_ORDER.duplicate()
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
	# Deck de monstros = monstros + eventos/maldições (antes os eventos nunca entravam no deck).
	monster_ids = D.MONSTERS.keys().filter(func(k): return not D.OUTSIDE.has(k)) + D.EVENTS.keys()
	monster_ids.shuffle()
	xp.setup()
	Sfx.riffle(8)
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
			if D.ITEMS.has(start_item):  # Level One Isaac não tem item inicial
				_gain_item(p, start_item, Transform3D(FACE_DOWN, Vector3(0, 2.5, -1.0)))
		await _wait(0.3)
	for s in shop.size():
		_shop_fill(s)
		await _wait(0.2)
	for i in D.START_LOOT:
		for p in players:
			await _draw_loot(p, 1, true)
	for p in players:
		await xp.on_game_start(p)
	await _refill_slots(true)
	await xp.room_refill()
	if autoplay:
		_autoplay_give()
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
		b.material = _card_mat()
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
	insp_forced = true
	(inspect as ColorRect).color.a = 0.8
	insp_tex.texture = null
	insp_tex.visible = false
	insp_title.text = title
	insp_title.visible = true
	insp_note.visible = false
	for b in insp_btns.get_children():
		b.queue_free()
	_clear_custom_panel()
	insp_box.set_meta("custom", content)
	insp_box.add_child(content)
	insp_box.move_child(content, 2)

# Libera o conteúdo de painel personalizado, se houver.
func _clear_custom_panel() -> void:
	var holder := insp_box
	if holder.has_meta("custom") and holder.get_meta("custom") != null:
		var c = holder.get_meta("custom")
		holder.set_meta("custom", null)
		if is_instance_valid(c):
			c.queue_free()

func _sync_decks() -> void:
	decks.room.set_count(room_ids.size())
	decks.loot.set_count(loot_ids.size())
	decks.monster.set_count(monster_ids.size())
	decks.treasure.set_count(treasure_ids.size())
	decks.discard.set_count(0)

# =====================================================================
# CARTAS: comprar, posicionar
# =====================================================================
# `step` = loot do passo de loot / preparação (Lucky Toe não conta).
func _draw_loot(p: Dictionary, n := 1, step := false) -> void:
	if bool(p.state.get("double_loot", false)):
		n *= 2
	n = xp.loot_amount(p, n, step)
	if n <= 0:
		return
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
			decks.discard.set_count(0)  # antes a pilha de descarte continuava desenhada cheia
			decks.loot.bump()
			_toast("Descarte embaralhado no deck de loot")
			Sfx.riffle()
		var id: String = loot_ids.pop_back()
		decks.loot.set_count(loot_ids.size())
		decks.loot.bump()
		_loot_to_hand(p, id)
		await _wait(0.16)
	_check_bonus_souls()
	xp.after_loot(p, n)

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
		c.bob = true
		if c == drag_card and drag_active:
			continue
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
	xp.on_item_enter(p, it)
	if id == "breakfast" or id == "dinner":
		p.hp += 1
	if id == "momsshovel":
		it.tapped = true  # entra em jogo desativado
	_layout_items(p)
	Sfx.play("item_gain")
	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(c) and c.zone == "item":
			c.sheen()
			c.punch(0.08)
			_burst(c.global_position + Vector3(0, 0.05, 0), Color(1, 0.85, 0.45), 14, 1.4, 0.05, -1.5, 0.5))

func _is_eternal(it: Dictionary) -> bool:
	if bool(it.get("no_eternal", false)):  # Birthright: cópia que perde eterno
		return xp.eternal_now(it)
	return bool(it.get("eternal", false)) or bool(D.ITEMS[it.id][3]) or xp.eternal_now(it)

func _item_of(p: Dictionary, id: String):
	for it in p.items:
		if it.id == id:
			return it
	return null

# Trinkets ficam em jogo como itens (podem ser roubados/destruídos); o alias mantém a leitura do código.
func _nt(p: Dictionary, id: String) -> int:
	return _n(p, id)

# Trinket resolvido: a própria carta de loot entra em jogo na fileira de itens do jogador.
func _play_trinket(p: Dictionary, c: Card3D) -> void:
	Sfx.play("trinket")
	if c.get_parent() != table:
		c.reparent(table, true)
	c.bob = false
	c.highlight(false)
	if c.id == "lostsoul":
		# Lost Soul vira uma alma ao entrar em jogo.
		c.zone = "soul"
		c.ref = p
		p.souls.append(c)
		p.soul_n += 1
		c.fly_to(_soul_xf(p, p.souls.size() - 1), 0.6, 0.4)
		_float3d("+1 ALMA", (p.char_card as Card3D).global_position, Color(0.75, 0.9, 1), true)
		_burst(c.global_position, Color(0.6, 0.85, 1.0), 30, 2.0, 0.08, 1.0, 1.0)
		_check_bonus_souls()
		_ui()
		return
	var it := {"id": c.id, "tapped": false, "card": c, "owner": p, "eternal": bool(D.ITEMS[c.id][3]), "counters": 0, "trinket": true}
	c.zone = "item"
	c.ref = it
	p.items.append(it)
	xp.on_item_enter(p, it)
	_layout_items(p)
	_toast("%s: %s entra em jogo" % [p.name, D.ITEMS[c.id][0]])
	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(c) and c.zone == "item":
			c.sheen()
			c.punch(0.08))
	_ui()

# Item sai de jogo: trinkets voltam ao descarte de loot, tesouros ao descarte de tesouro.
func _discard_item(it: Dictionary) -> void:
	xp.forget_xtarget(it)
	if it.get("trinket", false):
		_discard_card(it.card, true)
	else:
		treasure_discard.append(it.id)
		_discard_card(it.card, false)

func _discard_card(c: Card3D, to_loot_pile: bool) -> void:
	if c == drag_card:
		drag_card = null
		drag_active = false
	if c.get_parent() != table:
		c.reparent(table, true)
	c.bob = false
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
	for x in xtargets:
		if x.uid == u:
			return x
	return null

# Monstros no topo dos espaços (os que podem ser alvo).
func _tops() -> Array:
	var out := []
	for s in slots.size():
		if not slots[s].is_empty():
			out.append(slots[s].back())
	return out

func _all_mons() -> Array:
	var out := []
	for s in slots.size():
		for m in slots[s]:
			out.append(m)
	return out

func _has_tag(m: Dictionary, tag: String) -> bool:
	return (m.get("tags", []) as Array).has(tag)

func _mdata(id: String) -> Array:
	if D.MONSTERS.has(id):
		return D.MONSTERS[id]
	if D.ATTACKABLE.has(id):
		return D.ATTACKABLE[id]
	return [_card_disp_name(id), 0, 0, 0, 0, 0, 0, 0, "", ""]  # jogador atacado (pseudo-alvo)

func _make_mon(id: String, s: int, c: Card3D) -> Dictionary:
	var d: Array = _mdata(id)
	uid += 1
	var l := _label3d("", 46, Color(1, 0.97, 0.94))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 12
	l.outline_modulate = Color(0.12, 0.02, 0.02, 1)
	l.position = Vector3(0, -Card3D.H / 2 - 0.02, 0.14)
	l.no_depth_test = true
	l.render_priority = 2
	l.outline_render_priority = 1
	var heart := Sprite3D.new()
	heart.texture = load(HUD + "heart.png")
	heart.pixel_size = 0.0034
	heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heart.no_depth_test = true
	heart.render_priority = 0
	heart.position = Vector3(0, 0.012, -0.001)
	l.add_child(heart)
	c.add_child(l)
	return {"id": id, "uid": uid, "hp": d[1], "max": d[1], "eva": d[2], "atk": d[3],
		"slot": s, "card": c, "label": l, "tags": (MON_TAG.get(id, []) as Array).duplicate(),
		"temp_atk": 0, "temp_eva": 0, "hits": 0, "reward_kind": d[9], "text": d[8], "double": false, "prevent_full": 0,
		"counters": 0, "rolls": 0, "hpc": 0, "atc": 0}

func _update_monster_labels() -> void:
	for x in xtargets:
		if x.get("label") != null and is_instance_valid(x.label):
			(x.label as Label3D).text = str(max(x.hp, 0))
	for s in slots.size():
		for m in slots[s]:
			var l: Label3D = m.label
			l.visible = m == _top(s)
			l.text = str(max(m.hp, 0))
			l.modulate = Color(1, 0.97, 0.94) if m.hp >= m.max else Color(1, 0.8, 0.5)
			var c: Card3D = m.card
			var fighting: bool = in_combat and combat.get("uid", -1) == m.uid
			if targeting == "":
				c.highlight(fighting, Color(1, 0.25, 0.2))

func _eva(m: Dictionary) -> int:
	if m.has("player"):
		return m.eva
	var e: int = m.eva + int(m.get("temp_eva", 0)) + xp.eva_mod(m)
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
	return max(e, 1)

func _mon_atk(m: Dictionary) -> int:
	if m.has("player"):
		return _atk(m.player)
	if m.has("atk_set"):
		return int(m.atk_set)
	return max(0, m.atk + int(m.get("temp_atk", 0)) + xp.mon_atk_mod(m))

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
# Guarda contra reentrada: duas reposições simultâneas (ex.: loot jogado durante a animação de revelar)
# viam o mesmo espaço vazio e revelavam duas cartas nele. Chamadas aninhadas (rolagem de evento) só retornam.
func _refill_slots(setup := false) -> void:
	if refilling:
		return
	refilling = true
	# Recomeça a varredura a cada revelação: eventos podem esvaziar ou criar espaços no meio.
	var s := _first_empty_slot()
	while s >= 0 and not monster_ids.is_empty() and not game_over:
		await _reveal_into(s, setup)
		s = _first_empty_slot()
	refilling = false
	_ui()

func _first_empty_slot() -> int:
	for i in slots.size():
		if slots[i].is_empty():
			return i
	return -1

# Espera a mesa "assentar" (pilha, dado e reposição terminados).
func _settle() -> void:
	while stack_running or busy or refilling:
		await _wait(0.05)

func _reveal_into(s: int, setup := false) -> void:
	var id: String = monster_ids.pop_back()
	decks.monster.set_count(monster_ids.size())
	decks.monster.bump()
	var c := Card3D.make(id, "monsterback")
	table.add_child(c)
	c.transform = decks.monster.top_xf()
	c.zone = "monster"
	c.tapped.connect(_on_card_tapped)
	var depth: int = slots[s].size()
	# Sobe virada, gira no ar e bate na mesa.
	var lift := Transform3D(Basis(Vector3.RIGHT, PI / 2), c.transform.origin.lerp(_slot_xf(s, depth).origin, 0.4) + Vector3(0, 0.9, 0.2))
	await c.fly_to(lift, 0.25, 0.1).finished
	await c.fly_to(_slot_xf(s, depth), 0.32, 0.15).finished
	c.punch(0.14)
	_puff(c.global_position)
	Sfx.play("event" if D.EVENTS.has(id) and not setup else "mon_reveal")
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
	if not setup and xp.indomitable(id) and not slots[s].is_empty():
		# Indomável: abre um espaço novo em vez de cobrir.
		_expand_monster_slots(1)
		s = slots.size() - 1
		c.fly_to(_slot_xf(s, 0), 0.3, 0.1)
	var m := _make_mon(id, s, c)
	c.ref = m
	slots[s].append(m)
	_ui()
	if not setup:
		await xp.on_mon_enter(m)

func _gain_treasure(p: Dictionary, n := 1) -> void:
	n = xp.treasure_amount(p, n)
	for i in n:
		if treasure_ids.is_empty():
			return
		var id: String = treasure_ids.pop_back()
		decks.treasure.set_count(treasure_ids.size())
		_gain_item(p, id, decks.treasure.top_xf())
		xp.on_treasure(p)
		await _wait(0.05)

func _search_treasure(match_ids: Array) -> String:
	for i in treasure_ids.size():
		if match_ids.has(treasure_ids[i]):
			var id: String = treasure_ids[i]
			treasure_ids.remove_at(i)
			decks.treasure.set_count(treasure_ids.size())
			return id
	return ""

# `cost` = descarte pago pelo próprio jogador (Rib of Greed só impede os forçados).
func _force_discard(p: Dictionary, n: int, cost := false) -> void:
	if not cost and _n(p, "ribofgreed") > 0:
		return
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

func _lose_coins(p: Dictionary, n: int, cost := false) -> void:
	if not cost and _n(p, "ribofgreed") > 0:
		return
	var lost: int = min(p.coins, n)
	p.coins -= lost
	if lost > 0:
		Sfx.play("coin_lose")
	_float3d("-%d¢" % lost, (p.char_card as Card3D).global_position, Color(1, 0.4, 0.3))
	_ui()

func _recharge_first(p: Dictionary) -> bool:
	for it in p.items:
		if it.tapped and it.id != "carbattery":
			it.tapped = false
			Sfx.play("recharge")
			_layout_items(p)
			return true
	return false

func _recharge_all(p: Dictionary) -> void:
	for it in p.items:
		if it.id != "carbattery":
			it.tapped = false
	_layout_items(p)

# ============ EVENTOS ============
func _event_resolve(id: String, c: Card3D) -> void:
	var p: Dictionary = players[active]
	var cpos: Vector3 = c.global_position if is_instance_valid(c) else Vector3.ZERO  # a carta pode ser liberada antes do dado resolver
	match id:
		"chest":
			await _roll(p, "Chest", func(v: int) -> void: _gain_coins(p, [1, 1, 3, 3, 6, 6][v - 1], cpos))
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
				elif v <= 4: _gain_coins(p, 3, cpos)
				else: _damage_player(p, 2, null))
		"darkchest_2":
			await _roll(p, "Dark Chest", func(v: int) -> void:
				if v <= 2: _gain_coins(p, 1, cpos)
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
				elif v <= 5: _gain_coins(p, 7, cpos)
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
			var target: Dictionary = await xp.curse_target(p, id)
			(target.curses as Array).append(id)
			_toast("%s recebe %s" % [target.name, D.EVENTS[id][0]])
		_:
			await xp.event(id, c, p)

func _resolve_devil_deal(p: Dictionary) -> void:
	Sfx.play("devil")
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

# `card_id` opcional mostra a carta acima das opções.
func _choose_option(title: String, options: Array, default_i := 0, bot := false, card_id := "") -> int:
	if bot or autoplay:
		return default_i
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	if card_id != "":
		var tr := TextureRect.new()
		tr.material = _card_mat()
		tr.texture = Card3D.tex(card_id)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(180, 246)
		vb.add_child(tr)
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
	if m.has("player"):
		# Jogador sendo atacado (Battle Royale, The Siren...): o dano vai para ele.
		_damage_player(m.player, n, null)
		xp.on_dealt_damage(by, n)
		return
	n = xp.pre_mon_damage(m, n, by)
	if n <= 0:
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
	c.flash_hit()
	Sfx.play("mon_hit")
	if randf() < 0.45:
		Sfx.play("mon_grunt")
	c.set_gore(0.3 + 0.7 * (1.0 - float(maxi(m.hp, 0)) / float(m.max)))
	var at := c.global_position + Vector3(0, 0.08, 0)
	_burst(at, Color(1, 0.55, 0.2), 22, 3.0, 0.06, -5.0, 0.45)
	_burst(at, Color(0.45, 0.02, 0.02, 0.9), 10, 1.8, 0.07, -6.0, 0.6, false)
	_splat_around(c.global_position, 1, 0.8, 0.12)
	_float3d("-%d" % n, c.global_position, Color(1, 0.85, 0.3), true)
	_hitstop(0.03)
	if _has_tag(m, "haunt") and int(m.hits) % 2 == 0:
		m.temp_eva = int(m.get("temp_eva", 0)) + 1
		_toast("The Haunt: +1 dado")
	if _has_tag(m, "rage_atk"):
		m.temp_atk = int(m.get("temp_atk", 0)) + 1
	if _has_tag(m, "echo_right") or _has_tag(m, "echo_left"):
		_damage_player(players[1 - active], n, null)
	xp.on_dealt_damage(by, n)
	xp.on_mon_damaged(m, n, by)
	if m.hp <= 0 and _find_mon(m.uid) != null and not xp.prevent_mon_death(m, by):
		_kill_monster(m, by)
	_ui()

# ---------- Morte de monstro ----------
func _kill_monster(m: Dictionary, by: Dictionary) -> void:
	if m.has("obj"):
		# Item/sala/alma atacável: tratamento próprio (não é monstro).
		await xp.kill_xtarget(m, by)
		return
	var s: int = m.slot
	slots[s].erase(m)
	monster_died = true
	by = xp.reward_taker(m, by)
	var d: Array = _mdata(m.id)
	if in_combat and combat.get("uid", -1) == m.uid:
		in_combat = false
		if awaiting_roll:
			roll_requested.emit()
	_toast("%s derrotou %s!" % [by.name, d[0]], Color(1, 0.85, 0.5))
	var c: Card3D = m.card
	(m.label as Label3D).queue_free()
	c.highlight(false)
	var pos: Vector3 = c.global_position
	var at := pos + Vector3(0, 0.08, 0)
	_burst(at, Color(1, 0.7, 0.3), 40, 4.0, 0.08, -4.0, 0.7)
	_burst(at, Color(0.08, 0.05, 0.05, 0.7), 14, 1.2, 0.25, 0.6, 1.1, false)
	# Gibs: pedaços pesados sobem e caem; onde "pousam", o feltro mancha.
	_burst(at, Color(0.38, 0.03, 0.04, 1.0), 16, 3.4, 0.1, -10.0, 0.75, false, 60.0)
	_burst(at, Color(0.85, 0.65, 0.55, 1.0), 5, 3.0, 0.06, -10.0, 0.7, false, 60.0)
	_splat_around(pos, 3, 1.0, 0.3)
	_splat(pos, 1.6, 0.05)
	c.set_gore(1.0)
	_cam_shake(0.25)
	Sfx.play("mon_kill")
	Sfx.play("splat")
	_hitstop(0.05)
	# Recompensas
	var roll_val: int = int(m.get("kill_roll", 1))
	var mult: int = (2 if bool(m.get("double", false)) else 1) * xp.reward_mult(m, by)
	if m.reward_kind == "rollcents":
		_gain_coins(by, roll_val * mult, pos)
	elif m.reward_kind == "rollloot":
		await _draw_loot(by, roll_val * mult)
	elif m.reward_kind == "special":
		await xp.special_reward(m, by, mult)
	else:
		if d[4] > 0:
			_gain_coins(by, int(d[4]) * mult, pos)
	if d[5] > 0:
		await _draw_loot(by, int(d[5]) * mult)
	for i in int(d[6]) * mult:
		await _gain_treasure(by, 1)
	# Alma ou descarte (algumas cartas desviam ou bloqueiam a alma)
	var soul_to = xp.soul_taker(m, by) if d[7] > 0 else null
	if soul_to != null:
		by = soul_to
		by.soul_n += int(d[7])
		by.souls.append(c)
		c.zone = "soul"
		c.ref = by
		# Alma: sobe brilhando antes de ir para a pilha do jogador.
		var up_pos := at + Vector3(0, 1.2, 0.3)
		var up := Transform3D(Basis.looking_at(up_pos - cam_base).scaled(Vector3.ONE * 1.1), up_pos)
		var tw := c.fly_to(up, 0.4, 0.0)
		_burst(at, Color(0.6, 0.85, 1.0), 45, 2.2, 0.09, 1.2, 1.4)
		_float3d("+%d ALMA" % int(d[7]), pos, Color(0.75, 0.9, 1), true)
		Sfx.play("soul")
		c.highlight(true, Color(0.55, 0.8, 1.0))
		tw.finished.connect(func():
			c.sheen(0.5)
			await _wait(0.5)
			if not is_instance_valid(c) or c.zone != "soul":
				return
			c.highlight(false)
			var t2 := c.fly_to(_soul_xf(c.ref, (c.ref.souls as Array).find(c)), 0.55, 0.3)
			t2.finished.connect(func():
				_burst(c.global_position, Color(0.6, 0.85, 1.0), 20, 1.5, 0.06, 0.5, 0.8)
				c.punch(0.1)))
	elif xp.leaves_play(m, by):
		monster_discard.append(m.id)
		_discard_card(c, false)
	_ui()
	if soul_to != null:
		xp.on_soul_gained(by, m.id)
	if by.soul_n >= D.SOULS_TO_WIN and not game_over:
		_game_end(by)
		return
	await _mon_death_effect(m, by)
	await xp.on_mon_killed(m, by)
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
			# Golden Trinket: itens com ficha dourada valem também como o trinket.
			if bool(it.get("gold", false)):
				k += _n_raw(p, "goldentrinket")
	# Item virado sala (Cracked Key): vale para o jogador ativo.
	if not players.is_empty() and p.i == active:
		for r in rooms:
			if r.id == id:
				k += 1
	return k

func _n_raw(p: Dictionary, id: String) -> int:
	var k := 0
	for it in p.items:
		if it.id == id:
			k += 1
	return k

func _max_hp(p: Dictionary) -> int:
	return p.base_hp + _n(p, "breakfast") + _n(p, "dinner") + p.temp_hp + xp.hp_mod(p)

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
	a += xp.atk_mod(p)
	if p.state.has("atk_set"):
		a = int(p.state.atk_set)
	return max(a, 0)

func _roll_bonus(p: Dictionary, is_attack := false, first := false) -> int:
	var r: int = p.temp_roll
	if is_attack:
		r += _n(p, "meat") + _n(p, "synthoil")
		if p.coins == 0:
			r += _n(p, "emptyvessel")
		if first and _bumbo_level(p) >= 1:
			r += 2
	return r + xp.roll_mod(p, is_attack, first)

func _loot_step(p: Dictionary) -> int:
	return 1 + _n(p, "momspurse") + _n(p, "momscoinpurse") + xp.loot_step_mod(p)

func _shop_price(p: Dictionary) -> int:
	return max(0, D.SHOP_PRICE - 5 * _n(p, "steamysale") - xp.price_off(p))

func _guppy_count(p: Dictionary) -> int:
	var k := 0
	for g in GUPPY_ITEMS:
		k += _n(p, g)
	return k

func _check_bonus_souls() -> void:
	if players.is_empty():
		return
	var winner: Dictionary = {}
	xp.check_bonus_souls()
	for q in players:
		if not bonus_souls_taken.has("soulofgreed") and q.coins >= 25:
			bonus_souls_taken["soulofgreed"] = q.i
			q.soul_n += 1
			Sfx.play("bonus_soul")
			_toast("%s ganhou a Alma de Greed!" % q.name)
		if not bonus_souls_taken.has("soulofgluttony") and q.hand.size() >= 10:
			bonus_souls_taken["soulofgluttony"] = q.i
			q.soul_n += 1
			Sfx.play("bonus_soul")
			_toast("%s ganhou a Alma de Gluttony!" % q.name)
		if not bonus_souls_taken.has("soulofguppy") and _guppy_count(q) >= 2:
			bonus_souls_taken["soulofguppy"] = q.i
			q.soul_n += 1
			Sfx.play("bonus_soul")
			_toast("%s ganhou a Alma de Guppy!" % q.name)
		if q.soul_n >= D.SOULS_TO_WIN and not game_over:
			winner = q
	if not winner.is_empty():
		_game_end(winner)

func _opp(p: Dictionary) -> Dictionary:
	return players[1 - p.i]

func _gain_coins(p: Dictionary, n: int, at: Vector3, raw := false) -> void:
	if n <= 0 or game_over:
		return
	if not raw:
		n = xp.coin_amount(p, n)
		if n <= 0:
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
	_coin_fly(at, p, amt)
	if not raw:
		xp.after_coins(p, amt)
	_check_bonus_souls()
	_ui()

func _damage_player(p: Dictionary, n: int, src) -> void:
	if p.dead or n <= 0 or game_over:
		return
	n = xp.pre_player_damage(p, n, src)
	if n <= 0:
		_float3d("Prevenido", (p.char_card as Card3D).global_position, Color(0.6, 0.85, 1))
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
	# Guppy's Hairball (trinket): rolagem rápida, 6 previne 1 do dano.
	for _h in _nt(p, "guppyshairball"):
		if _rand_roll(p) == 6:
			n -= 1
			_toast("Guppy's Hairball: 6! previne 1", Color(0.6, 0.85, 1))
	if n <= 0:
		_float3d("Prevenido", (p.char_card as Card3D).global_position, Color(0.6, 0.85, 1))
		_ui()
		return
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
	cc.flash_hit(1.0)
	Sfx.play("hurt", 1.0 if p.i == 0 else 1.12)
	_float3d("-%d" % n, cc.global_position, Color(1, 0.25, 0.2), true)
	_burst(cc.global_position + Vector3(0, 0.08, 0), Color(0.55, 0.02, 0.03, 0.95), 16, 2.2, 0.08, -6.0, 0.6, false)
	_burst(cc.global_position + Vector3(0, 0.08, 0), Color(1, 0.3, 0.2), 10, 2.0, 0.05, -3.0, 0.35)
	if CHAR_DROPS.has(p.char):
		_burst(cc.global_position + Vector3(0, 0.15, 0), CHAR_DROPS[p.char], 12, 2.0, 0.06, -7.0, 0.8, false, 50.0)
	cc.set_gore(0.25 + 0.75 * (1.0 - float(maxi(p.hp, 0)) / float(maxi(_max_hp(p), 1))))
	_splat_around(cc.global_position, 1, 0.75, 0.1)
	_hitstop(0.035)
	if p.i == 0:
		flash.color = Color(0.6, 0, 0, 0.28)
		flash.create_tween().tween_property(flash, "color:a", 0.0, 0.5)
		_cam_shake(0.3)
	else:
		cc.shake()
	_on_player_damaged(p, n)
	if src != null and src is Dictionary and src.has("tags"):
		_mon_dealt_damage(src, p, n)
	if p.hp <= 0:
		_kill_player(p)
	_ui()

func _on_player_damaged(p: Dictionary, n: int) -> void:
	await xp.on_player_damaged(p, n)
	if p.dead:
		return
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
	xp.mon_dealt_damage(m, p, n)
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
	if D.ROOMS.has(id):
		return D.ROOMS[id][0]
	if D.ATTACKABLE.has(id):
		return D.ATTACKABLE[id][0]
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
		vb.add_child(_ulbl("Escolha a %dª (topo primeiro)" % (order.size() + 1), 18, PAPER, 6))
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
		"room": arr = room_ids; dk = decks.room
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

func _peek_maybe_bottom(p: Dictionary, src_name: String, deck_key: String) -> void:
	var top := _peek(deck_key)
	if top == "":
		return
	var bottom := false
	if p.bot or autoplay:
		bottom = _bot_dislikes_top(deck_key, top)
	else:
		bottom = (await _choose_option("%s · %s" % [src_name, _card_disp_name(top)], ["MANTER NO TOPO", "MANDAR PARA O FUNDO"], 0, false, top)) == 1
	if bottom:
		var arr: Array = loot_ids if deck_key == "loot" else (treasure_ids if deck_key == "treasure" else monster_ids)
		arr.push_front(arr.pop_back())
		_toast("%s: %s foi para o fundo" % [src_name, _card_disp_name(top) if p.i == 0 else "carta"])
	elif p.i == 0:
		_toast("%s: topo = %s" % [src_name, _card_disp_name(top)])
	await _wait(0.3)

# Heurística simples da CPU para trinkets de espiar.
func _bot_dislikes_top(deck_key: String, id: String) -> bool:
	match deck_key:
		"loot":
			return id in ["penny", "twocents", "xiiideath", "xvithetower", "pills_orange"]
		"monster":
			if D.EVENTS.has(id):
				return D.EVENTS[id][0].begins_with("Curse") or id in ["trollbombs", "megatrollbomb", "cursedchest"]
			return D.MONSTERS.has(id) and int(D.MONSTERS[id][7]) == 0 and int(D.MONSTERS[id][1]) >= 4
	return false

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
		"room":
			if room_ids.is_empty(): return ""
			return room_ids.back()
	return ""

func _kill_player(p: Dictionary) -> void:
	if game_over or p.dead:
		return
	if await xp.prevent_death(p):
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
	_toast("%s MORREU" % p.name.to_upper(), Color(1, 0.4, 0.35))
	var cc: Card3D = p.char_card
	cc.dim(true)
	cc.set_gore(1.0)
	Sfx.play("die")
	_splat_around(cc.global_position, 3, 1.1, 0.15)
	_burst(cc.global_position + Vector3(0, 0.1, 0), Color(0.05, 0.03, 0.03, 0.8), 24, 1.4, 0.3, 0.8, 1.4, false)
	_burst(cc.global_position + Vector3(0, 0.1, 0), Color(0.9, 0.1, 0.05), 30, 3.5, 0.07, -5.0, 0.7)
	_cam_shake(0.45)
	if p.i == 0:
		flash.color = Color(0, 0, 0, 0.85)
		flash.create_tween().tween_property(flash, "color:a", 0.0, 1.4)
	_banner("VOCÊ MORREU" if p.i == 0 else "%s MORREU" % p.name.to_upper(), Color(1, 0.45, 0.35))
	# Antes das penalidades
	if _n(p, "greedsgullet") > 0:
		_gain_coins(p, 8, (p.char_card as Card3D).global_position)
	if _n(p, "suicideking") > 0:
		await _draw_loot(p, 3)
	for q in players:
		if _nt(q, "bloodypenny") > 0:
			await _draw_loot(q, 1)
	await xp.before_penalties(p)
	var pen: Dictionary = xp.penalty(p)
	# Maldições-atributo voltam (babyhaunt/daddyhaunt entregues a outro jogador)
	for cur in ["babyhaunt", "daddyhaunt"]:
		var ci = _item_of(p, cur)
		if ci != null:
			_transfer_item(ci, _opp(p))
	# Penalidades: 1¢, 1 loot, 1 item não-eterno, tudo virado.
	if pen.coins:
		p.coins = max(0, p.coins - 1)
	if pen.loot and not p.hand.is_empty():
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
	if pen.item and not lose.is_empty():
		var it: Dictionary = lose.pick_random()
		if not await xp.penalty_item(p, it):
			p.items.erase(it)
			_discard_item(it)
	for it in p.items:
		it.tapped = true
	p.char_tapped = true
	# Maldições (eventos) vão para descarte.
	if not p.curses.is_empty():
		xp.curses_on_death(p)
		for cur in p.curses:
			monster_discard.append(cur)
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
		_ui()
		# Se a pilha esperava a prioridade do humano, o botão PASSAR sumiu junto com a pilha: libera a espera.
		if waiting_priority:
			priority_event.emit("push")
		if p.i == 0:
			_force_end_turn()
	# Depois das penalidades: Lazarus' Rags
	if _n(p, "lazarusrags") > 0:
		await _gain_treasure(p, 1)
	await xp.after_death(p)

func _force_end_turn() -> void:
	await _settle()
	await _wait(0.4)
	await _settle()
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
	_banner("SEU TURNO" if p.i == 0 else "TURNO DE %s" % p.name.to_upper(), Color(1, 0.9, 0.7) if p.i == 0 else Color(0.85, 0.8, 0.95))
	Sfx.play("banner", 1.0 if p.i == 0 else 0.85, 0.0 if p.i == 0 else -3.0)
	if p.items.any(func(it): return it.tapped):
		Sfx.later("recharge", 0.3)
	xp.recharge_step(p)
	p.loot_plays = 1 + _n(p, "polydactyly") + _n(p, "bellybutton") + xp.extra_loot_plays(p)
	p.attacks = 1 + _n(p, "championbelt") + xp.extra_attacks(p)
	if _bumbo_level(p) >= 25:
		p.attacks = 99
	p.bought = 0
	p.buy_limit = 1 + (1 if _n(p, "theresoptions") > 0 else 0)
	monster_died = false
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
			_discard_item(it)
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
	# Trinkets de espiar: olha o topo do deck e pode mandá-lo para o fundo.
	for pair in [["cainseye", "loot"], ["goldenhorseshoe", "treasure"], ["purpleheart", "monster"]]:
		if _nt(p, pair[0]) > 0:
			await _peek_maybe_bottom(p, D.ITEMS[pair[0]][0], pair[1])
	await xp.on_turn_start(p)
	if game_over or turn_over:
		return
	# Passo de loot
	await _draw_loot(p, _loot_step(p), true)
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
	await xp.on_turn_end(p)
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
	while p.hand.size() > xp.hand_limit(p):
		var c: Card3D = p.hand.pop_front()
		_discard_card(c, true)
	_revert_copies()  # Diplopia/Placebo voltam a ser o que eram
	await xp.after_revert(p)
	# Fim de turno: todos curam, monstros também.
	for q in players:
		q.temp_atk = 0
		q.temp_hp = 0
		q.temp_roll = 0
		q.prevent_full = 0
		q.prevent_amt = 0
		q.reduce_to1 = false
		q.shield = 0
		if q.dead:
			(q.char_card as Card3D).dim(false)
			(q.char_card as Card3D).sheen()
		q.dead = false
		q.hp = _max_hp(q)
		(q.char_card as Card3D).set_gore(0.0)  # todos curam: as cartas se limpam devagar
	for s in slots.size():
		for m in slots[s]:
			if not _has_tag(m, "noheal"):
				m.hp = m.max
			m.temp_atk = 0
			m.temp_eva = 0
			m.erase("atk_set")
			(m.card as Card3D).set_gore(0.0)
	xp.on_cleanup()
	_layout_hand(p)
	_ui()
	await _refill_slots()
	await xp.after_end(p)
	await _settle()
	await _wait(0.3)

func _trinity_blocked(actor: Dictionary) -> bool:
	var cur: Dictionary = players[active]
	return (not is_same(actor, cur) and _n(cur, "trinityshield") > 0) or xp.blocked(actor)

func _human_idle() -> bool:
	return active == 0 and not players[0].bot and stack.is_empty() and not busy and not in_combat \
		and not game_over and not turn_over and targeting == "" and not players[0].dead and not refilling

# Pode o humano agir agora (ativar itens / jogar loot)?
func _human_has_priority() -> bool:
	if game_over or busy or targeting != "" or players[0].dead:
		return false
	if _trinity_blocked(players[0]):
		return false
	if waiting_priority:
		return true
	return active == 0 and stack.is_empty() and (not in_combat or awaiting_roll) and not turn_over and not refilling

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
			if D.TRINKETS.has(e.card.id):
				_play_trinket(e.owner, e.card)
			else:
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
	v = await xp.adjust_roll(p, v, extra)  # vários dados / resultado fixado (antes do lançamento)
	busy = true
	_ui()
	var from := (p.char_card as Card3D).position + Vector3(0, 1.0, -0.3 if p.i == 0 else 0.3)
	var to := Vector3(randf_range(-0.3, 0.3), Dice3D.S / 2, randf_range(-1.0, -0.85))
	await dice.throw(v, from, to)
	_dice_landed(v)
	busy = false
	v = await xp.change_roll(p, v, extra)  # P.H.D., Telepathy, Isaac's Blessing (depois de ver o dado)
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
	await xp.roll_triggers(p, v)

func _reroll(e: Dictionary) -> void:
	if not stack.has(e):
		return
	var v := _rand_roll(e.owner)
	e.value = v
	_toast("Rerrolou: %d" % v)
	var to := dice.position + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.1, 0.1))
	await dice.throw(v, dice.position + Vector3(0, 0.8, 0.3), to)
	_dice_landed(v)
	await _roll_triggers(e.owner, v)
	_ui()

func _dice_landed(v: int) -> void:
	_puff(dice.global_position - Vector3(0, Dice3D.S / 2, 0), 8)
	var col := Color(1, 0.95, 0.85)
	if v == 6:
		col = Color(1, 0.8, 0.3)
		_burst(dice.global_position, Color(1, 0.8, 0.3), 24, 2.5, 0.06, -2.0, 0.6)
	elif v == 1:
		col = Color(1, 0.35, 0.3)
	_float3d(str(v), dice.global_position + Vector3(0, 0.15, 0), col, true)
	if v == 6:
		Sfx.play("roll_6")
	elif v == 1:
		Sfx.play("roll_1")

# =====================================================================
# AÇÕES (compartilhadas por humano e CPU)
# =====================================================================
func _act_attack(p: Dictionary, s: int) -> void:
	var m = _top(s)
	if m == null:
		return
	await _attack(p, m)

func _tname(m: Dictionary) -> String:
	return str(m.get("name", "")) if m.has("name") else str(_mdata(m.id)[0])

# Ataca o topo do deck de monstros: a carta cobre um espaço e o ataque segue contra ela.
func _act_attack_deck(p: Dictionary) -> void:
	if monster_ids.is_empty() or in_combat:
		return
	var free: bool = int(p.state.get("deck_attacks", 0)) > 0
	if not free and p.attacks <= 0:
		return
	if free:
		p.state.deck_attacks = int(p.state.deck_attacks) - 1
	else:
		p.attacks -= 1
	var s: int = await xp.pick_slot_for_deck(p)
	await xp.before_deck_attack(p)
	last_revealed = {}
	_toast("%s ataca o topo do deck de monstros" % p.name)
	await _reveal_into(s)
	p.state["deck_attacked"] = true
	if last_revealed.is_empty() or _find_mon(last_revealed.uid) == null or p.dead or turn_over:
		return
	if await xp.cancel_deck_attack(p):
		return
	await _attack(p, last_revealed, true)

var last_revealed: Dictionary = {}

# Ataque a qualquer alvo: monstro, objeto atacável ou jogador (`free` = não gasta ataque).
func _attack(p: Dictionary, m: Dictionary, free := false) -> void:
	if (p.attacks <= 0 and not free) or in_combat:
		return
	if _has_tag(m, "untargetable"):
		_toast("%s não pode ser atacado" % _tname(m))
		return
	var why: String = xp.can_attack(p, m)
	if why != "":
		_toast(why)
		return
	if not free:
		p.attacks -= 1
	m = await xp.redirect_attack(p, m)
	in_combat = true
	combat = {"p": p, "uid": m.uid, "team": [], "rolls": 0}
	_toast("%s ataca %s" % [p.name, _tname(m)])
	# Câmera aproxima levemente do monstro durante o combate.
	cam_focus_target = Vector3((m.card as Card3D).position.x * 0.15, -0.35, -0.3)
	(p.char_card as Card3D).lunge((m.card as Card3D).global_position, 0.2)
	Sfx.play("attack")
	_ui()
	if _has_tag(m, "pride_declare"):
		_force_discard(_opp(p), 2)
	await xp.on_attack_declared(p, m)
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
		var on_res := func(v: int) -> void: await _resolve_attack(p, mu, v)
		await _roll(p, "ataque", on_res, {"attack": true, "mon_uid": mu, "first": p.first_roll})
		# Team Up: cada parceiro rola contra o mesmo alvo depois de cada rolagem do atacante.
		for q in (combat.get("team", []) as Array).duplicate():
			if not in_combat or q.dead or p.dead or game_over or _find_mon(mu) == null:
				break
			var q_res := func(v: int) -> void: await _resolve_attack(q, mu, v)
			await _roll(q, "ataque (equipe)", q_res, {"attack": true, "mon_uid": mu, "first": q.first_roll, "team": true})
	in_combat = false
	xp.on_attack_end(p)
	awaiting_roll = false
	cam_focus_target = Vector3.ZERO
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
	var mc: Card3D = m.card
	var pc: Card3D = p.char_card
	m.rolls = int(m.get("rolls", 0)) + 1
	if is_same(p, combat.get("p", null)):
		combat.rolls = int(combat.get("rolls", 0)) + 1
	var hit: bool = total >= _eva(m) and not xp.attack_miss_forced(p, m, raw)
	m.last_roll = raw
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
	if hit:
		if (_has_tag(m, "immune6") and raw == 6) or (_has_tag(m, "immune45") and (raw == 4 or raw == 5)) or xp.combat_immune(m, raw):
			_toast("%s é imune a essa rolagem" % _tname(m))
			_float3d("IMUNE", mc.global_position, Color(0.7, 0.75, 0.8))
			mc.shake(0.02)
			await xp.after_attack_roll(p, m, raw, true)
			return
		dmg = xp.combat_dmg(p, m, raw, dmg)
		_toast("Acerto! %d de dano" % dmg, Color(1, 0.9, 0.55))
		# Investida do personagem; o dano entra no impacto.
		pc.lunge(mc.global_position, 0.35)
		Sfx.play("swing")
		await _wait(0.17)
		if _find_mon(mu) == null or p.dead:
			return
		_damage_monster(m, dmg, p)
		if _has_tag(m, "gluttony6") and raw == 6:
			_damage_player(players[(active + 1) % players.size()], 1, null)
		if _has_tag(m, "lust_thorns"):
			_damage_player(p, 1, null)
		await xp.on_combat_hit(p, m, raw, dmg)
	else:
		var d: int = _mon_atk(m)
		if _has_tag(m, "dbl1") and raw == 1:
			d *= 2
		if _has_tag(m, "plus2") and raw == 2:
			d += 1
		if _has_tag(m, "chub") and raw == 1:
			m.hp = min(m.max, m.hp + 2)
		d = xp.player_combat_dmg(p, m, raw, d)
		_toast("Errou — %s causa %d" % [_tname(m), d], Color(1, 0.6, 0.5))
		_float3d("ERROU", mc.global_position, Color(0.85, 0.8, 0.75))
		mc.lunge(pc.global_position, 0.4)
		Sfx.play("mon_grunt")
		await _wait(0.17)
		if p.dead or game_over:
			return
		combat_damage = true
		_damage_player(p, d, m)
		combat_damage = false
		await xp.on_attack_miss(p, m, raw)
	await xp.after_attack_roll(p, m, raw, hit)

# s >= 0: espaço da loja · -1: topo do deck de tesouros · -2: topo do descarte de tesouros (Recycling Sticker).
func _act_buy(p: Dictionary, s: int) -> void:
	if p.bought >= p.buy_limit:
		return
	var price: int = _shop_price(p) if s >= 0 or s == -2 else D.SHOP_PRICE
	if s >= 0 and xp.free_purchase(p):
		price = 0
	if p.coins < price:
		return
	# Valida a origem ANTES de cobrar (antes o jogador perdia ¢ com o deck/espaço vazio).
	if (s == -1 and treasure_ids.is_empty()) or (s >= 0 and shop[s] == null) or (s == -2 and treasure_discard.is_empty()):
		return
	var from: Transform3D
	var id: String
	if s == -2:
		p.coins -= price
		id = treasure_discard.pop_back()
		from = decks.treasure.top_xf()
	elif s < 0:
		p.coins -= price
		id = treasure_ids.pop_back()
		decks.treasure.bump()
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
	Sfx.play("buy")
	_toast("%s comprou %s" % [p.name, D.ITEMS[id][0]])
	_gain_item(p, id, from)
	_ui()
	await xp.on_purchase(p, id, price)
	await _wait(0.4)
	if s >= 0 and xp.shop_refills():
		_shop_fill(s)

func _act_tap_char(p: Dictionary) -> void:
	if p.char_tapped:
		return
	if not xp.pay_tap(p):
		return
	p.char_tapped = true
	Sfx.play("char_tap")
	if await xp.tap_char(p):
		_layout_items(p)
		_ui()
		return
	p.loot_plays += 1
	_layout_items(p)
	_ui()

# Joga um loot. `target` já escolhido quando o loot precisa de alvo.
func _act_play_loot(p: Dictionary, c: Card3D, target = null, free := false) -> void:
	if free:
		pass
	elif not xp.may_play_loot(p):
		return
	elif p.i == active and p.loot_plays > 0:
		p.loot_plays -= 1
	elif not p.char_tapped:
		p.char_tapped = true
		_layout_items(p)
	else:
		return
	p.hand.erase(c)
	if c == selected_card:
		selected_card = null
	if c == drag_card:
		drag_card = null
		drag_active = false
	c.reparent(table, true)
	c.bob = false
	c.highlight(false)
	c.zone = "stack"
	Sfx.play("card_play")
	_layout_hand(p)
	var id: String = c.id
	var e := {"kind": "loot", "owner": p, "name": D.LOOT[id][0], "card": c, "target": target}
	e.fn = _loot_effect(p, id, target, e)
	if target is Dictionary and target.type == "monster":
		var mu: int = target.m.uid
		e.valid = func() -> bool: return _find_mon(mu) != null
	_toast("%s joga %s" % [p.name, D.LOOT[id][0]])
	xp.on_loot_played(p, id, e)
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
	return xp.loot_effect(p, id, target, e)

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
	_discard_item(it)
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
	if await xp.on_destroy(p, it):
		return
	# The Chest: se fosse destruído, vira uma alma.
	if it.id == "thechest":
		_item_to_soul(p, it)
		return
	# Remove de quem tem o item agora (pode ter mudado de dono durante um await); já fora de jogo = nada a fazer.
	var holder = null
	for q in players:
		if q.items.has(it):
			holder = q
	if holder == null or not is_instance_valid(it.card):
		return
	Sfx.play("destroy")
	holder.items.erase(it)
	_discard_item(it)
	_layout_items(holder)

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
				if x.kind == "loot":
					_discard_card(x.card, true)  # loot cancelado vai para o descarte, não some
				else:
					(x.card as Card3D).queue_free()
			_toast("Cancelado: " + x.name)
			break

func _on_item_activated(p: Dictionary, _it: Dictionary) -> void:
	xp.on_item_activated(p, _it)
	if _n(p, "shinyrock") > 0:
		_gain_coins(p, 1, (p.char_card as Card3D).global_position)
	for m in _all_mons():
		if _has_tag(m, "gurdyjr") and in_combat and is_same(combat.get("p", null), p):
			_damage_player(p, 1, m)
		if _has_tag(m, "curse_activate_dmg"):
			_damage_player(p, 1, m)

func _item_needs_target(id: String) -> bool:
	return id in ["yumheart", "bloodlust", "mrboom", "razorblade", "guppyspaw", "jawbone", "momsbra", "twoofclubs", "thed4"] or xp.item_needs_target(id)

func _paid_cost(id: String) -> int:
	return {"batterybum": 4, "goldenrazorblade": 5, "paytoplay": 10, "portableslotmachine": 3}.get(id, 0)

func _paid_usable(it: Dictionary) -> bool:
	var id: String = it.id
	if players[0].coins < _paid_cost(id):
		return false
	if not xp.paid_usable(it):
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
		_:
			if not await xp.item_paid(p, it, target):
				return
	Sfx.play("item_use")
	xp.on_item_activated(p, it)
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
			e.fn = func() -> void:
				var src = await _choose_item(p, func(x): return x != it and not _is_eternal(x) and D.ITEMS[x.id][2] == "passive", "Diplopia — copiar qual item passivo?")
				if src != null: _copy_item(it, src.id, true)
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
			e.fn = func() -> void:
				var src = await _choose_item(p, func(x): return x != it and not _is_eternal(x), "Modeling Clay — copiar qual item?")
				if src != null: _copy_item(it, src.id, false)
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
			e.fn = func() -> void:
				# Vira cópia (até o fim do turno) de um item ↷ e fica recarregado para usar a habilidade.
				var src = await _choose_item(p, func(x): return x != it and not _is_eternal(x) and D.ITEMS[x.id][2] in ["tap", "both"], "Placebo — copiar a habilidade de qual item?")
				if src != null:
					_copy_item(it, src.id, true)
					it.tapped = false
					_layout_items(p)
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
			e.fn = func() -> void:
				var victim = await _choose_item(p, func(x): return not _is_eternal(x), "The D20 — rerrolar qual item?", true)
				if victim != null: await _reroll_item(victim)
		"thed4":
			e.fn = func() -> void:
				var tp := _target_p(target, p)
				_destroy_item(p, it)
				for x in tp.items.duplicate():
					if not _is_eternal(x):
						await _reroll_item(x)
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
			if not await xp.item_tap(p, it, target, e):
				return
	if not xp.pay_tap(p):
		return
	it.tapped = true
	Sfx.play("item_use")
	_layout_items(p)
	# Cópia fantasma do item sobe para a pilha (o item pode ter sido destruído ao ativar: Magic Skin, Glass Cannon...).
	var src_ok := is_instance_valid(it.card)
	if src_ok:
		(it.card as Card3D).sheen(0.4)
	var ghost := Card3D.make(id, "treasureback")
	table.add_child(ghost)
	if src_ok:
		ghost.transform = (it.card as Card3D).transform
	ghost.zone = "stack"  # inspecionável enquanto está na pilha
	ghost.tapped.connect(_on_card_tapped)
	e.card = ghost
	_on_item_activated(p, it)
	if p.dead:
		# Morreu ativando o item (Gurdy Jr., maldição): a habilidade não chega a entrar na pilha.
		ghost.queue_free()
		return
	_toast("%s ativa %s" % [p.name, D.ITEMS[id][0]])
	_push(e)
	await _run_stack()

# Escolhe um item em jogo (de qualquer jogador). `hostile` = CPU prefere itens do oponente.
func _choose_item(p: Dictionary, ok: Callable, title: String, hostile := false):
	var pool: Array = []
	for q in players:
		for x in q.items:
			if ok.call(x):
				pool.append(x)
	if pool.is_empty():
		_toast("Nenhum item válido")
		return null
	if p.bot or autoplay:
		var pref: Array = pool.filter(func(x): return is_same(x.owner, p) != hostile)
		return (pref if not pref.is_empty() else pool).pick_random()
	var ids: Array = []
	for x in pool:
		if not ids.has(x.id):
			ids.append(x.id)
	var pick: String = await _choose_card(ids, title)
	for x in pool:
		if x.id == pick:
			return x
	return null

# Item vira cópia de outro. Temporário = volta ao original no fim do turno.
func _copy_item(it: Dictionary, new_id: String, temporary: bool) -> void:
	if not is_instance_valid(it.card):
		return  # o item saiu de jogo antes da habilidade resolver
	if temporary and not it.has("orig_id"):
		it.orig_id = it.id
	it.id = new_id
	(it.card as Card3D).set_front(new_id)
	(it.card as Card3D).sheen()
	_toast("Agora é uma cópia de %s" % D.ITEMS[new_id][0])
	_ui()

func _revert_copies() -> void:
	for q in players:
		for x in q.items:
			if x.has("orig_id"):
				x.id = x.orig_id
				x.erase("orig_id")
				(x.card as Card3D).set_front(x.id)

# Rerrolar item: vai para o descarte e o dono ganha o topo do deck de tesouros no lugar.
func _reroll_item(x: Dictionary) -> void:
	var owner: Dictionary = x.owner
	if not owner.items.has(x) or treasure_ids.is_empty():
		return
	owner.items.erase(x)
	_discard_item(x)
	_layout_items(owner)
	await _gain_treasure(owner, 1)

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
		var must: String = xp.must_attack_reason(players[0])
		if must != "":
			_toast(must, Color(1, 0.6, 0.5))
			return
		end_turn_requested.emit()

func _on_deck_tapped(d: Deck3D, kind: String) -> void:
	if targeting != "" or overlay.visible:
		return
	match kind:
		"treasure":
			var me0: Dictionary = players[0]
			var tb := [["COMPRAR TOPO · 10¢", func(): _close_inspect(); _act_buy(me0, -1), _human_idle() and me0.bought < me0.buy_limit and me0.coins >= D.SHOP_PRICE]]
			if _n(me0, "recyclingsticker") > 0 and not treasure_discard.is_empty():
				tb.append(["COMPRAR DO DESCARTE · %d¢" % _shop_price(me0), func(): _close_inspect(); _act_buy(me0, -2), _human_idle() and me0.bought < me0.buy_limit and me0.coins >= _shop_price(me0)])
			_open_inspect("treasureback", "Deck de Tesouros", "%d cartas. Compre a carta do topo às cegas por %d¢." % [treasure_ids.size(), D.SHOP_PRICE], tb)
		"monster":
			var me1: Dictionary = players[0]
			var can: bool = _human_idle() and not monster_ids.is_empty() and (me1.attacks > 0 or int(me1.state.get("deck_attacks", 0)) > 0)
			_open_inspect("monsterback", "Deck de Monstros", "%d cartas. Atacar o topo: a carta revelada cobre um espaço e você a ataca." % monster_ids.size(),
				[["ATACAR O TOPO", func(): _close_inspect(); _act_attack_deck(me1), can]])
		"room":
			d.bump()
			_float3d("%d salas" % room_ids.size(), d.global_position, PAPER)
		"loot":
			# Sem interação possível: só a contagem, sem abrir janela.
			var n: int = monster_ids.size() if kind == "monster" else loot_ids.size()
			d.bump()
			_float3d("%d cartas" % n, d.global_position, PAPER)
		"discard":
			_open_discard()

# Descarte de loot é informação pública: grade rolável (mais recente primeiro), toque amplia.
func _open_discard() -> void:
	if loot_discard.is_empty():
		_toast("Descarte vazio")
		return
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(480, 600)
	sc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	sc.add_child(g)
	for k in range(loot_discard.size() - 1, -1, -1):
		var id: String = loot_discard[k]
		var b := TextureButton.new()
		b.material = _card_mat()
		b.texture_normal = Card3D.tex(id)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(150, 205)
		b.pressed.connect(func(): _open_inspect(id, D.LOOT[id][0] if D.LOOT.has(id) else id, D.LOOT[id][1] if D.LOOT.has(id) else "", []))
		g.add_child(b)
	_open_custom_panel("DESCARTE · %d" % loot_discard.size(), sc)
	insp_forced = false
	var close := _btn("FECHAR", _close_inspect, false)
	insp_btns.add_child(close)

func _on_card_tapped(c: Card3D) -> void:
	if overlay.visible or game_over:
		return
	if Card3D.touch_mode and c.zone != "hand":
		c.press_pulse()
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
			# Toque decide no soltar: arrastar para cima joga, toque simples inspeciona (ver _input).
			c.set_hover(true)  # no celular, segurar a carta = hover
			drag_card = c
			drag_from = get_viewport().get_mouse_position()
			drag_active = false
		"room":
			xp.inspect_room(c)
		"item":
			var it: Dictionary = c.ref
			var info: Array = D.ITEMS[it.id]
			var btns := []
			var xt = xp.xtarget_of(it)
			if xt != null:
				btns.append(["ATACAR", func(): _close_inspect(); _attack(me, xt), _human_idle() and me.attacks > 0])
			if is_same(it.owner, me):
				var mode: String = info[2]
				if mode in ["tap", "both"]:
					btns.append(["ATIVAR", func(): _close_inspect(); _human_item(it), not it.tapped and _human_has_priority() and _item_usable(it.id)])
				if mode in ["paid", "both"]:
					btns.append(["PAGAR", func(): _close_inspect(); _human_item_paid(it), _human_has_priority() and _paid_usable(it)])
			_open_inspect(it.id, info[0] + ("  (virado)" if it.tapped else ""), info[1] + ("\nEterno." if info[3] else "") + xp.counter_note(it), btns)
		"char":
			var p: Dictionary = c.ref
			var st := "%s %d/%d    %s %d    %s %d    %d/%d almas" % [_ic("heart", 22), max(p.hp, 0), _max_hp(p), _ic("sword", 22), _atk(p), _ic("coin", 22), p.coins, p.soul_n, D.SOULS_TO_WIN]
			var txt := "Vire: jogue um loot adicional (pode ser feito no turno de qualquer jogador)."
			var btns := []
			if is_same(p, me):
				btns.append(["VIRAR (+1 LOOT)", func(): _close_inspect(); _act_tap_char(me), not me.char_tapped and _human_has_priority() and active == 0])
			else:
				var dc: int = xp.player_attack_dc(me, p)
				if dc > 0:
					btns.append(["ATACAR (%d+)" % dc, func(): _close_inspect(); _attack(me, xp.player_target(p, dc)), _human_idle() and me.attacks > 0])
			txt = xp.char_text(p, txt)
			_open_inspect(p.char, p.name, txt, btns, st)
		"monster":
			var m = c.ref
			if m == null or not (m is Dictionary) or not m.has("uid"):
				return
			var d: Array = _mdata(m.id)
			var st := "%s %d/%d    %s %d+    %s %d" % [_ic("heart", 22), max(m.hp, 0), m.max, _ic_die(_eva(m), 22), _eva(m), _ic("sword", 22), _mon_atk(m)]
			var txt := String(d[8])
			var rew := []
			if d[4]: rew.append("%d¢" % d[4])
			if d[5]: rew.append("loot %d" % d[5])
			if d[6]: rew.append("%d tesouro" % d[6])
			if d[7]: rew.append("%d alma" % d[7])
			if String(d[9]) == "rollcents": rew.append("¢ (por rolagem)")
			elif String(d[9]) == "rollloot": rew.append("loot (por rolagem)")
			if int(m.get("counters", 0)) > 0: txt += "\nFichas: %d" % int(m.counters)
			if not rew.is_empty():
				txt += ("\n" if txt != "" else "") + "Recompensa: " + ", ".join(rew)
			var is_top: bool = _find_mon(m.uid) != null
			_open_inspect(m.id, d[0], txt, [["ATACAR", func(): _close_inspect(); _act_attack(me, m.slot), is_top and _human_idle() and me.attacks > 0]], st)
		"shop":
			var s: int = c.ref
			var info: Array = D.ITEMS[c.id]
			var pr: int = _shop_price(me)
			_open_inspect(c.id, info[0], info[1], [["COMPRAR · %d¢" % pr, func(): _close_inspect(); _act_buy(me, s), _human_idle() and me.bought < me.buy_limit and me.coins >= pr]])
		"soul":
			_open_inspect(c.id, _card_disp_name(c.id), "Alma de %s." % c.ref.name, [])
		"stack", "discard":
			if D.LOOT.has(c.id):
				_open_inspect(c.id, D.LOOT[c.id][0], D.LOOT[c.id][1], [])
			elif D.ITEMS.has(c.id):
				_open_inspect(c.id, D.ITEMS[c.id][0], D.ITEMS[c.id][1], [])

func _inspect_hand_card(c: Card3D) -> void:
	var me: Dictionary = players[0]
	if selected_card != c:
		selected_card = c
		_layout_hand(me)
	var info: Array = D.LOOT[c.id]
	_open_inspect(c.id, info[0], info[1],
		[["JOGAR", func(): _close_inspect(); _human_play_loot(c), _human_can_play_loot() and _loot_playable(c.id)]])

# Arrastar carta da mão: segue o dedo (com inclinação/flexão pela velocidade) e joga ao soltar no alto.
func _input(event: InputEvent) -> void:
	if drag_card == null:
		return
	if not is_instance_valid(drag_card) or drag_card.zone != "hand" or not is_same(drag_card.ref, players[0]) \
			or overlay.visible or game_over:
		if is_instance_valid(drag_card) and Card3D.touch_mode:
			drag_card.set_hover(false)
		drag_card = null
		drag_active = false
		return
	if event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		if not drag_active and drag_from.distance_to(pos) > 16:
			drag_active = true
			drag_card.stop_move()
			if selected_card != null:
				selected_card = null
			_layout_hand(players[0])
		if drag_active:
			var world := cam.project_position(pos, 1.9)
			var lp := hand_root.to_local(world)
			drag_card.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.8), lp + Vector3(0, 0.12, 0))
			var vh := get_viewport().get_visible_rect().size.y
			var can: bool = pos.y < vh * 0.7 and _human_can_play_loot() and _loot_playable(drag_card.id)
			drag_card.highlight(pos.y < vh * 0.7, Color(0.5, 1.0, 0.55) if can else Color(1.0, 0.3, 0.25))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var c := drag_card
		var was_drag := drag_active
		drag_card = null
		drag_active = false
		c.highlight(false)
		if Card3D.touch_mode:
			c.set_hover(false)
		if not was_drag:
			_inspect_hand_card(c)
			return
		var vh := get_viewport().get_visible_rect().size.y
		var high: bool = event.position.y < vh * 0.7
		if high and _human_can_play_loot() and _loot_playable(c.id):
			_layout_hand(players[0])
			_human_play_loot(c)
		else:
			if high:
				_toast("Não dá para jogar %s agora" % D.LOOT[c.id][0], Color(1, 0.6, 0.5))
				c.shake(0.03)
			_layout_hand(players[0])

func _loot_playable(id: String) -> bool:
	if not xp.loot_playable(id):
		return false
	match D.LOOT[id][2]:
		"roll":
			return _top_roll() != null
		"cancel":
			return _top_cancelable() != null
	return true

func _item_usable(id: String) -> bool:
	if id in ["d6", "spoon", "bookofbelial", "luckyfoot", "minimush", "godhead"]:
		return _top_roll() != null
	if not xp.item_usable(id):
		return false
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
	return id in ["goldenrazorblade", "techx", "thebone"] or xp.paid_needs_target(id)

func _human_item_paid(it: Dictionary) -> void:
	var me: Dictionary = players[0]
	var target = null
	if _paid_needs_target(it.id):
		target = await _choose_target("Escolha o alvo de " + D.ITEMS[it.id][0])
		if target == null:
			return
	await _act_paid(me, it, target)

# `stats` = linha de atributos já em BBCode (ícones); `text` é texto puro da carta.
func _open_inspect(tex_id: String, title: String, text: String, btns: Array, stats := "") -> void:
	Sfx.play("inspect")
	inspect.visible = true
	insp_forced = false
	insp_tex.visible = true
	insp_tex.texture = Card3D.tex(tex_id)
	insp_title.text = title
	insp_title.visible = false
	var body := text.replace("[", "[lb]")
	if stats != "":
		body = "[font_size=24]%s[/font_size]%s" % [stats, ("\n" + body) if body != "" else ""]
	insp_text.text = "[center]%s[/center]" % body
	insp_note.visible = body != ""
	_clear_custom_panel()
	for b in insp_btns.get_children():
		b.queue_free()
	for b in btns:
		var bt := _btn(b[0], b[1])
		bt.disabled = not b[2]
		insp_btns.add_child(bt)
	var close := _btn("FECHAR", _close_inspect, false)
	insp_btns.add_child(close)
	# Entrada: fundo escurece, carta "salta" girando de leve, textos e botões chegam em seguida.
	var bg := inspect as ColorRect
	bg.color.a = 0.0
	insp_tex.pivot_offset = insp_tex.custom_minimum_size / 2
	insp_tex.scale = Vector2(0.55, 0.55)
	insp_tex.rotation = -0.12
	insp_tex.modulate.a = 0.0
	insp_btns.modulate.a = 0.0
	insp_text.modulate.a = 0.0
	var t := insp_tex.create_tween().set_parallel()
	t.tween_property(bg, "color:a", 0.8, 0.18)
	t.tween_property(insp_tex, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Salas são horizontais: a arte guardada em pé gira de volta na inspeção.
	t.tween_property(insp_tex, "rotation", -PI / 2 if D.ROOMS.has(tex_id) else 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(insp_tex, "modulate:a", 1.0, 0.12)
	t.tween_property(insp_text, "modulate:a", 1.0, 0.2).set_delay(0.1)
	t.tween_property(insp_btns, "modulate:a", 1.0, 0.2).set_delay(0.16)
	t.tween_method(func(x: float): (insp_tex.material as ShaderMaterial).set_shader_parameter("shine", x), -0.2, 1.3, 0.7).set_delay(0.2)

func _close_inspect() -> void:
	inspect.visible = false
	insp_forced = false
	if selected_card != null:
		selected_card = null
		_layout_hand(players[0])

# `kinds`: "any" (monstro ou jogador), "monster" ou "player"; `mfilter` restringe os monstros.
func _choose_target(msg: String, kinds := "any", mfilter := Callable()):
	target_valid = []
	if kinds != "player":
		for s in slots.size():
			var m = _top(s)
			if m != null and (not mfilter.is_valid() or mfilter.call(m)):
				target_valid.append({"type": "monster", "m": m, "card": m.card})
	if kinds != "monster":
		for p in players:
			if not p.dead:
				target_valid.append({"type": "player", "p": p, "card": p.char_card})
	if target_valid.is_empty():
		return null
	targeting = msg
	prompt_lbl.text = msg
	prompt_panel.visible = true
	for t in target_valid:
		(t.card as Card3D).highlight(true)
	# Cartas flutuando na pilha ficam entre a câmera e os alvos: tiram o raio do caminho.
	var blockers := []
	for e in stack:
		if e.get("card") != null and is_instance_valid(e.card):
			(e.card as Card3D).set_pickable(false)
			blockers.append(e.card)
	_ui()
	var r = await target_chosen
	for b in blockers:
		if is_instance_valid(b):
			(b as Card3D).set_pickable(true)
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
const BOT_PACE := 1.7  # CPU mais lenta: dá tempo de acompanhar cada ação
func _bot_turn(p: Dictionary) -> void:
	await _wait(0.8 * BOT_PACE)
	# Strength antes de atacar, moedas e bombas oportunas; baterias depois de gastar itens.
	await _bot_play_loots(p)
	await _bot_use_items(p)
	await _bot_play_loots(p)
	await _bot_use_items(p)
	await xp.bot_turn_extra(p)
	# Compra
	if not turn_over and not game_over and p.coins >= D.SHOP_PRICE:
		var s := -1
		for i in shop.size():
			if shop[i] != null:
				s = i
				break
		if s >= 0:
			await _act_buy(p, s)
			await _wait(0.5 * BOT_PACE)
	# Ataque(s)
	var guard := 0
	while not turn_over and not game_over and not p.dead and guard < 12:
		guard += 1
		var forced = xp.bot_forced_attack(p)
		if forced is String and forced == "deck":
			await _act_attack_deck(p)
			await _wait(0.6 * BOT_PACE)
			continue
		elif forced is Dictionary:
			await _attack(p, forced, p.attacks <= 0)
			await _wait(0.6 * BOT_PACE)
			continue
		if p.attacks <= 0:
			break
		var best := -1
		var best_score := -999.0
		for s in slots.size():
			var m = _top(s)
			if m == null or _has_tag(m, "untargetable"):
				continue
			if xp.can_attack(p, m) != "":
				continue
			var d: Array = _mdata(m.id)
			var hit_p: float = clampf((7.0 - _eva(m) + _n(p, "meat") + _n(p, "synthoil")) / 6.0, 0.05, 1.0)
			var score: float = d[7] * 6.0 + d[4] * 0.4 + d[5] * 0.8 + d[6] * 2.0 + hit_p * 4.0 - m.hp * 0.8 - _mon_atk(m) * 0.5
			# Evita suicídio: monstro que mata num erro e é difícil de acertar (antes a CPU vivia atacando Satan).
			if _mon_atk(m) >= p.hp:
				score -= (1.0 - hit_p) * 8.0 + m.hp * 0.6
			score -= int(m.get("bot_fails", 0)) * 4.0  # desiste de alvos em que já morreu
			if score > best_score:
				best_score = score
				best = s
		if best < 0 or best_score < -3.0:  # nenhum alvo que valha o risco
			if best < 0 and not monster_ids.is_empty() and p.hp >= 2:
				await _act_attack_deck(p)
				await _wait(0.6 * BOT_PACE)
				continue
			break
		await _act_attack(p, best)
		await _wait(0.6 * BOT_PACE)
	await _wait(0.5 * BOT_PACE)

func _bot_play_loots(p: Dictionary) -> void:
	var guard := 0
	while not turn_over and not game_over and guard < 4:
		guard += 1
		var pick := _bot_pick_loot(p)
		if pick.is_empty():
			break
		await _act_play_loot(p, pick.card, pick.get("target"))
		await _wait(0.5 * BOT_PACE)

func _bot_use_items(p: Dictionary) -> void:
	var o := _opp(p)
	for it in p.items.duplicate():
		if turn_over or game_over:
			break
		if it.tapped:
			continue
		var use := false
		match it.id:
			"booksin", "sackofpennies": use = true
			"guppyshead": use = not o.hand.is_empty()
			"razorblade": use = not o.dead and (o.hp <= 1 or randf() < 0.5)
			_: use = xp.bot_wants_item(p, it)
		if use:
			await _act_item(p, it)
			await _wait(0.4 * BOT_PACE)

func _bot_pick_loot(p: Dictionary) -> Dictionary:
	if p.loot_plays <= 0 and p.char_tapped:
		return {}
	var o := _opp(p)
	var tapped_item: bool = p.items.any(func(it): return it.tapped and D.ITEMS[it.id][2] in ["tap", "both"])
	for c in p.hand:
		match c.id:
			"penny", "twocents", "threecents", "fourcents", "nickel", "dime", "strength":
				return {"card": c}
			"battery", "megabattery":
				if tapped_item:  # antes gastava Mega Battery sem nada virado
					return {"card": c}
			"pills_blue", "pills_red":
				return {"card": c}
			"pills_orange":
				if p.hp >= 2 and p.loot_plays > 0:
					return {"card": c}
			_:
				if D.TRINKETS.has(c.id):  # trinkets são valor permanente: sempre jogar
					return {"card": c}
	for c in p.hand:
		if c.id in ["bomb", "goldbomb"]:
			var dmg := 3 if c.id == "goldbomb" else 1
			for s in slots.size():
				var m = _top(s)
				if m != null and m.hp <= dmg:
					return {"card": c, "target": {"type": "monster", "m": m, "card": m.card}}
			if o.hp <= dmg and not o.dead:
				return {"card": c, "target": {"type": "player", "p": o, "card": o.char_card}}
	return xp.bot_pick_loot(p)

func _bot_loot_in_hand(b: Dictionary, id: String) -> Card3D:
	for c in b.hand:
		if c.id == id:
			return c
	return null

# Resposta da CPU quando tem prioridade. Retorna true se colocou algo na pilha.
func _bot_respond() -> bool:
	var b: Dictionary = players[1]
	if b.dead or stack.is_empty():
		return false
	if _trinity_blocked(b):
		return false
	var top: Dictionary = stack.back()
	var can_loot: bool = (active == b.i and b.loot_plays > 0) or not b.char_tapped
	if top.kind == "roll" and top.get("attack", false):
		var m = _find_mon(top.get("mon_uid", -1))
		if m == null:
			return false  # monstro já saiu (antes: crash em _eva(null) ao avaliar o Spoon Bender)
		var hits := _roll_hits(top)
		var mine: bool = is_same(top.owner, b)
		var boss: bool = _mdata(m.id)[7] > 0
		if (mine and not hits) or (not mine and hits and boss and m.hp <= _atk(top.owner)):
			for it in b.items:
				if it.id == "d6" and not it.tapped:
					_act_item(b, it)
					return true
			var shard := _bot_loot_in_hand(b, "diceshard")
			if shard != null and can_loot:
				_act_play_loot(b, shard)
				return true
			if mine and top.value + top.bonus + 1 + _n(b, "meat") + _n(b, "synthoil") >= _eva(m):
				for it in b.items:
					if it.id == "spoon" and not it.tapped:
						_act_item(b, it)
						return true
		if mine and not hits and _mon_atk(m) >= b.hp and b.shield == 0:
			for it in b.items:
				if it.id == "yumheart" and not it.tapped:
					_act_item(b, it)
					return true
			var sh := _bot_loot_in_hand(b, "soulheart")
			if sh != null and can_loot:
				_act_play_loot(b, sh)
				return true
	# Cancela loot/habilidade do oponente que mira a CPU (ex.: bomba).
	if not is_same(top.owner, b) and top.kind in ["loot", "ability"] and _threatens(top, b) and can_loot:
		var bean := _bot_loot_in_hand(b, "butterbean")
		if bean != null:
			_act_play_loot(b, bean)
			return true
	return xp.bot_respond(b, top, can_loot)

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
	var t := autoplay_turns  # o turno pode acabar no meio (morte): não agir no turno da CPU
	if not me.char_tapped and randf() < 0.35:
		_act_tap_char(me)
		await _wait(0.3)
	var guard := 0
	while me.attacks > 0 and _sim_on(t) and guard < 4:
		guard += 1
		var s := _sim_pick_monster()
		if s < 0:
			break
		await _act_attack(me, s)
		await _wait(0.3)
	for it in me.items.duplicate():
		if not _sim_on(t):
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
	while _human_can_play_loot() and guard < 3 and _sim_on(t):
		guard += 1
		var c = _sim_pick_loot(me)
		if c == null:
			break
		await _human_play_loot(c)
		await _wait(0.2)
	for i in shop.size():
		if shop[i] != null and me.coins >= _shop_price(me) and _sim_on(t):
			await _act_buy(me, i)
			break
	if _sim_on(t):
		await xp.sim_extra(me)
	if _sim_on(t):
		end_turn_requested.emit()
	sim_busy = false

func _sim_on(t: int) -> bool:
	return active == 0 and autoplay_turns == t and not turn_over and not game_over

# --shots=DIR (com janela, sem --headless): capturas periódicas da tela para revisar o HUD; tempo 2×.
func _autoplay_shots() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	time_base = 2.0
	Engine.time_scale = time_base
	var n := 0
	while not game_over and n < 40:
		await get_tree().create_timer(1.5, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [dir, n])
		n += 1

# --give=id,id,... : entrega itens (tesouros) ou loots ao jogador 0 para testar cartas específicas.
func _autoplay_give() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--give="):
			continue
		for id in a.trim_prefix("--give=").split(","):
			if D.LOOT.has(id):
				_loot_to_hand(players[0], id)
			elif D.ITEMS.has(id):
				_gain_item(players[0], id, decks.treasure.top_xf())
			elif D.MONSTERS.has(id) or D.EVENTS.has(id):
				monster_ids.erase(id)
				monster_ids.push_back(id)  # topo do deck: revela logo
			elif D.ROOMS.has(id):
				xp.give_room(id)
			else:
				push_error("--give: id desconhecido " + id)

func _sim_pick_monster() -> int:
	var opts := []
	for s in slots.size():
		var m = _top(s)
		if m != null and not _has_tag(m, "untargetable") and int(m.get("bot_fails", 0)) < 3:
			opts.append(s)
	return opts.pick_random() if not opts.is_empty() else -1

func _sim_pick_loot(me: Dictionary):
	for c in me.hand:
		if _loot_playable(c.id):
			return c
	return null
