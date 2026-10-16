extends Control
# Menu principal (cena inicial). Visual do menu do TBOI: quadro de papel preso com tachinhas,
# escrita em tinta e seta de cursor, sobre a mesa do porão (mesma mesa/vinheta/brasas da partida).
# Novo Jogo → main.tscn (escolha de personagem) · Opções → volumes e tela cheia (autoload Settings).

const D := preload("res://scripts/data.gd")
const GAME_SCENE := "res://select.tscn"  # Novo Jogo → seleção de personagem
const UI := "res://assets/ui/"
const INK := Color8(55, 43, 44)        # tinta dos sprites do TBOI
const INK_HOT := Color8(140, 32, 44)   # tinta vermelha do item em foco
const INK_SOFT := Color8(110, 88, 90)
const PAPER := Color8(233, 218, 223)
const MAIN_POS := Vector2(16, 330)     # quadro principal (256×228 ×2) na coluna 540×960
const OPT_POS := Vector2(10, 316)      # quadro de opções (258×255 ×2)
const MAIN_ROT := -0.035               # papéis pregados tortos, cada um de um jeito
const OPT_ROT := 0.022

var font: Font                         # Upheaval (pixel, mesma pegada da logo)
var col: Control          # coluna 540×960 centrada: layout de referência do retrato
var logo: TextureRect
var main_board: TextureRect
var opt_board: TextureRect
var first_item: Control
var first_opt: Control
var fs_btn: Button
var fader: ColorRect
var soft_tex: GradientTexture2D
var busy := true

func _ready() -> void:
	Engine.time_scale = 1.0  # hit-stop interrompido na partida não pode vazar para o menu
	# Testes headless pulam direto para a partida.
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--autoplay"):
			get_tree().change_scene_to_file.call_deferred("res://main.tscn")
			return
	font = load("res://assets/fonts/Upheaval.ttf")
	_build_backdrop()
	col = Control.new()
	col.set_anchors_preset(PRESET_CENTER)
	col.offset_left = -270
	col.offset_right = 270
	col.offset_top = -480
	col.offset_bottom = 480
	col.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(col)
	var dd := _tex("doodles.png", Vector2(0, 650), Vector2(540, 306))
	dd.modulate = Color(PAPER, 0.2)
	col.add_child(dd)
	# Logo com sombra dura deslocada (descola a logo do fundo, como nos menus do jogo).
	var lpos := Vector2(30, 28)
	var lsz := Vector2(480, 276)
	logo = _tex("logo.png", lpos, lsz)
	for sh in [[Vector2(12, 18), 0.28], [Vector2(7, 11), 0.8]]:
		var s := _tex("logo.png", sh[0], lsz)
		s.modulate = Color(0.02, 0.0, 0.0, sh[1])
		s.pivot_offset = lsz / 2 - sh[0]
		s.show_behind_parent = true
		logo.add_child(s)
	col.add_child(logo)
	_build_main_board()
	_build_options_board()
	fader = ColorRect.new()
	fader.color = Color.BLACK
	fader.set_anchors_preset(PRESET_FULL_RECT)
	fader.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(fader)
	_intro()

# ---------------- Fundo ----------------
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
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment(){
	float d = distance(UV, vec2(0.5, 0.42));
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.25, 0.8, d) * 0.9);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	vig.material = m
	add_child(vig)
	soft_tex = GradientTexture2D.new()
	soft_tex.fill = GradientTexture2D.FILL_RADIAL
	soft_tex.fill_from = Vector2(0.5, 0.5)
	soft_tex.fill_to = Vector2(1.0, 0.5)
	var sg := Gradient.new()
	sg.set_color(0, Color.WHITE)
	sg.set_color(1, Color(1, 1, 1, 0))
	soft_tex.gradient = sg
	add_child(_embers())

func _embers() -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.amount = 36
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
	var r := Gradient.new()
	r.set_color(0, Color(1, 1, 1, 1))
	r.set_color(1, Color(1, 1, 1, 0))
	e.color_ramp = r
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	e.material = cm
	# Acompanha a largura real da tela (aspecto "expand").
	var fit := func():
		var vs := get_viewport_rect().size
		e.emission_rect_extents = Vector2(vs.x / 2, 10)
		e.position = Vector2(vs.x / 2, vs.y + 10)
	fit.call()
	get_viewport().size_changed.connect(fit)
	return e

# ---------------- Quadros ----------------
func _build_main_board() -> void:
	main_board = _tex("menu_board.png", MAIN_POS, Vector2(512, 456))
	col.add_child(main_board)
	_add_cursor(main_board)
	first_item = _item(main_board, "NOVO JOGO", Vector2(58, 140), -0.03, _start_game, 46)
	_item(main_board, "OPÇÕES", Vector2(86, 244), 0.025, _open_options, 46)
	# Bilhete cor de pêssego (já inclinado no sprite, ~-17°): a regra de vitória, como recado.
	var note := VBoxContainer.new()
	note.alignment = BoxContainer.ALIGNMENT_CENTER
	note.add_theme_constant_override("separation", 2)
	note.size = Vector2(94, 150)
	note.position = Vector2(436, 346) - note.size / 2
	note.pivot_offset = note.size / 2
	note.rotation = -0.29
	note.mouse_filter = MOUSE_FILTER_IGNORE
	for w in [["%d" % D.SOULS_TO_WIN, 44], ["ALMAS", 22], ["P/ VENCER", 14]]:
		var sc := _scrawl(w[0], w[1], INK, 1.4)
		sc.size_flags_horizontal = SIZE_SHRINK_CENTER
		note.add_child(sc)
	main_board.add_child(note)

func _build_options_board() -> void:
	opt_board = _tex("options_board.png", OPT_POS, Vector2(516, 510))
	opt_board.visible = false
	col.add_child(opt_board)
	_add_cursor(opt_board)
	var title := _scrawl("OPÇÕES", 46, INK, 1.3)
	title.position = Vector2(150, 50)
	title.rotation = -0.04
	opt_board.add_child(title)
	var y := 128.0
	var k_i := 0
	for row in [["master", "VOLUME GERAL"], ["music", "MÚSICA"], ["sfx", "EFEITOS"]]:
		var k: String = row[0]
		var dx: float = [0.0, 10.0, 4.0][k_i]  # linhas desalinhadas de propósito
		var l := _scrawl(row[1], 22, INK)
		l.position = Vector2(70 + dx, y)
		l.rotation = [-0.02, 0.015, -0.01][k_i]
		opt_board.add_child(l)
		var s := _slider()
		s.position = Vector2(66 + dx, y + 28)
		s.size = Vector2(300, 36)
		s.rotation = [0.012, -0.015, 0.008][k_i]
		s.value = roundf(Settings.volume[k] * 100.0)
		var pct := _scrawl("%d%%" % int(s.value), 20, INK_SOFT)
		pct.position = Vector2(382 + dx, y + 36)
		s.value_changed.connect(func(v: float):
			Settings.set_volume(k, v / 100.0)
			pct.set_text("%d%%" % int(v)))
		s.focus_entered.connect(_point.bind(l))
		s.mouse_entered.connect(s.grab_focus)
		opt_board.add_child(s)
		opt_board.add_child(pct)
		if first_opt == null:
			first_opt = s
		y += 80.0
		k_i += 1
	if Settings.can_fullscreen():
		fs_btn = _item(opt_board, "", Vector2(70, y + 4), -0.015, func():
			Settings.set_fullscreen(not Settings.fullscreen)
			_fs_text(), 24)
		_fs_text()
		y += 56.0
	_item(opt_board, "VOLTAR", Vector2(96, maxf(y + 6, 410)), 0.03, _close_options)

func _fs_text() -> void:
	fs_btn.get_meta("label").set_text(("[X]" if Settings.fullscreen else "[  ]") + " TELA CHEIA")
	_fit_item(fs_btn)

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

func _scrawl(txt: String, sz: int, c: Color, jitter := 1.0) -> Scrawl:
	return Scrawl.new().setup(txt, font, sz, c, jitter)

# Item de menu escrito à mão: tinta escura; com foco fica vermelho, treme (boil) e ganha a seta do TBOI.
func _item(board: Control, txt: String, pos: Vector2, rot: float, cb: Callable, sz := 40) -> Button:
	var b := Button.new()
	b.flat = true
	b.position = pos
	b.rotation = rot
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var l := _scrawl(txt, sz, INK, 1.2)
	l.position = Vector2(4, 6)
	b.add_child(l)
	b.set_meta("label", l)
	_fit_item(b)
	b.focus_entered.connect(func():
		Sfx.play("ui_focus")
		l.color = INK_HOT
		l.set_boil(true)
		_point(b))
	b.focus_exited.connect(func():
		l.color = INK
		l.set_boil(false))
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(func():
		if busy:
			return
		Sfx.play("ui_confirm")
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.9, 0.9), 0.05)
		tw.tween_property(b, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		cb.call())
	board.add_child(b)
	return b

# Área de toque generosa em volta do texto (mobile).
func _fit_item(b: Button) -> void:
	var l: Scrawl = b.get_meta("label")
	b.size = l.size + Vector2(24, 12)
	b.pivot_offset = Vector2(12, b.size.y / 2)

func _slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	var track := _stroke("stroke_ink.png", Color(1, 1, 1, 0.45))
	var fill := _stroke("stroke_red.png", Color.WHITE)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	s.add_theme_icon_override("grabber", _dot(INK))
	s.add_theme_icon_override("grabber_highlight", _dot(INK_HOT))
	# Tique com tom pela posição (e no volume novo, de quebra serve de prévia do SFX).
	s.value_changed.connect(func(v: float):
		if s.has_focus():
			Sfx.play("ui_slider", 0.7 + v / 100.0 * 0.8))
	return s

# Traço de caneta (recortado do sprite) esticado como trilho do slider.
func _stroke(file: String, tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(UI + file)
	sb.texture_margin_left = 8
	sb.texture_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.modulate_color = tint
	return sb

# Botão do slider: bolota de tinta irregular com miolo de papel (nada de círculo perfeito).
func _dot(c: Color) -> ImageTexture:
	var n := 30
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ctr := Vector2(n - 1, n - 1) / 2.0
	for y in n:
		for x in n:
			var v := Vector2(x, y) - ctr
			var t := v.angle()
			var r := 12.0 + 1.3 * sin(3.0 * t + 1.0) + 0.8 * sin(5.0 * t + 2.5)
			var d := v.length()
			var a := clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(PAPER if d < r - 4.5 else c, a))
	return ImageTexture.create_from_image(img)

func _add_cursor(board: Control) -> void:
	var holder := Control.new()
	holder.name = "Cursor"
	holder.visible = false
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	board.add_child(holder)
	var a := _tex("cursor.png", Vector2.ZERO, Vector2(32, 38))
	holder.add_child(a)
	var tw := a.create_tween().set_loops()
	tw.tween_property(a, "position:x", 6.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(a, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_SINE)

# Seta aponta para o controle focado (botão ou rótulo da linha do slider).
func _point(c: Control) -> void:
	var holder: Control = c.get_parent().get_node("Cursor")
	holder.visible = true
	holder.position = c.position + Vector2(-42, c.size.y / 2 - 19)
	holder.rotation = c.rotation

# ---------------- Transições ----------------
func _intro() -> void:
	fader.create_tween().tween_property(fader, "color:a", 0.0, 0.4)
	logo.modulate.a = 0.0
	logo.scale = Vector2(1.12, 1.12)
	var lt := logo.create_tween().set_parallel()
	lt.tween_property(logo, "modulate:a", 1.0, 0.5)
	lt.tween_property(logo, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.chain().tween_callback(_idle_logo)
	await _drop_in(main_board, MAIN_POS, 0.2)
	busy = false
	first_item.grab_focus()

func _idle_logo() -> void:
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "position:y", logo.position.y + 7, 1.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(logo, "rotation", 0.008, 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "position:y", logo.position.y, 1.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(logo, "rotation", -0.008, 1.8).set_trans(Tween.TRANS_SINE)

# Papel cai do alto e assenta torto, como se tivesse sido pregado agora.
func _drop_in(board: Control, to: Vector2, delay := 0.0) -> void:
	board.visible = true
	Sfx.later("board_in", delay + 0.05)
	board.position = to + Vector2(0, -700)
	board.rotation = 0.14
	var tw := board.create_tween().set_parallel()
	tw.tween_property(board, "position", to, 0.5).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(board, "rotation", MAIN_ROT if board == main_board else OPT_ROT, 0.6).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

func _drop_out(board: Control) -> void:
	Sfx.play("board_out")
	var tw := board.create_tween().set_parallel()
	tw.tween_property(board, "position:y", board.position.y + 760, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(board, "rotation", -0.25, 0.32)
	await tw.finished
	board.visible = false  # fora da tela não pode receber foco por teclado/controle

func _swap(from: Control, to: Control, to_pos: Vector2, focus: Control) -> void:
	busy = true
	focus.release_focus()
	_drop_out(from)
	await _drop_in(to, to_pos, 0.12)
	busy = false
	focus.grab_focus()

func _open_options() -> void:
	_swap(main_board, opt_board, OPT_POS, first_opt)

func _close_options() -> void:
	Settings.save()
	_swap(opt_board, main_board, MAIN_POS, first_item)

func _start_game() -> void:
	busy = true
	Sfx.play("game_start")
	fader.mouse_filter = MOUSE_FILTER_STOP
	var tw := fader.create_tween()
	tw.tween_property(fader, "color:a", 1.0, 0.35)
	tw.tween_callback(func(): get_tree().change_scene_to_file(GAME_SCENE))

# Voltar (Esc / botão "voltar" do Android): fecha as opções; no menu, o Android sai do jogo.
func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel") and not busy and opt_board.visible:
		_close_options()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not busy:
		if opt_board.visible:
			_close_options()
		else:
			get_tree().quit()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Settings.save()

# Texto "rabiscado": cada letra levemente torta e fora da linha, como o lettering à mão do TBOI.
# Com boil, o tremido é sorteado de novo a cada ~0,12 s (line boil de animação desenhada à mão).
class Scrawl extends Control:
	var text := ""
	var font: Font
	var fsize := 32
	var color := Color.BLACK:
		set(v):
			color = v
			queue_redraw()
	var jitter := 1.0
	var boil := false
	var _seed := 0
	var _t := 0.0

	func setup(t: String, f: Font, sz: int, c: Color, j: float) -> Scrawl:
		font = f
		fsize = sz
		color = c
		jitter = j
		mouse_filter = MOUSE_FILTER_IGNORE
		set_process(false)
		set_text(t)
		return self

	func set_text(t: String) -> void:
		text = t
		_seed = hash(t)
		var w := 0.0
		for ch in text:
			w += font.get_char_size(ch.unicode_at(0), fsize).x + 1.0
		custom_minimum_size = Vector2(w, font.get_height(fsize))
		size = custom_minimum_size
		queue_redraw()

	func set_boil(on: bool) -> void:
		boil = on
		set_process(on)
		if not on:
			_seed = hash(text)
			queue_redraw()

	func _process(d: float) -> void:
		_t += d
		if _t > 0.22:
			_t = 0.0
			_seed += 1
			queue_redraw()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed
		var x := 0.0
		var asc := font.get_ascent(fsize)
		for ch in text:
			var w := font.get_char_size(ch.unicode_at(0), fsize).x
			draw_set_transform(Vector2(x + w / 2, asc + rng.randf_range(-0.8, 0.8) * jitter), rng.randf_range(-0.025, 0.025) * jitter)
			draw_string(font, Vector2(-w / 2, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, color)
			x += w + 1.0
		draw_set_transform(Vector2.ZERO)
