extends Control
# Seleção de personagem (menu → aqui → main.tscn). Visual do "WHO AM I?" do TBOI no estilo do menu
# (papel pregado, tinta, Upheaval torta): anel girável de cartas (arrastar, tocar nas laterais, setas,
# teclado/roda), atributos + item inicial do personagem em foco, slot "?" aleatório e sequência de
# vitórias (user://profile.cfg). A escolha chega à partida pelas statics abaixo (main.gd › Sel.pick).

const D := preload("res://scripts/data.gd")
const Scrawl := preload("res://scripts/menu.gd").Scrawl
const GAME_SCENE := "res://main.tscn"
const MENU_SCENE := "res://menu.tscn"
const UI := "res://assets/ui/select/"
const PROFILE := "user://profile.cfg"
const INK := Color8(55, 43, 44)
const INK_HOT := Color8(140, 32, 44)
const INK_SOFT := Color8(110, 88, 90)
const RANDOM := "random"
const CARD := Vector2(210, 287)   # carta em destaque (arte 400×546)
const RING_C := Vector2(270, 352) # centro do anel na coluna 540×960
const STEP := 0.52                # ângulo entre vizinhas
const RADIUS := 300.0
const BOARD_POS := Vector2(12, 50)
const BOARD_ROT := -0.018

# ---------------- Escolha e perfil (estáticos: sobrevivem à troca de cena) ----------------
static var chosen := ""
static var random_mode := false   # "?" escolhido: cada "jogar novamente" sorteia de novo
static var _reroll := false

static func pick() -> String:
	if not D.CHARACTERS.has(chosen) or (random_mode and _reroll):
		chosen = D.CHARACTER_ORDER[randi() % D.CHARACTER_ORDER.size()]
	_reroll = true
	return chosen

static func profile() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(PROFILE)
	return c

# Fim de partida (só humano de verdade): sequência zera na derrota; vitórias contadas por personagem.
static func record(won: bool, cid: String) -> void:
	var c := profile()
	var s: int = (c.get_value("stats", "streak", 0) + 1) if won else 0
	c.set_value("stats", "streak", s)
	c.set_value("stats", "best", maxi(s, c.get_value("stats", "best", 0)))
	if won:
		c.set_value("wins", cid, c.get_value("wins", cid, 0) + 1)
	c.save(PROFILE)

# ---------------- Tela ----------------
var font: Font
var col: Control
var board: TextureRect
var ids: Array = []
var cards: Array = []          # um Control por id (filho "Face" = arte)
var cur := 0.0                 # posição contínua do anel (em cartas)
var target := 0.0
var spinning := false          # cur animado por tween (intro / sorteio)
var dragging := false
var drag_moved := false
var drag_x := 0.0
var drag_cur := 0.0
var drag_vel := 0.0
var shown := -1
var others_a := 1.0            # some com as não escolhidas na confirmação
var name_tex: TextureRect
var name_scr  # Scrawl: nome escrito para personagens sem letreiro recortado (expansões)
var hp_lbl: Scrawl
var atk_lbl: Scrawl
var wins_lbl: Scrawl
var item_card: TextureRect
var item_q: Control
var arrows: Array = []
var play_btn: Button
var zoom: Control
var fader: ColorRect
var soft_tex: GradientTexture2D
var busy := true

func _ready() -> void:
	font = load("res://assets/fonts/Upheaval.ttf")
	ids = D.CHARACTER_ORDER.duplicate()
	ids.append(RANDOM)
	_build_backdrop()
	col = Control.new()
	col.set_anchors_preset(PRESET_CENTER)
	col.offset_left = -270
	col.offset_right = 270
	col.offset_top = -480
	col.offset_bottom = 480
	col.mouse_filter = MOUSE_FILTER_IGNORE
	col.texture_filter = TEXTURE_FILTER_NEAREST  # sprites em pixel art; cartas voltam ao linear
	add_child(col)
	_build_board()
	_build_ring()
	_build_info()
	_build_footer()
	_build_zoom()
	fader = ColorRect.new()
	fader.color = Color.BLACK
	fader.set_anchors_preset(PRESET_FULL_RECT)
	fader.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(fader)
	_intro()

func _build_backdrop() -> void:
	var base := ColorRect.new()
	base.color = Color(0.035, 0.025, 0.02)
	base.set_anchors_preset(PRESET_FULL_RECT)
	add_child(base)
	var t := TextureRect.new()
	t.texture = load("res://assets/table.jpg")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_preset(PRESET_FULL_RECT)
	t.modulate = Color(0.4, 0.31, 0.26)
	add_child(t)
	var vig := ColorRect.new()
	vig.set_anchors_preset(PRESET_FULL_RECT)
	vig.mouse_filter = MOUSE_FILTER_IGNORE
	vig.material = _shader("""shader_type canvas_item;
void fragment(){ COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.25, 0.8, distance(UV, vec2(0.5, 0.42))) * 0.9); }""")
	add_child(vig)
	soft_tex = GradientTexture2D.new()
	soft_tex.fill = GradientTexture2D.FILL_RADIAL
	soft_tex.fill_from = Vector2(0.5, 0.5)
	soft_tex.fill_to = Vector2(1.0, 0.5)
	var sg := Gradient.new()
	sg.set_color(0, Color.WHITE)
	sg.set_color(1, Color(1, 1, 1, 0))
	soft_tex.gradient = sg
	var e := CPUParticles2D.new()
	e.amount = 30
	e.lifetime = 6.0
	e.preprocess = 6.0
	e.texture = soft_tex
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.direction = Vector2(0, -1)
	e.spread = 20
	e.gravity = Vector2(0, -10)
	e.initial_velocity_min = 30
	e.initial_velocity_max = 100
	e.scale_amount_min = 0.05
	e.scale_amount_max = 0.16
	e.color = Color(1.0, 0.5, 0.2)
	e.color_ramp = sg
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	e.material = cm
	var fit := func():
		var vs := get_viewport_rect().size
		e.emission_rect_extents = Vector2(vs.x / 2, 10)
		e.position = Vector2(vs.x / 2, vs.y + 10)
	fit.call()
	get_viewport().size_changed.connect(fit)
	add_child(e)

func _shader(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

# ---------------- Quadro "WHO AM I?" ----------------
func _build_board() -> void:
	# Mancha de sangue na mesa, saindo de baixo do item inicial.
	var blood := _tex("blood.png", Vector2(300, 790), Vector2(262, 102))
	blood.rotation = 0.35
	blood.modulate.a = 0.85
	col.add_child(blood)
	board = _tex("board.png", BOARD_POS, Vector2(515, 606))
	col.add_child(board)
	var tack := Tack.new()
	tack.position = Vector2(257, 18)
	board.add_child(tack)

# ---------------- Anel de cartas ----------------
func _build_ring() -> void:
	var round_mat := _shader("""shader_type canvas_item;
void fragment(){
	vec2 q = abs(UV - 0.5) * vec2(1.0, 1.365) - vec2(0.5, 0.6825) + 0.05;
	float d = length(max(q, 0.0)) - 0.05;
	COLOR.a *= 1.0 - smoothstep(-0.004, 0.003, d);
}""")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for id in ids:
		var c := Control.new()
		c.size = CARD
		c.pivot_offset = CARD / 2
		c.mouse_filter = MOUSE_FILTER_IGNORE
		c.set_meta("tilt", rng.randf_range(-0.03, 0.03))
		var face: Control
		if id == RANDOM:
			face = Note.new().setup(CARD, 7)
			face.add_child(_tex("qmark.png", Vector2(45, 62), Vector2(120, 168)))
		else:
			var tr := TextureRect.new()
			tr.texture = Card3D.tex(id)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.size = CARD
			tr.material = round_mat
			tr.texture_filter = TEXTURE_FILTER_LINEAR
			var sh := TextureRect.new()
			sh.texture = tr.texture
			sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sh.size = CARD
			sh.position = Vector2(7, 11)
			sh.material = round_mat
			sh.modulate = Color(0, 0, 0, 0.45)
			sh.show_behind_parent = true
			tr.add_child(sh)
			face = tr
		face.name = "Face"
		face.pivot_offset = CARD / 2
		face.mouse_filter = MOUSE_FILTER_IGNORE
		c.add_child(face)
		col.add_child(c)
		cards.append(c)
	# Área de toque/arrasto do anel (por cima das cartas).
	var area := Control.new()
	area.position = Vector2(0, RING_C.y - 170)
	area.size = Vector2(540, 340)
	area.gui_input.connect(_ring_input)
	col.add_child(area)
	area.z_index = 200

func _process(d: float) -> void:
	if not spinning and not dragging:
		cur = lerpf(cur, target, 1.0 - exp(-d * 10.0))
	var n := ids.size()
	var t := Time.get_ticks_msec() / 1000.0
	for i in n:
		var c: Control = cards[i]
		var o := fposmod(i - cur + n * 0.5, n) - n * 0.5  # distância assinada até o centro
		var ao := absf(o)
		c.visible = ao < 2.6
		if not c.visible:
			continue
		var s := 1.0 / (1.0 + ao * 0.55)
		var x := RING_C.x + sin(clampf(o * STEP, -1.5, 1.5)) * RADIUS
		var y := RING_C.y - (1.0 - s) * 46.0 + sin(t * 1.5 + i) * 2.5 * s
		c.position = Vector2(x, y) - CARD / 2
		c.scale = Vector2(s, s)
		c.rotation = o * 0.08 + c.get_meta("tilt")
		c.z_index = 100 - int(ao * 10.0)
		var v := 1.0 - minf(ao, 2.0) * 0.3
		var a := clampf(2.6 - ao, 0.0, 1.0) * (1.0 if ao < 0.5 else others_a)
		c.modulate = Color(v, v, v, a)
	var idx := posmod(roundi(cur), n)
	if idx != shown:
		_show_info(idx)

func _ring_input(ev: InputEvent) -> void:
	if busy:
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			_step(1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			_step(-1)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				dragging = true
				drag_moved = false
				drag_x = ev.position.x
				drag_cur = cur
				drag_vel = 0.0
			elif dragging:
				dragging = false
				if drag_moved:
					target = roundf(cur + clampf(drag_vel * 0.12, -3.0, 3.0))  # arremesso gira mais
				else:
					_tap(ev.position.x)
	elif ev is InputEventMouseMotion and dragging:
		var dx: float = ev.position.x - drag_x
		if absf(dx) > 10.0:
			drag_moved = true
		if drag_moved:
			cur = drag_cur - dx / 170.0
			target = cur
			drag_vel = lerpf(drag_vel, -ev.velocity.x / 170.0, 0.5)

func _tap(x: float) -> void:
	if absf(x - RING_C.x) < CARD.x * 0.5:
		_confirm()
	else:
		_step(1 if x > RING_C.x else -1)

func _step(dir: int) -> void:
	if busy:
		return
	target = roundf(target) + dir
	var a: Control = arrows[0 if dir < 0 else 1]
	var tw := a.create_tween()
	tw.tween_property(a, "position:x", a.get_meta("x") + dir * 8.0, 0.06)
	tw.tween_property(a, "position:x", a.get_meta("x"), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---------------- Nome, atributos, item inicial ----------------
func _build_info() -> void:
	name_tex = _tex("name_isaac.png", Vector2.ZERO, Vector2.ONE)
	col.add_child(name_tex)
	name_scr = _scrawl("", 40, INK, 1.4)
	col.add_child(name_scr)
	for k in 2:
		var a := TextureButton.new()
		a.texture_normal = load(UI + ("arrow_l.png" if k == 0 else "arrow_r.png"))
		a.ignore_texture_size = true
		a.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		a.size = Vector2(54, 46)
		a.position = Vector2(46 if k == 0 else 440, 508)
		a.set_meta("x", a.position.x)
		a.focus_mode = FOCUS_NONE
		a.pressed.connect(_step.bind(-1 if k == 0 else 1))
		col.add_child(a)
		arrows.append(a)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.position = Vector2(20, 564)
	row.size = Vector2(500, 46)
	row.rotation = 0.012
	row.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(row)
	row.add_child(_icon("heart.png", Vector2(42, 40)))
	hp_lbl = _scrawl("2", 34)
	row.add_child(hp_lbl)
	row.add_child(_gap(22))
	row.add_child(_icon("sword.png", Vector2(36, 44)))
	atk_lbl = _scrawl("1", 34)
	row.add_child(atk_lbl)
	row.add_child(_gap(22))
	wins_lbl = _scrawl("", 20, INK_SOFT)
	row.add_child(wins_lbl)
	# Item inicial: carta pequena à direita, embaixo do quadro (toque amplia).
	var cap := _scrawl("ITEM INICIAL", 18, Color(0.91, 0.85, 0.87, 0.75))
	cap.position = Vector2(318, 672)
	cap.rotation = 0.03
	col.add_child(cap)
	item_card = TextureRect.new()
	item_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_card.texture_filter = TEXTURE_FILTER_LINEAR
	item_card.size = Vector2(128, 175)
	item_card.position = Vector2(326, 700)
	item_card.pivot_offset = item_card.size / 2
	item_card.rotation = 0.06
	item_card.material = cards[0].get_node("Face").material
	item_card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and item_card.texture:
			_open_zoom(item_card.texture))
	var sh := TextureRect.new()
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.size = item_card.size
	sh.position = Vector2(5, 8)
	sh.material = item_card.material
	sh.modulate = Color(0, 0, 0, 0.45)
	sh.show_behind_parent = true
	sh.name = "Shadow"
	item_card.add_child(sh)
	col.add_child(item_card)
	item_q = Note.new().setup(item_card.size, 11)
	item_q.position = item_card.position
	item_q.rotation = 0.06
	item_q.add_child(_tex("qmark.png", Vector2(37, 35), Vector2(54, 76)))
	col.add_child(item_q)

func _show_info(idx: int) -> void:
	if shown >= 0:
		Sfx.play("card_tap", 1.15)  # tique a cada carta que passa no centro (setas, arrasto, inércia, roleta)
	shown = idx
	var id: String = ids[idx]
	var rnd := id == RANDOM
	var path: String = UI + ("random.png" if rnd else "name_%s.png" % id)
	var has_png := ResourceLoader.exists(path)
	name_tex.visible = has_png
	name_scr.visible = not has_png
	if not has_png:
		var nm: String = str(D.CHARACTERS[id].name).to_upper()
		name_scr.set_text(nm)
		var fs := 40
		while name_scr.size.x > 440 and fs > 22:
			fs -= 4
			name_scr.fsize = fs
			name_scr.set_text(nm)
		name_scr.pivot_offset = name_scr.size / 2
		name_scr.position = Vector2(270, 531) - name_scr.size / 2
		name_scr.rotation = (hash(id) % 7 - 3) * 0.008
	var tex: Texture2D = load(path) if has_png else null
	if tex == null:
		tex = name_tex.texture
	var k := 2.6 if not rnd else 2.2
	name_tex.size = tex.get_size() * k
	name_tex.texture = tex
	name_tex.pivot_offset = name_tex.size / 2
	name_tex.position = Vector2(270, 531) - name_tex.size / 2
	name_tex.rotation = (hash(id) % 7 - 3) * 0.008  # cada nome levemente torto, sempre igual
	name_tex.scale = Vector2(1.12, 1.12)
	name_tex.create_tween().tween_property(name_tex, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var wins := 0
	if not rnd:
		wins = profile().get_value("wins", id, 0)
	hp_lbl.set_text("?" if rnd else str(D.CHARACTERS[id].hp))
	atk_lbl.set_text("?" if rnd else str(D.CHARACTERS[id].atk))
	wins_lbl.set_text("VITÓRIAS ???" if rnd else "VITÓRIAS %d" % wins)
	var item: String = "" if rnd else str(D.CHARACTERS[id].item)
	var has_item := D.ITEMS.has(item)  # Eden não tem: sorteia entre 3 tesouros na partida
	item_card.visible = has_item
	item_q.visible = not has_item
	if has_item:
		item_card.texture = Card3D.tex(item)
		item_card.get_node("Shadow").texture = item_card.texture

# ---------------- Rodapé: sequência de vitórias + JOGAR ----------------
func _build_footer() -> void:
	var c := profile()
	var note := Note.new().setup(Vector2(250, 136), 3)
	note.position = Vector2(26, 680)
	note.rotation = -0.04
	col.add_child(note)
	var l1 := _scrawl("VITÓRIAS", 24)
	l1.position = Vector2(18, 26)
	note.add_child(l1)
	var l2 := _scrawl("SEGUIDAS", 24)
	l2.position = Vector2(24, 56)
	note.add_child(l2)
	var best := _scrawl("RECORDE %d" % c.get_value("stats", "best", 0), 16, INK_SOFT)
	best.position = Vector2(20, 98)
	note.add_child(best)
	var n := _scrawl(str(c.get_value("stats", "streak", 0)), 58, INK_HOT, 1.3)
	n.position = Vector2(176, 34)
	n.rotation = 0.05
	note.add_child(n)
	# JOGAR! num bilhete próprio; com foco fica vermelho, treme de leve e ganha a seta do menu.
	var pn := Note.new().setup(Vector2(236, 88), 5)
	pn.position = Vector2(88, 846)
	pn.rotation = 0.025
	col.add_child(pn)
	play_btn = Button.new()
	play_btn.flat = true
	play_btn.position = Vector2(36, 18)
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		play_btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var pl := _scrawl("JOGAR!", 46, INK, 1.2)
	pl.position = Vector2(4, 6)
	play_btn.add_child(pl)
	play_btn.size = pl.size + Vector2(24, 12)
	play_btn.pivot_offset = play_btn.size / 2
	var arrow := TextureRect.new()
	arrow.texture = load("res://assets/ui/cursor.png")
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.size = Vector2(32, 38)
	arrow.position = Vector2(-50, play_btn.position.y + play_btn.size.y / 2 - 19)
	arrow.visible = false
	arrow.mouse_filter = MOUSE_FILTER_IGNORE
	pn.add_child(arrow)
	var tw := arrow.create_tween().set_loops()
	tw.tween_property(arrow, "position:x", -44.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(arrow, "position:x", -50.0, 0.35).set_trans(Tween.TRANS_SINE)
	play_btn.focus_entered.connect(func():
		pl.color = INK_HOT
		pl.set_boil(true)
		arrow.visible = true)
	play_btn.focus_exited.connect(func():
		pl.color = INK
		pl.set_boil(false)
		arrow.visible = false)
	play_btn.mouse_entered.connect(play_btn.grab_focus)
	play_btn.pressed.connect(func():
		var pt := play_btn.create_tween()
		pt.tween_property(play_btn, "scale", Vector2(0.9, 0.9), 0.05)
		pt.tween_property(play_btn, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_confirm())
	pn.add_child(play_btn)
	var back := Button.new()
	back.flat = true
	back.position = Vector2(14, 10)
	back.focus_mode = FOCUS_NONE
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		back.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var bl := _scrawl("< VOLTAR", 24, Color8(233, 218, 223))
	bl.position = Vector2(6, 6)
	back.add_child(bl)
	back.size = bl.size + Vector2(18, 14)
	back.mouse_entered.connect(func(): bl.color = Color8(230, 120, 120))
	back.mouse_exited.connect(func(): bl.color = Color8(233, 218, 223))
	back.pressed.connect(_back)
	col.add_child(back)

func _build_zoom() -> void:
	zoom = ColorRect.new()
	zoom.color = Color(0, 0, 0, 0.75)
	zoom.set_anchors_preset(PRESET_FULL_RECT)
	zoom.visible = false
	var t := TextureRect.new()
	t.name = "Card"
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.set_anchors_preset(PRESET_CENTER)
	t.offset_left = -190
	t.offset_right = 190
	t.offset_top = -260
	t.offset_bottom = 260
	t.pivot_offset = Vector2(190, 260)
	t.material = cards[0].get_node("Face").material
	t.mouse_filter = MOUSE_FILTER_IGNORE
	zoom.add_child(t)
	zoom.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			zoom.visible = false)
	add_child(zoom)

func _open_zoom(tex: Texture2D) -> void:
	var t: TextureRect = zoom.get_node("Card")
	t.texture = tex
	zoom.visible = true
	Sfx.play("inspect")
	t.scale = Vector2(0.6, 0.6)
	t.rotation = 0.06
	var tw := t.create_tween().set_parallel()
	tw.tween_property(t, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "rotation", 0.0, 0.22)

# ---------------- Transições ----------------
func _intro() -> void:
	fader.create_tween().tween_property(fader, "color:a", 0.0, 0.35)
	var start := maxi(0, ids.find(chosen)) if not random_mode else ids.size() - 1
	board.position = BOARD_POS + Vector2(0, -760)
	board.rotation = 0.14
	Sfx.later("board_in", 0.05)
	var bt := board.create_tween().set_parallel()
	bt.tween_property(board, "position", BOARD_POS, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.tween_property(board, "rotation", BOARD_ROT, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# O anel entra girando e assenta no último personagem escolhido.
	spinning = true
	cur = start - 5.0
	target = start
	var tw := create_tween()
	tw.tween_property(self, "cur", float(start), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	spinning = false
	busy = false
	play_btn.grab_focus()

func _confirm() -> void:
	if busy:
		return
	busy = true
	var n := ids.size()
	var idx := posmod(roundi(target), n)
	random_mode = ids[idx] == RANDOM
	if random_mode:
		# Roleta: duas voltas e meia desacelerando até um personagem sorteado.
		var k := randi() % D.CHARACTER_ORDER.size()
		var base := roundf(target)
		var dest := base + n * 2 + posmod(k - idx, n)
		spinning = true
		Sfx.play("char_flip_dark")
		var tw := create_tween()
		tw.tween_property(self, "cur", dest, 2.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		await tw.finished
		target = dest
		idx = k
	chosen = ids[idx]
	Sfx.play("run_start")
	_reroll = false
	var face: Control = cards[idx].get_node("Face")
	var pt := face.create_tween()
	pt.tween_property(face, "scale", Vector2(1.14, 1.14), 0.12).set_ease(Tween.EASE_OUT)
	pt.tween_property(face, "scale", Vector2(1.07, 1.07), 0.12)
	create_tween().tween_property(self, "others_a", 0.0, 0.25)
	await get_tree().create_timer(0.45).timeout
	_go(GAME_SCENE)

func _back() -> void:
	if busy:
		return
	busy = true
	Sfx.play("board_out")
	_go(MENU_SCENE)

func _go(scene: String) -> void:
	fader.mouse_filter = MOUSE_FILTER_STOP
	var tw := fader.create_tween()
	tw.tween_property(fader, "color:a", 1.0, 0.3)
	tw.tween_callback(func(): get_tree().change_scene_to_file(scene))

func _unhandled_input(ev: InputEvent) -> void:
	if zoom.visible and ev.is_action_pressed("ui_cancel"):
		zoom.visible = false
	elif ev.is_action_pressed("ui_left"):
		_step(-1)
	elif ev.is_action_pressed("ui_right"):
		_step(1)
	elif ev.is_action_pressed("ui_cancel"):
		_back()
	else:
		return
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if zoom.visible:
			zoom.visible = false
		else:
			_back()

# ---------------- Helpers ----------------
func _tex(file: String, pos: Vector2, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(UI + file)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = pos
	t.size = sz
	t.pivot_offset = sz / 2
	t.mouse_filter = MOUSE_FILTER_IGNORE
	return t

func _icon(file: String, sz: Vector2) -> TextureRect:
	var t := _tex(file, Vector2.ZERO, sz)
	t.custom_minimum_size = sz
	return t

func _gap(w: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(w, 1)
	g.mouse_filter = MOUSE_FILTER_IGNORE
	return g

func _scrawl(txt: String, sz: int, c := INK, jitter := 1.0) -> Scrawl:
	return Scrawl.new().setup(txt, font, sz, c, jitter)

# Papel pregado desenhado: cantos e meios das bordas um pouco fora do lugar, sombra e tachinha.
class Note extends Control:
	var pts := PackedVector2Array()

	func setup(sz: Vector2, s: int) -> Note:
		size = sz
		pivot_offset = sz / 2
		mouse_filter = MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		for p in [Vector2.ZERO, Vector2(sz.x * 0.5, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y * 0.5), sz,
				Vector2(sz.x * 0.5, sz.y), Vector2(0, sz.y), Vector2(0, sz.y * 0.5)]:
			pts.append(p + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)))
		var t := Tack.new()
		t.position = Vector2(sz.x * 0.5, 13)
		add_child(t)
		return self

	func _draw() -> void:
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(6, 9))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
		draw_colored_polygon(pts, Color8(233, 218, 223))
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, Color8(150, 136, 140), 3.0)

# Tachinha cinza do quadro do TBOI.
class Tack extends Control:
	func _draw() -> void:
		draw_circle(Vector2(2, 4), 10, Color(0, 0, 0, 0.35))
		draw_circle(Vector2.ZERO, 10, Color8(70, 70, 74))
		draw_circle(Vector2.ZERO, 8, Color8(128, 128, 134))
		draw_circle(Vector2(-3, -3), 3, Color8(205, 205, 210))
