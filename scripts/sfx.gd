extends Node
# Autoload "Sfx": todo efeito sonoro passa por aqui (bus "SFX", volume nas Opções).
# Uso: Sfx.play("evento" [, pitch, dB extra]) · Sfx.later("evento", seg) · Sfx.riffle() (embaralhar).
# Anti-repetição: sorteia amostra sem repetir a anterior + pitch aleatório.
# Anti-estouro: cooldown e limite de vozes por evento, pool fixo (rouba a voz mais antiga) e limitador no bus.
# Amostras em assets/sfx/<nome>.wav (vindas de ../tboi sounds/, nome em minúsculas com "_").

const DIR := "res://assets/sfx/"
const VOICES := 16
# evento: [amostras, dB, ± variação de pitch, cooldown (s), vozes máx.]
const EV := {
	# --- UI / menu ---
	"ui_focus": [["menu_scroll"], 4.0, 0.06, 0.04, 2],
	"ui_slider": [["menu_scroll"], 2.0, 0.0, 0.05, 1],
	"ui_confirm": [["book_page_turn"], -9.0, 0.06, 0.08, 1],
	"ui_click": [["button_press"], -5.0, 0.08, 0.05, 2],
	"board_in": [["menu_noteappear"], 0.0, 0.05, 0.1, 1],
	"board_out": [["menu_notehide"], 0.0, 0.05, 0.1, 1],
	"game_start": [["door_heavy_open"], -11.0, 0.04, 0.5, 1],
	# --- seleção de personagem (para a tela de seleção) ---
	"char_left": [["character_select_left"], -12.0, 0.04, 0.03, 2],
	"char_right": [["character_select_right"], -12.0, 0.04, 0.03, 2],
	"char_flip": [["charactermenufliplight"], -8.0, 0.05, 0.1, 1],
	"char_flip_dark": [["charactermenuflipdark"], -15.0, 0.03, 0.3, 1],
	"char_pick": [["charactermenurip"], -3.0, 0.03, 0.3, 1],
	# --- cartas ---
	"card_slide": [["paper_in", "paper_out"], -14.0, 0.15, 0.06, 2],
	"card_tap": [["character_select_left", "character_select_right"], -17.0, 0.1, 0.05, 2],
	"card_play": [["pop_impact_13", "pop_impact_14"], -6.0, 0.1, 0.05, 2],
	"inspect": [["book_page_turn"], -11.0, 0.08, 0.1, 1],
	"shuffle": [["shell_game_0", "shell_game_1"], -17.0, 0.12, 0.035, 3],
	"item_gain": [["power_up1", "power_up_3", "power_up_4", "power_up_7"], -15.0, 0.0, 0.3, 1],
	"trinket": [["pickup_lucky_02"], -10.0, 0.05, 0.2, 1],
	"item_use": [["battery_discharge"], -9.0, 0.08, 0.1, 2],
	"recharge": [["battery_charge"], -11.0, 0.05, 0.3, 1],
	"char_tap": [["cute_grunt", "cute_grunt_2", "cute_grunt_3"], -15.0, 0.06, 0.2, 1],
	"destroy": [["pot_break_01", "pot_break_02"], -17.0, 0.08, 0.15, 1],
	# --- moedas ---
	"coin": [["penny_pickup_1", "nickel_pickup"], -15.0, 0.03, 0.035, 3],
	"coin_lose": [["penny_drop_1", "dime_drop"], -9.0, 0.08, 0.15, 1],
	"buy": [["cash_register"], -7.0, 0.04, 0.2, 1],
	# --- monstros / combate ---
	"mon_reveal": [["enemyappearsmoke01", "enemyappearsmoke02", "enemyappearsmoke03", "enemyappearsmoke04"], -8.0, 0.08, 0.1, 2],
	"event": [["summonsound"], -14.0, 0.05, 0.3, 1],
	"attack": [["whip_01", "whip_02", "whip_03", "whip_04"], -13.0, 0.08, 0.1, 1],
	"swing": [["whip_01", "whip_02", "whip_03", "whip_04"], -10.0, 0.1, 0.08, 1],
	"dice": [["bone_bounce_01", "bone_bounce_02", "bone_bounce_03", "bone_bounce_04"], -9.0, 0.1, 0.05, 2],
	"roll_6": [["thumbs_up"], -19.0, 0.02, 0.2, 1],
	"roll_1": [["thumbs_down"], -19.0, 0.02, 0.2, 1],
	"mon_hit": [["meat_impact", "meat_impacts_2", "meat_impacts_3"], -6.0, 0.1, 0.05, 2],
	"mon_grunt": [["monster_grunt_1a", "monster_grunt_2a", "monster_grunt_4a", "monster_grunt_5"], -17.0, 0.1, 0.25, 1],
	"block": [["tear_block"], -4.0, 0.1, 0.08, 1],
	"mon_kill": [["meaty_deaths_0", "meaty_deaths_1", "meaty_deaths_2", "meaty_deaths_3", "meaty_deaths_4"], -9.0, 0.08, 0.1, 2],
	"splat": [["splatter_0", "splatter_1", "splatter_2"], -4.0, 0.1, 0.08, 2],
	"soul": [["soulpickup1", "soulpickup2", "soulpickup3", "soulpickup4"], -4.0, 0.03, 0.2, 1],
	"bonus_soul": [["holy"], -9.0, 0.02, 0.5, 1],
	# --- jogadores ---
	"hurt": [["punch1", "punch2"], -10.0, 0.08, 0.08, 2],
	"die": [["death_burst_large_0", "death_burst_large_2"], -9.0, 0.04, 0.5, 1],
	"prevent": [["holyshield_shatter_02"], -17.0, 0.06, 0.2, 1],
	"heal": [["heartin"], -11.0, 0.05, 0.3, 1],
	"devil": [["devil_card"], -15.0, 0.0, 1.0, 1],
	# --- turnos / fim ---
	"banner": [["angel_wing1", "angel_wing2", "angel_wing3", "angel_wing4"], -11.0, 0.04, 0.3, 1],
	"victory": [["choir"], -10.0, 0.0, 1.0, 1],
	"defeat": [["death_skull_dying"], -6.0, 0.0, 1.0, 1],
}

var _pool: Array[AudioStreamPlayer] = []
var _ev_of := {}    # player → evento tocando
var _t0 := {}       # player → início (ms)
var _last_t := {}   # evento → último disparo (ms)
var _last_i := {}   # evento → última amostra
var _cache := {}    # nome → AudioStream
var _headless := DisplayServer.get_name() == "headless"

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	var bus := "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	for i in VOICES:
		var a := AudioStreamPlayer.new()
		a.bus = bus
		add_child(a)
		_pool.append(a)
	# Limitador no bus: picos somados (morte + moedas + alma) não estouram.
	var b := AudioServer.get_bus_index(bus)
	var has := false
	for k in AudioServer.get_bus_effect_count(b):
		has = has or AudioServer.get_bus_effect(b, k) is AudioEffectHardLimiter
	if not has:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(b, lim)

# Solta os streams antes do fim (senão o quit acusa "resources still in use").
func _exit_tree() -> void:
	for a in _pool:
		a.stop()
		a.stream = null
	_cache.clear()

func play(ev: String, pitch := 1.0, db := 0.0) -> AudioStreamPlayer:
	var d = EV.get(ev)
	if d == null:
		push_warning("Sfx: evento desconhecido '%s'" % ev)
		return null
	var now := Time.get_ticks_msec()
	if now - int(_last_t.get(ev, -100000)) < int(d[3] * 1000.0):
		return null
	_last_t[ev] = now
	var files: Array = d[0]
	var n := files.size()
	var i := randi() % n
	if n > 1 and i == int(_last_i.get(ev, -1)):
		i = (i + 1 + randi() % (n - 1)) % n
	_last_i[ev] = i
	var a := _voice(ev, int(d[4]))
	a.stream = _stream(files[i])
	a.volume_db = float(d[1]) + db
	a.pitch_scale = maxf(0.1, pitch * (1.0 + randf_range(-d[2], d[2])))
	_ev_of[a] = ev
	_t0[a] = now
	if not _headless:  # autoplay: valida evento e arquivo sem tocar (playbacks vivos no quit viram "leak")
		a.play()
	return a

# Dispara depois de `s` segundos de jogo (acompanha hit-stop e o 10× do autoplay).
func later(ev: String, s: float, pitch := 1.0, db := 0.0) -> void:
	get_tree().create_timer(s).timeout.connect(func(): play(ev, pitch, db))

# Embaralhar: rajada de estalos de carta.
func riffle(n := 6) -> void:
	for k in n:
		later("shuffle", 0.045 * k, 1.0 + k * 0.015)

func _voice(ev: String, cap: int) -> AudioStreamPlayer:
	var mine: Array = []
	var free: AudioStreamPlayer = null
	var oldest: AudioStreamPlayer = _pool[0]
	for a in _pool:
		if not a.playing:
			if free == null:
				free = a
			continue
		if _ev_of.get(a) == ev:
			mine.append(a)
		if int(_t0.get(a, 0)) < int(_t0.get(oldest, 0)):
			oldest = a
	if mine.size() >= cap:
		mine.sort_custom(func(x, y): return int(_t0[x]) < int(_t0[y]))
		return mine[0]
	return free if free != null else oldest

func _stream(name: String) -> AudioStream:
	if not _cache.has(name):
		_cache[name] = load(DIR + name + ".wav")
	return _cache[name]
