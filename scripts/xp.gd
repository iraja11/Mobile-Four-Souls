extends RefCounted
# Cartas das expansões (Four Souls+, Requiem, The Summer of Isaac, Anniversary).
# O main.gd chama estes ganchos nos pontos de regra; aqui fica o efeito de cada carta, por id.
# Partida 1×1: "outro jogador" é sempre o oponente; "jogador à esquerda/direita" também.

const D = preload("res://scripts/data.gd")
const PAPER := Color(0.95, 0.9, 0.8)

var g  # main.gd

var room_slots = 1
var bonus_active: Array = []   # almas bônus em jogo nesta partida (3 sorteadas)
var bonus_ctr = {}            # fichas das almas bônus de contagem (Wrath/Pride/Lust)
var mutant = null              # Mutant Spider: {"chooser": p} até a próxima rolagem
var erawalk = {}              # Era Walk: {"v": resultado, "n": rolagens restantes}
var eternal6 = false          # Eternal D6: 2 e 3 viram 1 até o fim do turno
var jail = -1                 # Get Out of Jail Card: índice do jogador protegido neste turno
var rival = null               # Sibling Rivalry: parceiro do próximo ataque
var goals = {}                # Social Goals: progresso por meta
var keepers_rest = 0          # Keeper's Resting Place resolvidos nesta partida
var adversary = {}            # The Adversary: número escolhido por jogador
var lust_target = null         # Lust for Blood: jogador a ser atacado neste turno

func _init(main) -> void:
	g = main

# =====================================================================
# UTILITÁRIOS
# =====================================================================
func n(p: Dictionary, id: String) -> int:
	return g._n(p, id)

func act() -> Dictionary:
	return g.players[g.active]

func opp(p: Dictionary) -> Dictionary:
	return g._opp(p)

func pos(p: Dictionary) -> Vector3:
	return (p.char_card as Card3D).global_position

func room(id: String) -> bool:
	for r in g.rooms:
		if r.id == id:
			return true
	return false

func mon_in_play(id: String) -> bool:
	for m in g._tops():
		if m.id == id:
			return true
	return false

func ask(p: Dictionary) -> bool:
	return not p.bot and not g.autoplay

func toast(s: String, col := Color(1, 0.93, 0.8)) -> void:
	g._toast(s, col)

func coins(p: Dictionary, k: int) -> void:
	g._gain_coins(p, k, pos(p))

func dmg(p: Dictionary, k: int) -> void:
	g._damage_player(p, k, null)

func loot(p: Dictionary, k: int) -> void:
	await g._draw_loot(p, k)

func treasure(p: Dictionary, k := 1) -> void:
	await g._gain_treasure(p, k)

func roll(p: Dictionary, name: String, cb: Callable) -> void:
	await g._roll(p, name, cb)

func choose(p: Dictionary, title: String, opts: Array, bot_pick := 0, card_id := "") -> int:
	if not ask(p):
		return bot_pick
	return await g._choose_option(title, opts, 0, false, card_id)

func yes(p: Dictionary, title: String, bot_yes := true, card_id := "") -> bool:
	return (await choose(p, title, ["SIM", "NÃO"], 0 if bot_yes else 1, card_id)) == 0

func souls_max() -> int:
	var mx = 0
	for q in g.players:
		mx = max(mx, q.soul_n)
	return mx

func souls_min() -> int:
	var mn = 999
	for q in g.players:
		mn = min(mn, q.soul_n)
	return mn

func fewest_souls(p: Dictionary) -> bool:
	return p.soul_n == souls_min()

func most_items(p: Dictionary) -> bool:
	for q in g.players:
		if q.items.size() > p.items.size():
			return false
	return true

func counters(it) -> int:
	return int(it.counters) if it != null else 0

func item(p: Dictionary, id: String):
	return g._item_of(p, id)

func in_fight(m: Dictionary) -> bool:
	return g.in_combat and g.combat.get("uid", -1) == m.uid

func free_mons() -> Array:
	return g._tops().filter(func(m): return not in_fight(m))

# Remove um monstro do espaço sem matá-lo. `to`: discard | bottom | none.
func remove_mon(m: Dictionary, to := "discard") -> void:
	var s: int = m.slot
	if s < 0 or s >= g.slots.size() or not g.slots[s].has(m):
		return
	g.slots[s].erase(m)
	if m.get("label") != null and is_instance_valid(m.label):
		(m.label as Label3D).queue_free()
	match to:
		"discard":
			g.monster_discard.append(m.id)
		"bottom":
			g.monster_ids.push_front(m.id)
			g.decks.monster.set_count(g.monster_ids.size())
	g._discard_card(m.card, false)
	if in_fight(m):
		g.in_combat = false
		if g.awaiting_roll:
			g.roll_requested.emit()
	g._ui()

# Coloca uma carta (id) do deck/descarte num espaço, cobrindo o que houver (passa por _reveal_into).
func place_mon(id: String, s := -1) -> void:
	if s < 0:
		s = free_slot()
	g.monster_ids.push_back(id)
	g.decks.monster.set_count(g.monster_ids.size())
	await g._reveal_into(s)

func free_slot() -> int:
	for i in g.slots.size():
		if g.slots[i].is_empty():
			return i
	for i in g.slots.size():
		var m = g._top(i)
		if m == null or not in_fight(m):
			return i
	return 0

# Alvo "monstro ou jogador" escolhido por p (humano escolhe; CPU mira o que mata, senão o oponente).
func pick_any(p: Dictionary, k := 1, title := "Escolha o alvo"):
	if not p.bot:
		return await g._choose_target(title)
	var o: Dictionary = opp(p)
	for m in g._tops():
		if m.hp <= k:
			return {"type": "monster", "m": m, "card": m.card}
	if not o.dead and o.hp <= k and n(o, "themonster") == 0:
		return {"type": "player", "p": o, "card": o.char_card}
	var ms: Array = g._tops()
	if not ms.is_empty() and randf() < 0.6:
		var m = ms[0]
		for x in ms:
			if x.hp < m.hp:
				m = x
		return {"type": "monster", "m": m, "card": m.card}
	if not o.dead:
		return {"type": "player", "p": o, "card": o.char_card}
	return null

func deal_any(p: Dictionary, k := 1, title := "Escolha o alvo do dano") -> void:
	var t = await pick_any(p, k, title)
	if t != null:
		g._deal_to_target(t, k, p)

func pick_mon(p: Dictionary, title: String, hostile := true, filt := Callable()):
	var ms: Array = g._tops().filter(func(m): return not filt.is_valid() or filt.call(m))
	if ms.is_empty():
		return null
	if not p.bot:
		var t = await g._choose_target(title, "monster", filt)
		return t.get("m") if t != null else null
	var best = ms[0]
	for m in ms:
		if hostile and m.hp < best.hp:
			best = m
		elif not hostile and m.hp > best.hp:
			best = m
	return best

func deal_mon(p: Dictionary, k := 1) -> void:
	var m = await pick_mon(p, "Escolha o monstro")
	if m != null:
		g._damage_monster(m, k, p)

func pick_deck(p: Dictionary, title: String, with_room := false, bot_deck := "monster") -> String:
	var keys = ["loot", "monster", "treasure"]
	var labels = ["LOOT", "MONSTROS", "TESOUROS"]
	if with_room:
		keys.append("room")
		labels.append("SALAS")
	if not ask(p):
		return bot_deck
	return keys[await g._choose_option(title, labels, 0)]

func deck_arr(k: String) -> Array:
	match k:
		"loot": return g.loot_ids
		"monster": return g.monster_ids
		"treasure": return g.treasure_ids
		"room": return g.room_ids
	return []

func sync_decks() -> void:
	g.decks.loot.set_count(g.loot_ids.size())
	g.decks.monster.set_count(g.monster_ids.size())
	g.decks.treasure.set_count(g.treasure_ids.size())
	g.decks.room.set_count(g.room_ids.size())
	g.decks.discard.set_count(g.loot_discard.size())

# Descarte escolhido pelo próprio jogador (humano escolhe a carta; CPU descarta a pior).
func discard_choice(p: Dictionary, k := 1, title := "Descarte uma carta de loot") -> void:
	for i in k:
		if p.hand.is_empty():
			return
		var c: Card3D = p.hand[0]
		if ask(p):
			var ids: Array = []
			for h in p.hand:
				if not ids.has(h.id):
					ids.append(h.id)
			var pick: String = await g._choose_card(ids, title)
			for h in p.hand:
				if h.id == pick:
					c = h
					break
		else:
			for h in p.hand:
				if h.id in ["penny", "twocents"]:
					c = h
					break
		p.hand.erase(c)
		if c == g.selected_card:
			g.selected_card = null
		g._discard_card(c, true)
	g._layout_hand(p)
	g._ui()

# Põe uma carta da mão no topo do deck de loot.
func hand_to_top(p: Dictionary, k := 1) -> void:
	for i in k:
		if p.hand.is_empty():
			return
		var c: Card3D = p.hand.pick_random()
		if ask(p):
			var ids: Array = []
			for h in p.hand:
				if not ids.has(h.id):
					ids.append(h.id)
			var pick: String = await g._choose_card(ids, "Coloque uma carta no topo do deck de loot")
			for h in p.hand:
				if h.id == pick:
					c = h
					break
		p.hand.erase(c)
		g.loot_ids.push_back(c.id)
		c.queue_free()
		g.decks.loot.set_count(g.loot_ids.size())
	g._layout_hand(p)

func discard_hand(p: Dictionary) -> void:
	g._force_discard(p, p.hand.size(), true)

func give_item(it: Dictionary, to: Dictionary) -> void:
	if is_same(it.owner, to) or not is_instance_valid(it.card) or not it.owner.items.has(it):
		return  # já saiu de jogo (ex.: Magic Skin destruída pelo próprio gatilho)
	g._transfer_item(it, to)
	toast("%s vai para %s" % [D.ITEMS[it.id][0], to.name])
	on_item_enter(to, it, true)

func destroy_soul(p: Dictionary) -> void:
	if p.soul_n <= 0:
		return
	p.soul_n -= 1
	if not p.souls.is_empty():
		g._discard_card(p.souls.pop_back(), false)
	toast("%s perdeu uma alma" % p.name)
	g._ui()

func steal_soul(p: Dictionary, from: Dictionary) -> void:
	if from.soul_n <= 0 or not can_gain_soul(p):
		return
	from.soul_n -= 1
	p.soul_n += 1
	if not from.souls.is_empty():
		var sc: Card3D = from.souls.pop_back()
		sc.ref = p
		p.souls.append(sc)
		sc.fly_to(g._soul_xf(p, p.souls.size() - 1), 0.6, 0.4)
	toast("%s roubou uma alma!" % p.name)
	on_soul_gained(p, "")
	g._check_bonus_souls()

func gain_soul(p: Dictionary, why: String) -> void:
	if not can_gain_soul(p):
		toast("%s não pode ganhar almas" % p.name)
		return
	p.soul_n += 1
	g._float3d("+1 ALMA", pos(p), Color(0.75, 0.9, 1), true)
	Sfx.play("soul")
	toast("%s ganhou %s" % [p.name, why])
	on_soul_gained(p, "")
	g._check_bonus_souls()

func can_gain_soul(p: Dictionary) -> bool:
	return not room("allhallowseve") and not (p.curses as Array).has("curseofthesoulless")

# Rerrola (destrói e repõe) um item escolhido.
func reroll_one(p: Dictionary, own_only: bool, title: String) -> void:
	var x = await g._choose_item(p, func(i): return not g._is_eternal(i) and (not own_only or is_same(i.owner, p)), title, not own_only)
	if x != null:
		await g._reroll_item(x)

func reroll_all(q: Dictionary) -> void:
	for x in q.items.duplicate():
		if not g._is_eternal(x):
			await g._reroll_item(x)

func shop_to_discard(p: Dictionary, refill := true) -> void:
	var opts: Array = []
	for s in g.shop.size():
		if g.shop[s] != null:
			opts.append(s)
	if opts.is_empty():
		return
	var s: int = opts.pick_random()
	if ask(p):
		var ids: Array = []
		for k in opts:
			ids.append(g.shop[k].id)
		var pick: String = await g._choose_card(ids, "Coloque um item da loja no descarte")
		for k in opts:
			if g.shop[k].id == pick:
				s = k
	var sc: Card3D = g.shop[s]
	g.treasure_discard.append(sc.id)
	sc.queue_free()
	g.shop[s] = null
	if refill and shop_refills():
		g._shop_fill(s)

func steal_from_shop(p: Dictionary) -> void:
	for s in g.shop.size():
		if g.shop[s] != null:
			var sc: Card3D = g.shop[s]
			g.shop[s] = null
			g._gain_item(p, sc.id, sc.transform)
			sc.queue_free()
			if shop_refills():
				g._shop_fill(s)
			return

func all_items() -> Array:
	var out = []
	for q in g.players:
		out.append_array(q.items)
	return out

func hand_names(q: Dictionary) -> String:
	var names = []
	for c in q.hand:
		names.append(D.LOOT[c.id][0])
	return ", ".join(names) if not names.is_empty() else "(vazia)"

# =====================================================================
# PREPARAÇÃO
# =====================================================================
func setup() -> void:
	g.room_ids = D.ROOMS.keys()
	g.room_ids.shuffle()
	room_slots = 1
	# Requiem: 3 almas bônus sorteadas entre as 8.
	var all: Array = ["soulofguppy", "soulofgreed", "soulofgluttony"] + D.BONUS_SOULS.keys().filter(func(k): return not k in ["soulofguppy", "soulofgreed", "soulofgluttony"])
	all.shuffle()
	bonus_active = all.slice(0, 3)
	for k in ["soulofguppy", "soulofgreed", "soulofgluttony"]:
		if not bonus_active.has(k):
			g.bonus_souls_taken[k] = -1  # fora desta partida
	var names = []
	for k in bonus_active:
		names.append(D.BONUS_SOULS[k][0])
	toast("Almas bônus: " + ", ".join(names))

func on_game_start(p: Dictionary) -> void:
	if p.char == "leveloneisaac":
		await g._draw_loot(p, 2, true)

# =====================================================================
# MODIFICADORES ESTÁTICOS
# =====================================================================
func item_ctr(p: Dictionary, key: String) -> int:
	var k = 0
	for it in p.items:
		k += int(it.get(key, 0))
	return k

func atk_mod(p: Dictionary) -> int:
	var a = 2 * n(p, "polyphemus") + 3 * n(p, "abaddon") + n(p, "foundsoul")
	a += item_ctr(p, "atc") + int(p.state.get("atc", 0)) + int(p.state.get("mm_atk", 0))
	if room("samsonsblessing"):
		a += 1
	if room("mightforthemeek") and fewest_souls(p):
		a += 1
	if p.char == "thebaleful":
		a += 2 if p.soul_n >= 3 else (1 if p.soul_n >= 1 else 0)
	var ab = item(p, "abyss")
	if ab != null:
		a += counters(ab) / 2
	var cm = item(p, "chocolatemilk")
	if cm != null and counters(cm) == 2:
		a += 1
	var bp = item(p, "bloodpuppy")
	if bp != null and counters(bp) >= 4:
		a += 1
	return a

func hp_mod(p: Dictionary) -> int:
	var h = 2 * n(p, "lard") + 2 * n(p, "punchingbag") + n(p, "lunch") + item_ctr(p, "hpc")
	if room("maggysblessing"):
		h += 1
	h += counters(item(p, "hypercoagulation"))
	var bl = item(p, "baglunch")
	if bl != null and counters(bl) > 0:
		h += 1
	return h

func roll_mod(_p: Dictionary, _is_attack: bool, _first: bool) -> int:
	return 0

func loot_step_mod(p: Dictionary) -> int:
	return 1 if room("blessingofgluttony") and p.i == g.active else 0

func price_off(p: Dictionary) -> int:
	var k = n(p, "trickpenny") + 3 * n(p, "keepersbargain") + 4 * n(p, "membercard") + n(p, "recyclingsticker")
	if p.i == g.active:
		if room("blessingofsteam"):
			k += 5
		if mon_in_play("holygreed"):
			k += 3
		for r in g.rooms:
			if r.id == "everythingmustgo":
				k += 2 * int(r.counters)
	return k

func paid_discount(p: Dictionary) -> int:
	return n(p, "trickpenny")

func free_purchase(p: Dictionary) -> bool:
	return room("pityforthepoor") and fewest_souls(p) and p.i == g.active

func eva_mod(m: Dictionary) -> int:
	var ap: Dictionary = act()
	var e = n(ap, "polyphemus") + n(ap, "thewiz")
	if room("whitechampions"):
		e += 1
	if n(ap, "handicappedplacard") > 0:
		e -= (souls_max() - ap.soul_n) * n(ap, "handicappedplacard")
	return e

func mon_atk_mod(m: Dictionary) -> int:
	var ap: Dictionary = act()
	var a = int(m.get("atc", 0))
	if (ap.curses as Array).has("curseofthehunted"):
		a += 1
	if room("blackchampions"):
		a += 1
	if m.id == "therainmaker_2":
		a += (ap.curses as Array).size()
	return a

func extra_attacks(p: Dictionary) -> int:
	var k = n(p, "berserk")
	if room("mightforthemeek") and fewest_souls(p):
		k += 1
	return k

func extra_loot_plays(_p: Dictionary) -> int:
	return 0

func hand_limit(p: Dictionary) -> int:
	return 0 if bool(p.state.get("hand0", false)) else D.HAND_LIMIT

func eternal_now(it: Dictionary) -> bool:
	if bool(it.get("eternal_ctr", false)):
		return true
	var o = it.get("owner")
	return o != null and bool(o.state.get("algiz", false))

func indomitable(id: String) -> bool:
	return id in ["megasatan", "theharbingers", "holygreed", "shopkeeper"]

func shop_refills() -> bool:
	for r in g.rooms:
		if r.id == "everythingmustgo" and int(r.counters) > 0:
			return false
	return true

func blocked(actor: Dictionary) -> bool:
	return jail >= 0 and jail != actor.i

func may_play_loot(p: Dictionary) -> bool:
	if room("shadowoffamine") and int(p.state.get("loot_n", 0)) >= 1:
		toast("Shadow of Famine: só 1 loot por turno")
		return false
	return true

# ↷ custa 3¢ com Greed Mode; Shadow of Famine limita a 1 habilidade por turno.
func pay_tap(p: Dictionary) -> bool:
	if room("shadowoffamine") and int(p.state.get("abil_n", 0)) >= 1:
		toast("Shadow of Famine: só 1 habilidade por turno")
		return false
	if room("greedmode"):
		if p.coins < 3:
			toast("Greed Mode: ↷ custa 3¢")
			return false
		g._lose_coins(p, 3, true)
	p.state["abil_n"] = int(p.state.get("abil_n", 0)) + 1
	return true

func counter_note(it: Dictionary) -> String:
	var parts = []
	if int(it.get("counters", 0)) > 0:
		parts.append("Fichas: %d" % int(it.counters))
	if int(it.get("hpc", 0)) > 0:
		parts.append("Fichas de HP: %d" % int(it.hpc))
	if int(it.get("atc", 0)) > 0:
		parts.append("Fichas de AT: %d" % int(it.atc))
	if bool(it.get("gold", false)):
		parts.append("Ficha dourada")
	if bool(it.get("eternal_ctr", false)):
		parts.append("Ficha de eterno")
	if it.has("under") and not (it.under as Array).is_empty():
		var names = []
		for x in it.under:
			names.append(g._card_disp_name(x))
		parts.append("Embaixo: " + ", ".join(names))
	if it.has("proto"):
		parts.append("Escolhido: " + " ".join(it.proto_txt))
	return ("\n" + " · ".join(parts)) if not parts.is_empty() else ""

func char_text(p: Dictionary, txt: String) -> String:
	var t: String = str(D.CHARACTERS[p.char].get("text", ""))
	if t != "":
		txt = t + "\n" + txt
	if int(p.state.get("spider", 0)) > 0:
		txt += "\nFichas de aranha: %d (↷ remove uma)" % int(p.state.spider)
	if int(p.state.get("atc", 0)) > 0:
		txt += "\nFichas de AT: %d" % int(p.state.atc)
	# Guppy's Eye: os outros jogam com a mão revelada.
	if p.i != 0 and n(g.players[0], "guppyseye") > 0:
		txt += "\nMão: " + hand_names(p)
	if not (p.curses as Array).is_empty():
		txt += "\nMaldições: " + ", ".join((p.curses as Array).map(func(c): return D.EVENTS[c][0]))
	return txt

# =====================================================================
# ECONOMIA: moedas, loot, tesouros
# =====================================================================
func coin_amount(p: Dictionary, k: int) -> int:
	if n(p, "pokerchip") > 0 and p.i == g.active and not bool(p.state.get("pokerchip", false)):
		p.state["pokerchip"] = true
		var v = randi_range(1, 6)
		k = 1 if v <= 3 else k * 2
		toast("Poker Chip (%d): %d¢" % [v, k])
	if room("equality"):
		for q in g.players:
			if not is_same(q, p):
				g._gain_coins(q, k, pos(q), true)
	return k

func after_coins(p: Dictionary, amt: int) -> void:
	for q in g.players:
		if not is_same(q, p) and n(q, "magnet") > 0 and p.coins > 0:
			p.coins -= 1
			q.coins += 1
			toast("Magnet: %s entrega 1¢" % p.name)
	if amt >= 3:
		var bm = item(p, "blastminertnt")
		if bm != null and bm.tapped:
			bm.tapped = false
			g._layout_items(p)

func loot_amount(p: Dictionary, k: int, step: bool) -> int:
	if not step:
		k += n(p, "luckytoe")
	k += n(p, "bagoholes")
	return k

func after_loot(p: Dictionary, _k: int) -> void:
	if room("lasereye"):
		dmg(p, 1)

func treasure_amount(p: Dictionary, k: int) -> int:
	return k + n(p, "damocles") if k > 0 else k

func on_treasure(_p: Dictionary) -> void:
	bonus_tick("soulofpride")

# =====================================================================
# ITENS: entrar em jogo, destruir, comprar
# =====================================================================
func on_item_enter(p: Dictionary, it: Dictionary, transfer := false) -> void:
	match it.id:
		"hotpotato":
			_hot_potato(p, it)
			return
		"charmedvis":
			make_xtarget(it, "item")
	if transfer:
		return
	match it.id:
		"keeperspenny": coins(p, 9)
		"keeperssack": coins(p, 14)
		"keepersbox": g._expand_shop_slots(2); _fill_shop()
		"magicmushroom": it.counters = 3
		"rkey": it.tapped = true
		"rockbottom": it.counters = p.hand.size()
		"bobbybomb": _reveal_named(p, "bomb")
		"momsbottleofpills": _reveal_named(p, "pills")
		"punchingbag", "coopbaby": make_xtarget(it, "item")
		"goldentrinket": _golden_trinket(p, it)
		"prototype": _prototype(p, it)
		"forgetmenow", "divorcepapers": pass
	g._check_bonus_souls()

func _fill_shop() -> void:
	for s in g.shop.size():
		g._shop_fill(s)

func _reveal_named(p: Dictionary, key: String) -> void:
	var top: Array = []
	for i in min(10, g.loot_ids.size()):
		top.append(g.loot_ids.pop_back())
	var got = 0
	for id in top:
		var nm: String = D.LOOT[id][0].to_lower()
		if (key == "bomb" and nm.contains("bomb")) or (key == "pills" and nm == "pills!"):
			g._loot_to_hand(p, id)
			got += 1
		else:
			g.loot_ids.push_front(id)
	sync_decks()
	toast("%s: %d carta(s) para a mão" % [p.name, got])

func _golden_trinket(p: Dictionary, it: Dictionary) -> void:
	var x = await g._choose_item(p, func(i): return is_same(i.owner, p) and i != it and not g._is_eternal(i), "Golden Trinket — ficha dourada em qual item?")
	if x != null:
		x.gold = true
		toast("Ficha dourada em %s" % D.ITEMS[x.id][0])

func _prototype(p: Dictionary, it: Dictionary) -> void:
	var t = ["No início do seu turno", "Quando alguém rolar 3", "↷ + 3¢"]
	var e = ["Loot 2", "+1 HP até o fim do turno", "Ganhe 6¢", "Tome 1 de dano"]
	var x = ["Dê este item ao outro jogador", "Tome 1 de dano", "Descarte 1 loot"]
	var a: int = await choose(p, "Prototype — quando?", t, randi() % 3)
	var b: int = await choose(p, "Prototype — efeito", e, [0, 2].pick_random())
	var c: int = await choose(p, "Prototype — depois", x, 2)
	it.proto = [a, b, c]
	it.proto_txt = [t[a], e[b], x[c]]

func _proto_fire(p: Dictionary, it: Dictionary) -> void:
	match int(it.proto[1]):
		0: await loot(p, 2)
		1: p.temp_hp += 1; p.hp += 1
		2: coins(p, 6)
		3: dmg(p, 1)
	match int(it.proto[2]):
		0: give_item(it, opp(p))
		1: dmg(p, 1)
		2: g._force_discard(p, 1, true)

func _hot_potato(p: Dictionary, it: Dictionary) -> void:
	coins(p, 2)
	await roll(p, "Hot Potato!", _r_hot_potato.bind(p, it))

func _r_hot_potato(v: int, p: Dictionary, it: Dictionary) -> void:
	if not p.items.has(it):
		return
	if v <= 4:
		give_item(it, opp(p))
	elif v == 5:
		p.items.erase(it)
		g._discard_item(it)
		g._layout_items(p)
		dmg(p, 3)
	else:
		g._item_to_soul(p, it)

# true = destruição evitada.
func on_destroy(p: Dictionary, it: Dictionary) -> bool:
	match it.id:
		"baglunch":
			if counters(it) == 0:
				it.counters = 1
				toast("Bag Lunch ganha uma ficha em vez de ser destruído")
				return true
		"wishbone":
			treasure(p, 1)
		"judasshadow":
			var x = counters(it)
			coins(p, x)
			loot(p, x)
	forget_xtarget(it)
	return false

func on_purchase(p: Dictionary, _id: String, paid: int) -> void:
	if n(p, "trickpenny") > 0:
		coins(p, n(p, "trickpenny"))
	for q in g.players:
		if not is_same(q, p) and n(q, "keepersbox") > 0:
			coins(q, 2)
			await loot(q, 1)
	for m in g._tops():
		if m.id == "holygreed":
			m.counters = int(m.counters) + paid
	goal_add(p, "buy", 1)

# =====================================================================
# ALMAS
# =====================================================================
# Quem recebe a alma de um monstro morto (null = ninguém; a carta vai ao descarte).
func soul_taker(m: Dictionary, by: Dictionary):
	if m.id == "charmedmonstro" and by.i == g.active:
		by = opp(by)
	return by if can_gain_soul(by) else null

func reward_taker(m: Dictionary, by: Dictionary) -> Dictionary:
	if by.i == g.active or m.id in ["giantpoop", "ultragreed"] or room("multiplayerupdate"):
		return by
	if g.in_combat and in_fight(m):
		return act()  # em equipe, a recompensa é do jogador ativo
	return by

func reward_mult(m: Dictionary, by: Dictionary) -> int:
	var k = 1
	if bool(by.state.get("x2rewards", false)):
		k *= 2
	if room("blessingofthesack"):
		k *= 2
	if by.i == g.active and n(by, "club") > 0 and not bool(by.state.get("club_off", false)) and int(g._mdata(m.id)[7]) == 0:
		k *= 2
	return k

func on_soul_gained(p: Dictionary, src_id: String) -> void:
	if room("haunted"):
		p.state["skip_next"] = true
		toast("Haunted! %s pula o próximo turno" % p.name)
	for q in g.players:
		if is_same(q, p):
			var fs = item(q, "foundsoul")
			if fs != null:
				give_item(fs, opp(q))
			continue
		var af = item(q, "afriend")
		if af != null:
			af.counters = int(af.counters) + 1
			if int(af.counters) >= 3:
				g._item_to_soul(q, af)
				toast("A Friend virou uma alma!")
		if n(q, "karma") > 0:
			for k in g.players:
				steal_from_shop(k)
				loot(k, 1)
	if src_id == "momsheart":
		# Quem tiver mais almas (ou empatado) vence; o escolhido é quem ganhou a alma se empatar.
		var mx = souls_max()
		var w: Dictionary = p if p.soul_n == mx else opp(p)
		toast("Mom's Heart! %s vence" % w.name)
		g._game_end(w)
	if src_id == "cursedhaunt":
		for c in p.souls:
			if c.id == "cursedhaunt":
				make_xtarget(c, "soul")
	g._check_bonus_souls()

func check_bonus_souls() -> void:
	for q in g.players:
		if bonus_active.has("soulofenvy") and not g.bonus_souls_taken.has("soulofenvy") and q.soul_n >= 3:
			var mn = souls_min()
			var to: Dictionary = q
			for k in g.players:
				if k.soul_n == mn:
					to = k
			_take_bonus("soulofenvy", to)
		if bonus_active.has("soulofsloth") and not g.bonus_souls_taken.has("soulofsloth") and q.items.size() >= 4:
			var to2: Dictionary = q
			for k in g.players:
				if k.items.size() < to2.items.size():
					to2 = k
			_take_bonus("soulofsloth", to2)

func bonus_tick(id: String) -> void:
	if not bonus_active.has(id) or g.bonus_souls_taken.has(id) or g.players.is_empty():
		return
	bonus_ctr[id] = int(bonus_ctr.get(id, 0)) + 1
	if int(bonus_ctr[id]) >= 6:
		_take_bonus(id, act())

func _take_bonus(id: String, q: Dictionary) -> void:
	g.bonus_souls_taken[id] = q.i
	if not can_gain_soul(q):
		return
	q.soul_n += 1
	Sfx.play("bonus_soul")
	toast("%s ganhou a %s!" % [q.name, D.BONUS_SOULS[id][0]])
	if q.soul_n >= D.SOULS_TO_WIN and not g.game_over:
		g._game_end(q)

# =====================================================================
# DANO
# =====================================================================
func on_dealt_damage(by, k: int) -> void:
	if by is Dictionary and by.has("coins") and k > 0 and n(by, "headofthekeeper") > 0:
		coins(by, n(by, "headofthekeeper"))

func pre_player_damage(p: Dictionary, k: int, _src) -> int:
	if n(p, "gnawedleaf") > 0 and p.i != g.active:
		return 0
	if n(p, "callus") > 0 and not g.combat_damage:
		return 0
	return k

func on_player_damaged(p: Dictionary, k: int) -> void:
	var sm = item(p, "sumptorium")
	if sm != null:
		sm.counters = int(sm.counters) + 1
	if n(p, "abaddon") > 0:
		toast("Abaddon: %s morre!" % p.name, Color(1, 0.4, 0.35))
		await g._kill_player(p)
		return
	for i in n(p, "lard"):
		g._force_discard(p, 1)
	var sf = item(p, "smartfly")
	if sf != null and sf.tapped:
		sf.tapped = false
		g._layout_items(p)
	if n(p, "gimpy") > 0:
		var c: int = await choose(p, "Gimpy — escolha um", ["Ganhe 2¢", "Loot 1 e descarte 1", "+2 AT até o fim do turno"], 2 if p.i == g.active else 0)
		match c:
			0: coins(p, 2)
			1: await loot(p, 1); await discard_choice(p, 1)
			2: p.temp_atk += 2
	# Charmed Vis: quem ataca (ou controla) o Vis toma dano → o Vis fere os outros monstros.
	var vis = false
	if g.in_combat and is_same(g.combat.get("p", null), p):
		var t = g._find_mon(g.combat.uid)
		vis = t != null and t.id == "charmedvis"
	if vis or n(p, "charmedvis") > 0:
		for m in g._tops():
			if m.id != "charmedvis":
				g._damage_monster(m, 1, p)

func mon_dealt_damage(m: Dictionary, p: Dictionary, k: int) -> void:
	match m.id:
		"roundy":
			for o in g._tops():
				if o != m:
					g._damage_monster(o, 1, p)
		"mushroom":
			if is_same(p, g.combat.get("p", null)):
				for q in g.players:
					if not is_same(q, p):
						dmg(q, 1)
		"monstroii":
			dmg(opp(act()), 1)

func pre_mon_damage(m: Dictionary, k: int, by: Dictionary) -> int:
	match m.id:
		"hush":
			k -= 1
		"conjoinedfatty_2":
			if int(m.counters) > 0:
				m.counters = int(m.counters) - 1
				g._float3d("Prevenido", (m.card as Card3D).global_position, Color(0.6, 0.85, 1))
				loot(act(), 1)
				return 0
		"thescourge":
			# 1×1: o ativo vota "whiff", o outro "whip" → empate → o ativo loota 1 e o dano passa.
			loot(act(), 1)
	return k

func on_mon_damaged(m: Dictionary, k: int, by: Dictionary) -> void:
	var ap: Dictionary = act()
	if by is Dictionary and by.has("coins") and room("splashdamage"):
		dmg(opp(by), 1)
	match m.id:
		"tumor", "curseddople":
			for q in g.players:
				if q.i != g.active:
					dmg(q, 1)
		"dingle":
			if is_same(by, ap):
				await roll(ap, "Dingle", _r_dingle.bind(m))
		"isaacboss":
			dmg(opp(ap), 1)
		"redghost":
			dmg(opp(ap), 1)
		"babyplum":
			await roll(ap, "Baby Plum", func(v: int) -> void: dmg(ap if v <= 2 else opp(ap), 1))
		"brownie":
			m.temp_eva = int(m.temp_eva) - 1
		"mother":
			m.temp_eva = int(m.temp_eva) + 1
		"lightswitch":
			if is_same(by, ap):
				await roll(ap, "Light Switch", _r_lightswitch.bind(ap))
		"giantpoop":
			if by is Dictionary and by.has("coins"):
				loot(by, 1)
		"cereuspeashy":
			dmg(ap, 1)
		"mulligoon":
			_mulligoon(m)
		"globin":
			if m.hp == 1 and not bool(m.get("reached1", false)):
				m.reached1 = true
				await roll(ap, "Globin", func(v: int) -> void:
					if v <= 4: g._damage_monster(m, 1, ap)
					else: m.hp = min(m.max, m.hp + 2))
		"gemini_2":
			if m.hp == 1 and not bool(m.get("reached1", false)):
				m.reached1 = true
				var ms: Array = g._tops()
				if not ms.is_empty():
					var a = ms.pick_random()
					a.hpc = int(a.hpc) + 1
					a.max += 1
					a.hp += 1
					var b = ms.pick_random()
					b.atc = int(b.atc) + 1
					toast("Gemini: fichas de HP e AT")
	g._ui()

func _r_dingle(v: int, m: Dictionary) -> void:
	var ap: Dictionary = act()
	if v <= 2:
		dmg(ap, 1)
	elif v <= 4:
		for q in g.players:
			dmg(q, 1)
	else:
		g._damage_monster(m, 1, ap)

func _r_lightswitch(v: int, p: Dictionary) -> void:
	match v:
		1: dmg(p, 3)
		2: dmg(p, 2)
		3: coins(p, 1)
		4: await loot(p, 1)
		5: coins(p, 5)
		6: await treasure(p, 1)

func _mulligoon(m: Dictionary) -> void:
	if in_fight(m):
		g.in_combat = false
		if g.awaiting_roll:
			g.roll_requested.emit()
		toast("Mulligoon cancela o ataque e muda de espaço")
	loot(act(), 1)
	if g.slots.size() < 2 or m.hp <= 0:
		return
	var to: int = (m.slot + 1) % g.slots.size()
	g.slots[m.slot].erase(m)
	m.slot = to
	g.slots[to].append(m)
	(m.card as Card3D).fly_to(g._slot_xf(to, g.slots[to].size() - 1), 0.4, 0.1)
	await g._refill_slots()

# Evita a morte de um monstro (true = continua em jogo).
func prevent_mon_death(m: Dictionary, by: Dictionary) -> bool:
	match m.id:
		"headlesshorseman":
			if not bool(m.get("horse", false)):
				m.horse = true
				m.hp = min(m.max, 2)
				m.temp_eva = int(m.temp_eva) + 1
				m.temp_atk = int(m.temp_atk) - 1
				toast("Headless Horseman se recusa a morrer!")
				return true
		"headlesshorseman_2":
			if int(m.get("kill_roll", 0)) != 6 or not in_fight(m):
				m.hp = m.max
				m.temp_eva = int(m.temp_eva) + 1
				m.temp_atk = int(m.temp_atk) + 1
				toast("Headless Horseman volta! (recompensa dada)")
				treasure(act(), 1)
				return true
		"theharbingers":
			m.counters = int(m.counters) + 1
			treasure(act(), 1)
			if in_fight(m):
				g.in_combat = false
				if g.awaiting_roll:
					g.roll_requested.emit()
			m.hp = m.max
			toast("The Harbingers: ficha %d/4" % int(m.counters))
			if int(m.counters) >= 4:
				_flip_beast(m)
			return true
	return false

func _flip_beast(m: Dictionary) -> void:
	var d: Array = D.MONSTERS["thebeast"]
	m.id = "thebeast"
	m.hp = d[1]
	m.max = d[1]
	m.eva = d[2]
	m.atk = d[3]
	m.reward_kind = d[9]
	m.text = d[8]
	(m.card as Card3D).set_front("thebeast")
	(m.card as Card3D).sheen()
	toast("THE BEAST desperta!", Color(1, 0.4, 0.35))
	_beast_roll()

# The Beast: todos rolam; quem tirar o menor (ou empatar) morre.
func _beast_roll() -> void:
	var vals = {}
	for q in g.players:
		if not q.dead:
			vals[q.i] = g._rand_roll(q)
	if vals.is_empty():
		return
	var mn: int = vals.values().min()
	toast("The Beast: " + ", ".join(vals.keys().map(func(i): return "%s %d" % [g.players[i].name, vals[i]])))
	for i in vals:
		if int(vals[i]) == mn:
			await g._kill_player(g.players[i])

func special_reward(m: Dictionary, by: Dictionary, mult: int) -> void:
	match m.id:
		"mulligoon":
			for i in mult:
				await deal_any(by, 2, "Mulligoon — 2 de dano")
		"holygreed":
			coins(by, int(m.counters) * mult)
		"charmedvis":
			pass  # vira item (em leaves_play)
		"momsheart":
			pass
		"monstercard":
			pass

# false = a carta não vai para o descarte (o efeito decide o destino).
func leaves_play(m: Dictionary, by: Dictionary) -> bool:
	match m.id:
		"coil":
			g.monster_ids.insert(max(0, g.monster_ids.size() - 4), "coil")
			sync_decks()
			g._discard_card(m.card, false)
			return false
		"charmedvis":
			var c: Card3D = m.card
			c.queue_free()
			g._gain_item(by, "charmedvis", c.transform)
			return false
	if bool(m.get("ambush", false)):
		g._discard_card(m.card, false)
		g._loot_to_hand(act(), "monstercard")
		toast("Monster Card volta para a mão de %s" % act().name)
		return false
	return true

func on_mon_killed(m: Dictionary, by: Dictionary) -> void:
	var ap: Dictionary = act()
	var pp: Vector3 = (m.card as Card3D).global_position if is_instance_valid(m.card) else pos(by)
	# Efeitos de morte deste monstro
	match m.id:
		"swarmer", "mother":
			g._expand_monster_slots(2)
		"holymulligan":
			g._expand_monster_slots(2)
			ap.attacks += 1
		"blastocyst":
			g._expand_monster_slots(2)
			ap.state["deck_attacks"] = int(ap.state.get("deck_attacks", 0)) + 1
		"thefallen":
			await g._reorder_top("monster", 5)
		"peepingfatty":
			await g._reorder_top("loot", 5)
		"corny":
			var others: Array = g.players.filter(func(q): return q.i != g.active and not q.dead)
			if not others.is_empty():
				dmg(others.pick_random(), 2)
		"guttedfatty":
			ap.attacks += 1
			ap.state["must_extra"] = int(ap.state.get("must_extra", 0)) + 1
		"charmedgreedling": coins(opp(by), 10)
		"charmedkeeper": await roll(opp(by), "Charmed Keeper", func(v: int) -> void: coins(opp(by), v))
		"charmedbony": coins(opp(by), 5)
		"charmedclotty": await loot(opp(by), 1)
		"charmeddip": g._recharge_first(opp(by))
		"charmedfatbat": await treasure(opp(by), 1)
		"charmedfatty": await loot(opp(by), 2)
		"charmedglobin": await loot(opp(by), 3)
		"therainmaker":
			for i in g.monster_ids.size():
				var id: String = g.monster_ids[i]
				if D.EVENTS.has(id) and D.EVENTS[id][0].begins_with("Curse"):
					g.monster_ids.remove_at(i)
					g.monster_ids.shuffle()
					await place_mon(id)
					break
		"clog":
			g._swap_hands()
		"ragmega":
			if await yes(ap, "Rag Mega — matar o outro jogador?"):
				await g._kill_player(opp(ap))
		"dogma":
			await place_mon("theharbingers")
		"dogma_2":
			var x = await g._choose_item(ap, func(i): return is_same(i.owner, ap) and not g._is_eternal(i), "Dogma — ficha de eterno em qual item?")
			if x != null:
				x.eternal_ctr = true
		"conquest_2":
			ap.attacks += 1
			ap.state["must_player"] = 4
			toast("Conquest: ataque o outro jogador (4+)")
		"sistersvis":
			for q in g.combat.get("team", []):
				await treasure(q, 1)
	# Gatilhos de "cada vez que um monstro morre"
	for o in g._tops():
		match o.id:
			"holyportal":
				ap.attacks += 1
			"holygreedling":
				coins(ap, 3)
			"cursedmulligan":
				g._expand_monster_slots(1)
			"cursedmulliboom":
				dmg(g.players.pick_random(), 3)
			"thebloat":
				for x in g._tops():
					if x != o:
						g._damage_monster(x, 1, ap)
				for q in g.players:
					dmg(q, 1)
	for q in g.players:
		var jf = item(q, "jarofflies")
		if jf != null:
			jf.counters = int(jf.counters) + 1
		var uf = item(q, "ultrafleshkid")
		if uf != null:
			uf.counters = int(uf.counters) + 1
		if (q.curses as Array).has("curseofempathy"):
			g._force_discard(q, 1)
			g._lose_coins(q, 1)
	bonus_tick("souloflust")
	goal_add(by, "kill", 1)
	if room("challengeroom"):
		await roll(ap, "Challenge Room", func(v: int) -> void:
			if v >= 4:
				ap.attacks += 1
				ap.state["must_extra"] = int(ap.state.get("must_extra", 0)) + 1)
	if room("greedmode"):
		coins(ap, int(m.max))
	if room("themirror") and bool(ap.state.get("mirror", false)):
		await treasure(ap, 1)
	if room("conjoinedtwin") and not opp(by).dead:
		toast("Conjoined Twin: %s mata o outro jogador!" % by.name)
		await g._kill_player(opp(by))
	# Quem matou
	if n(by, "headofthekeeper") > 0:
		coins(by, 2 * n(by, "headofthekeeper"))
	if n(by, "bookofvirtues") > 0:
		await loot(by, 1)
		await loot(opp(by), 1)
	for i in n(by, "ceremonialblade"):
		await loot(by, 1)
	if n(by, "berserk") > 0:
		by.temp_hp += 1
		by.hp += 1
	if n(by, "lilchest") > 0:
		await roll(by, "Lil Chest", _r_lilchest.bind(by))
	if n(by, "tick") > 0 and by.i == g.active and not bool(by.state.get("tick", false)):
		by.state["tick"] = true
		by.hp = min(g._max_hp(by), by.hp + 1)
		by.attacks += 1
	if bool(m.get("squid", false)):
		for q in [by] + g.combat.get("team", []):
			var x = await g._choose_item(q, func(i): return is_same(i.owner, q) and int(i.get("hpc", 0)) == 0, "Game Squid — ficha de HP em qual item?")
			if x != null:
				x.hpc = 1
	if g.combat.get("share") != null and in_fight(m) == false:
		var sh: Dictionary = g.combat.share
		g.combat.erase("share")
		var d: Array = g._mdata(m.id)
		if int(d[4]) > 0: coins(sh, int(d[4]))
		if int(d[5]) > 0: await loot(sh, int(d[5]))
		if int(d[6]) > 0: await treasure(sh, int(d[6]))
	g._ui()

func _r_lilchest(v: int, p: Dictionary) -> void:
	if v <= 2:
		coins(p, 2)
	elif v <= 4:
		await loot(p, 2)
		await hand_to_top(p, 1)
	else:
		g._recharge_all(p)

# ---------- Morte de jogador ----------
func prevent_death(p: Dictionary) -> bool:
	var up = item(p, "1up")
	if up != null and p.i == g.active:
		p.items.erase(up)
		g._discard_item(up)
		g._layout_items(p)
		p.hp = g._max_hp(p)
		if g.in_combat and is_same(g.combat.get("p", null), p):
			g.in_combat = false
			if g.awaiting_roll:
				g.roll_requested.emit()
		p.attacks += 1
		toast("1-Up! %s volta à vida" % p.name, Color(0.6, 0.9, 1))
		return true
	if bool(p.state.get("tumorball", false)):
		p.state.erase("tumorball")
		p.hp = g._max_hp(p)
		toast("Tumor Ball previne a morte de %s" % p.name, Color(0.6, 0.9, 1))
		return true
	return false

func before_penalties(p: Dictionary) -> void:
	var o: Dictionary = opp(p)
	for id in ["mamahaunt", "fetalhaunt"]:
		var x = item(p, id)
		if x != null:
			give_item(x, o)
	var dm = item(p, "damocles")
	if dm != null:
		p.items.erase(dm)
		g._discard_item(dm)
		g._layout_items(p)
	var js = item(p, "judasshadow")
	if js != null:
		js.counters = int(js.counters) + 2
	if room("shadowofwar"):
		var it = g._pick_stealable(p)
		if it != null:
			await g._destroy_item(p, it)
	if n(p, "soulbond") > 0 and not o.dead and not bool(p.state.get("soulbond_lock", false)):
		p.state["soulbond_lock"] = true
		toast("Soulbond: %s leva %s junto" % [p.name, o.name])
		await g._kill_player(o)
		p.state.erase("soulbond_lock")
	# Outros jogadores reagem
	for q in g.players:
		if is_same(q, p):
			continue
		if n(q, "darkarts") > 0:
			await loot(q, 1)
		if n(q, "thelefthand") > 0:
			g._recharge_first(q)
		if room("spoilsofwar"):
			await loot(q, 1)
		if room("bloodmoney"):
			coins(q, 4)
	if p.i != g.active:
		var k: Dictionary = act()
		if n(k, "backstabber") > 0:
			await loot(k, 1)
		if n(k, "headofthekeeper") > 0:
			coins(k, 2)
	for q in g.players:
		var bp = item(q, "bloodpuppy")
		if bp != null:
			bp.counters = int(bp.counters) + 1
		var uf = item(q, "ultrafleshkid")
		if uf != null:
			uf.counters = int(uf.counters) + 1
	bonus_tick("soulofwrath")

func penalty(p: Dictionary) -> Dictionary:
	var keep: bool = n(p, "soulbond") > 0 or n(p, "ribofgreed") > 0
	return {"coins": not keep, "loot": not keep, "item": true}

# Item da penalidade de morte: true = já foi tratado (não vai ao descarte).
func penalty_item(p: Dictionary, it: Dictionary) -> bool:
	var ap: Dictionary = act()
	var attacked: bool = bool(p.state.get("was_attacked", false))
	if not is_same(ap, p) and ((lust_target != null and is_same(lust_target, p)) or ((room("battleroyale") or room("battleroyale_2") or room("battleroyale_3")) and attacked)):
		p.items.erase(it)
		it.owner = ap
		ap.items.append(it)
		g._layout_items(p)
		g._layout_items(ap)
		toast("%s entrega %s" % [p.name, D.ITEMS[it.id][0]])
		return true
	for q in g.players:
		if not is_same(q, p) and n(q, "isaacslastwill") > 0:
			var lw = item(q, "isaacslastwill")
			if not lw.has("under"):
				lw.under = []
			lw.under.append(it.id)
			p.items.erase(it)
			(it.card as Card3D).queue_free()
			coins(q, 2)
			g._layout_items(p)
			toast("Isaac's Last Will guarda %s" % D.ITEMS[it.id][0])
			return true
	if mon_in_play("shopkeeper"):
		p.items.erase(it)
		g._expand_shop_slots(1)
		var s: int = g.shop.size() - 1
		var c: Card3D = it.card
		c.zone = "shop"
		c.ref = s
		g.shop[s] = c
		c.fly_to(g._shop_xf(s), 0.5, 0.2)
		g._layout_items(p)
		for k in g.shop.size():
			if g.shop[k] != null:
				(g.shop[k] as Card3D).fly_to(g._shop_xf(k), 0.4, 0.05)
		toast("Shopkeeper: %s vai para a loja" % D.ITEMS[it.id][0])
		return true
	return false

func curses_on_death(p: Dictionary) -> void:
	var cs: Array = p.curses
	if cs.has("curseofenvy"):
		for q in g.players:
			if not is_same(q, p):
				treasure(q, 1)
	if cs.has("curseofthesoulless"):
		cs.erase("curseofthesoulless")
		(opp(p).curses as Array).append("curseofthesoulless")
		toast("Curse of the Soulless passa para %s" % opp(p).name)

func after_death(p: Dictionary) -> void:
	var tb = item(p, "tumorball")
	if tb != null:
		tb.counters = int(tb.counters) + 3
	if n(p, "flip") > 0:
		if p.char in ["theenigma", "theenigma_b"]:
			_flip_char(p, "theenigma_b" if p.char == "theenigma" else "theenigma")
		p.char_tapped = false
		g._layout_items(p)
		discard_hand(p)
		await g._draw_loot(p, 3)

func _flip_char(p: Dictionary, to: String) -> void:
	p.char = to
	var c: Dictionary = D.CHARACTERS[to]
	p.base_hp = c.hp
	p.base_atk = c.atk
	p.name = c.name
	(p.char_card as Card3D).set_front(to)
	(p.char_card as Card3D).sheen()
	toast("%s vira %s" % [p.name, c.name])
	g._ui()

# =====================================================================
# TURNOS
# =====================================================================
func recharge_step(p: Dictionary) -> void:
	var limit_one: bool = room("heavyisthehead") and most_items(p)
	var done = false
	for it in p.items:
		if it.id == "carbattery" and it.tapped:
			continue
		if limit_one and it.tapped:
			if done:
				continue
			done = true
		it.tapped = false
	if n(p, "mamahaunt") == 0:
		p.char_tapped = false
	for r in g.rooms:
		r.tapped = false

func on_turn_start(p: Dictionary) -> void:
	var ap = p
	# Cópias até o início do próximo turno (Undefined/Glitch) desfazem.
	for it in p.items:
		if it.has("keep_orig"):
			it.id = it.keep_orig
			it.erase("keep_orig")
			(it.card as Card3D).set_front(it.id)
	p.state.erase("hand0")
	if n(p, "bagoholes") > 0 and not p.hand.is_empty():
		toast("Bag-o-Holes: descarte a mão")
		discard_hand(p)
	for it in p.items.duplicate():
		if not p.items.has(it) or p.dead:
			continue
		match it.id:
			"hypercoagulation":
				it.counters = int(it.counters) + 1
				p.hp += 1
			"unstabledna":
				await roll(p, "Unstable DNA", _r_dna.bind(it))
			"telepathyfordummies":
				p.state["telepathy"] = g._rand_roll(p)
				toast("Telepathy: próxima rolagem pode virar %d" % int(p.state.telepathy))
			"daddylonglegsitem":
				await deal_any(p, 1, "Daddy Long Legs — 1 de dano")
			"alabasterbox":
				it.counters = int(it.counters) + 1
				match int(it.counters):
					2: coins(p, 10)
					4: await loot(p, 4)
					6: await treasure(p, 2)
			"bloodpuppy":
				if counters(it) >= 8:
					await deal_any(p, 1, "Blood Puppy — 1 de dano")
				if counters(it) >= 10:
					await roll(p, "Blood Puppy", func(v: int) -> void:
						if v <= 3: await g._kill_player(p))
			"bobbybomb":
				_from_discard(p, func(id): return D.LOOT[id][0].to_lower().contains("bomb"))
			"momsbottleofpills":
				_from_discard(p, func(id): return D.LOOT[id][0] == "Pills!")
			"chocolatemilk":
				it.counters = int(it.counters) + 1
				if int(it.counters) >= 3:
					it.counters = 0
					await deal_any(p, 1, "Chocolate Milk — 1 de dano")
			"consolationprize":
				var x = souls_max() - p.soul_n
				if x > 0:
					await loot(p, x)
			"playdoughcookie":
				var c: int = await choose(p, "Playdough Cookie", ["Ganhe 1¢", "+1 ficha num item", "-1 ficha num item"], 0)
				if c == 0:
					coins(p, 1)
				else:
					var y = await g._choose_item(p, func(i): return not g._is_eternal(i), "Playdough Cookie — qual item?")
					if y != null:
						y.counters = max(0, int(y.counters) + (1 if c == 1 else -1))
			"spelunkerhat":
				if ask(p) and await yes(p, "Spelunker Hat — olhar o topo de um deck?"):
					await g._reorder_top(await pick_deck(p, "Spelunker Hat — qual deck?"), 3)
			"cursedsoul":
				dmg(p, 1)
				it.counters = int(it.counters) + 1
				if int(it.counters) >= 6:
					g._item_to_soul(p, it)
					toast("Cursed Soul virou uma alma!")
			"magicskin":
				var k = counters(it)
				await roll(p, "Magic Skin", func(v: int) -> void:
					if v < k:
						toast("Magic Skin destrói todos os itens de %s!" % p.name)
						for x2 in p.items.duplicate():
							await g._destroy_item(p, x2))
			"undefined":
				if not p.bot and ask(p) and await yes(p, "Undefined — descartar um item da loja?", false):
					await shop_to_discard(p)
			"glitch":
				await _glitch_copy(p, it, false)
			"telekinesis":
				if ask(p) and await yes(p, "Telekinesis — olhar 2 cartas do topo de um deck?", false):
					await g._reorder_top(await pick_deck(p, "Telekinesis — qual deck?"), 2)
			"prototype":
				if it.has("proto") and int(it.proto[0]) == 0:
					await _proto_fire(p, it)
	# Monstros com efeito no início de cada turno
	for m in g._tops():
		match m.id:
			"weltling":
				m.counters = int(m.counters) + 1
				m.max = max(0, m.max - 1)
				m.hp = min(m.hp, m.max)
				if m.max <= 0:
					remove_mon(m)
			"war_2":
				var others: Array = g._tops().filter(func(o): return o != m)
				if not others.is_empty():
					var o = others.pick_random()
					o.atc = int(o.atc) + 1
					toast("War: +1 AT em %s" % g._tname(o))
			"cereuspeashy":
				await roll(ap, "Cereus Peashy", _r_peashy.bind(m))
			"krampus_2":
				var naughty: bool = await choose(ap, "Krampus — seu voto", ["NICE", "NAUGHTY"], 0) == 1
				if naughty:
					m.must_turn = true
					toast("Naughty! Ataque Krampus neste turno")
			"theadversary":
				adversary.clear()
				var taken = []
				for q in g.players:
					var v: int = await g._choose_roll_number(q)
					while taken.has(v):
						v = v % 6 + 1
					taken.append(v)
					adversary[q.i] = v
				toast("The Adversary: " + ", ".join(adversary.keys().map(func(i): return "%s=%d" % [g.players[i].name, adversary[i]])))
			"widow_2":
				var vic: Dictionary = g.players.pick_random()
				vic.state["spider"] = int(vic.state.get("spider", 0)) + 1
				toast("Widow: ficha de aranha em %s" % vic.name)
				for i in int(ap.state.get("spider", 0)):
					await roll(ap, "Widow", func(v: int) -> void:
						if v <= 3: dmg(ap, 1))
			"holypsyhorf":
				pass
	# Salas
	for r in g.rooms.duplicate():
		match r.id:
			"blessingofgreed":
				coins(ap, 3)
			"planetarium":
				await treasure(ap, 1)
			"edensblessingroom":
				if ap.items.any(func(i): return not g._is_eternal(i)) and await yes(ap, "Eden's Blessing — rerrolar um item seu?", false):
					await reroll_one(ap, true, "Eden's Blessing — rerrolar qual item?")
			"themirror":
				if ap.hp > 1 and await yes(ap, "The Mirror — pagar HP até ficar com 1? (+1 tesouro por monstro morto)", ap.hp >= 3 and ap.attacks > 0):
					ap.hp = 1
					ap.state["mirror"] = true
			"iamerror":
				await roll(ap, "I Am Error", _r_iamerror.bind(ap))
			"everythingmustgo":
				r.counters = int(r.counters) + 1
	g._ui()

func _from_discard(p: Dictionary, ok: Callable) -> void:
	for i in range(g.loot_discard.size() - 1, -1, -1):
		if ok.call(g.loot_discard[i]):
			var id: String = g.loot_discard[i]
			g.loot_discard.remove_at(i)
			sync_decks()
			g._loot_to_hand(p, id)
			toast("%s pega %s do descarte" % [p.name, D.LOOT[id][0]])
			return

func _r_dna(v: int, it: Dictionary) -> void:
	if v <= 2:
		it.counters = 0
		it.hpc = 0
		it.atc = 0
	elif v <= 4:
		it.hpc = int(it.get("hpc", 0)) + 1
		it.owner.hp += 1
	else:
		it.atc = int(it.get("atc", 0)) + 1
	g._ui()

func _r_peashy(v: int, m: Dictionary) -> void:
	if v <= 3:
		var others: Array = free_mons().filter(func(o): return o != m)
		if not others.is_empty():
			remove_mon(others.pick_random())
			await g._refill_slots()
	else:
		m.must_turn = true
		toast("Cereus Peashy: ataque-o neste turno")

func _r_iamerror(v: int, p: Dictionary) -> void:
	if v <= 2 or v == 6:
		var ms: Array = free_mons()
		if not ms.is_empty():
			remove_mon(ms.pick_random())
			await g._refill_slots()
	if (v >= 3 and v <= 4) or v == 6:
		var mine: Array = p.items.filter(func(i): return not g._is_eternal(i))
		if not mine.is_empty():
			await g._reroll_item(mine.pick_random())
	if v == 5 or v == 6:
		discard_hand(p)
		await g._draw_loot(p, 3)

# Glitch: ganha as habilidades de um item da loja (início: até o fim do turno; fim: até o próximo início).
func _glitch_copy(p: Dictionary, it: Dictionary, until_next: bool) -> void:
	var ids: Array = []
	for s in g.shop:
		if s != null:
			ids.append(s.id)
	if ids.is_empty():
		return
	var pick: String = ids.pick_random()
	if ask(p):
		pick = await g._choose_card(ids, "Glitch — copiar qual item da loja?")
	if until_next:
		it.keep_orig = it.id
		g._copy_item(it, pick, false)
		it.tapped = false
	else:
		g._copy_item(it, pick, true)

func on_turn_end(p: Dictionary) -> void:
	for it in p.items.duplicate():
		if not p.items.has(it):
			continue
		match it.id:
			"hypercoagulation":
				if int(it.counters) >= 3:
					it.counters = 0
					await loot(p, 3)
			"spindowndice":
				await roll(p, "Spindown Dice", func(v: int) -> void:
					if v >= 4: it.tapped = false)
			"ceremonialblade":
				await loot(p, 1)
				await discard_choice(p, 1)
			"rockbottom":
				if p.hand.size() < int(it.counters):
					await loot(p, 2)
			"trickpenny":
				coins(p, 1)
			"fetalhaunt":
				if not p.hand.is_empty():
					g._give_loot(opp(p), p)
			"cursedsoul":
				give_item(it, opp(p))
			"ultrafleshkid":
				if int(it.counters) >= 12:
					g._item_to_soul(p, it)
			"batterypack":
				it.counters = int(it.counters) + 1
			"keeperssack":
				if p.hand.is_empty():
					dmg(p, 2)
				else:
					await discard_choice(p, 1, "Keeper's Sack — descarte 1 loot")
			"aaabattery":
				await roll(p, "AAA Battery", func(v: int) -> void:
					if v >= 4: g._recharge_first(p))
			"deadweight", "xrayvision", "classicroller":
				it.tapped = false
	if int(p.state.get("lemegeton", 0)) > 0:
		for i in int(p.state.lemegeton):
			var x = await g._choose_item(p, func(y): return is_same(y.owner, p) and not g._is_eternal(y), "Lemegeton — destrua um item seu")
			if x != null:
				await g._destroy_item(p, x)
		p.state.lemegeton = 0
	var cs: Array = p.curses
	if cs.has("curseofimpulse"):
		for it in p.items:
			it.tapped = true
		p.char_tapped = true
		g._layout_items(p)
	if cs.has("curseofthehollow") and p.soul_n > 0:
		g._force_discard(p, p.soul_n)
		g._lose_coins(p, p.soul_n)
	for m in g._tops():
		if m.id == "holypsyhorf":
			await loot(p, 1)
		if m.id == "megasatan":
			var alive: Array = g.players.filter(func(q): return not q.dead)
			if alive.size() == 1 and is_same(alive[0], p):
				toast("Mega Satan: %s é o único vivo!" % p.name)
				g._game_end(p)
				return
	for r in g.rooms:
		match r.id:
			"bumboisloose": g._lose_coins(p, 2)
			"butterfingers": g._force_discard(p, 1)
			"redvise":
				if p.hand.size() <= 1: dmg(p, 1)
			"spiderwebs":
				p.char_tapped = true
				g._layout_items(p)
			"greedlooms":
				if p.bought == 0: g._force_discard(p, p.hand.size())
	g._ui()

func after_revert(p: Dictionary) -> void:
	for it in p.items:
		if it.id == "glitch":
			await _glitch_copy(p, it, true)

# Fim do turno, já com todos curados: zera efeitos "até o fim do turno".
func on_cleanup() -> void:
	mutant = null
	erawalk.clear()
	eternal6 = false
	jail = -1
	rival = null
	lust_target = null
	adversary.clear()
	for q in g.players:
		for k in ["atk_rolls", "deck_attacked", "must_extra", "must_player", "redcandle", "x2rewards", "algiz",
				"mirror", "loot_n", "abil_n", "pokerchip", "tick", "atk_set", "mm_atk", "attacked_uids", "attacked_n",
				"was_attacked", "deck_attacks", "club_off", "telepathy", "bloodlust_done"]:
			q.state.erase(k)
	for m in g._all_mons():
		m.erase("horse")
		m.erase("must_turn")
		m.erase("last_roll")
		m.erase("mother_nums")
		m.erase("reached1")
		m.rolls = 0
		if m.has("base_max"):
			m.max = m.base_max
			m.erase("base_max")
		if m.id == "weltling":
			m.hp = m.max
	for x in g.xtargets:
		x.hp = x.max
		x.rolls = 0

func after_end(p: Dictionary) -> void:
	# Dice Rooms saem no fim do turno.
	for r in g.rooms.duplicate():
		if r.id.begins_with("diceroom"):
			await discard_room(r)
	# Troca de sala: se um monstro morreu neste turno, o ativo pode descartar uma sala.
	if g.monster_died and not g.rooms.is_empty() and not g.room_ids.is_empty():
		var r = g.rooms[0]
		if _room_stays(r):
			pass
		elif await yes(p, "Um monstro morreu: descartar a sala %s?" % g._card_disp_name(r.id), bot_dislikes_room(r.id), r.id):
			await discard_room(r)
	await room_refill()

func _room_stays(r: Dictionary) -> bool:
	if r.id == "socialgoals":
		return _goals_done() < 4
	if r.id == "everythingmustgo":
		return g.shop.any(func(s): return s != null)
	return false

# ---------- Rolagens ----------
# Antes do lançamento: vários dados, resultado fixado.
func adjust_roll(p: Dictionary, v: int, extra: Dictionary) -> int:
	var atk: bool = bool(extra.get("attack", false))
	var tgt = g._find_mon(int(extra.get("mon_uid", -1))) if atk else null
	if not erawalk.is_empty() and int(erawalk.n) > 0:
		erawalk.n = int(erawalk.n) - 1
		return int(erawalk.v)
	if bool(p.state.get("d8", false)):
		p.state.erase("d8")
		v = randi_range(1, 8)
		toast("D8: %d" % v)
		v = min(v, 6)
	var dice = 1
	var chooser = null
	if mutant != null:
		dice = 4
		chooser = mutant.chooser
		mutant = null
	elif mon_in_play("cursedlilhaunt"):
		dice = 2
		chooser = opp(p)
	elif tgt != null and tgt.id == "taintedspitty":
		dice = p.soul_n + 1
		chooser = "low"
	if dice > 1:
		var vals = [v]
		for i in dice - 1:
			vals.append(g._rand_roll(p))
		var pickv: int = vals.max()
		if chooser is String or not is_same(chooser, p):
			pickv = vals.min()
		if chooser is Dictionary and ask(chooser):
			var opts: Array = vals.map(func(x): return str(x))
			pickv = int(vals[await g._choose_option("Escolha o resultado de %s" % p.name, opts, 0)])
		toast("Dados: %s → %d" % [", ".join(vals.map(func(x): return str(x))), pickv])
		v = pickv
	if eternal6 and (v == 2 or v == 3):
		v = 1
		toast("Eternal D6: vira 1")
	if tgt != null and tgt.id == "mother_2":
		var nums = [randi_range(1, 6), randi_range(1, 6)]
		if ask(opp(p)):
			nums = [await g._choose_roll_number(opp(p)), await g._choose_roll_number(opp(p))]
		tgt.mother_nums = nums
		toast("Mother: %d e %d erram" % nums)
	return v

# Depois de ver o dado: mudanças opcionais.
func change_roll(p: Dictionary, v: int, extra: Dictionary) -> int:
	var atk: bool = bool(extra.get("attack", false))
	if p.state.has("telepathy"):
		var t: int = int(p.state.telepathy)
		var use = false
		if ask(p):
			use = await yes(p, "Telepathy — mudar %d para %d?" % [v, t], false)
		else:
			use = t > v
		p.state.erase("telepathy")
		if use:
			v = t
	if n(p, "phd") > 0 and not atk and ask(p):
		var c: int = await g._choose_option("P.H.D. — rolagem %d" % v, ["MANTER", "+1", "-1"], 0)
		v = clampi(v + [0, 1, -1][c], 1, 6)
	if room("isaacsblessing") and (v == 1 or v == 6):
		var re = false
		if ask(p):
			re = await yes(p, "Isaac's Blessing — rerrolar o %d?" % v, false)
		else:
			re = v == 1
		if re:
			v = g._rand_roll(p)
			toast("Isaac's Blessing: %d" % v)
	return v

func roll_triggers(p: Dictionary, v: int) -> void:
	for q in g.players:
		if v == 6:
			for i in n(q, "darkarts"):
				coins(q, 2)
			var cd = item(q, "conjoinedd6")
			if cd != null:
				cd.tapped = false
		if v == 2:
			var hg = item(q, "hallowedground")
			if hg != null:
				hg.counters = int(hg.counters) + 1
			if n(q, "hourglass") > 0:
				var vic: Dictionary = opp(q)
				for it in vic.items:
					if not it.tapped and D.ITEMS[it.id][2] != "passive":
						it.tapped = true
						g._layout_items(vic)
						toast("Hourglass desativa %s" % D.ITEMS[it.id][0])
						break
		if v == 1:
			var sd = item(q, "sacrificialdagger")
			if sd != null:
				sd.counters = int(sd.counters) + 1
			if n(q, "gamebreakingbug") > 0 and not is_same(q, p):
				var mine: Array = p.items.filter(func(i): return not g._is_eternal(i))
				if not mine.is_empty() and randf() < 0.5:
					await g._reroll_item(mine.pick_random())
		if v == 3:
			if n(q, "lodestone") > 0:
				var m = await pick_mon(q, "Lodestone — qual monstro ganha -1 DC?", true)
				if m != null:
					m.temp_eva = int(m.temp_eva) - 1
			for it in q.items:
				if it.id == "prototype" and it.has("proto") and int(it.proto[0]) == 1:
					await _proto_fire(q, it)
		if (q.state.get("redcandle", []) as Array).has(v):
			await deal_any(q, 1, "Red Candle — 1 de dano")
		if adversary.get(q.i, -1) == v:
			dmg(q, 1)
	for m in g._tops():
		match m.id:
			"holybony":
				if v == 6 and ask(p):
					await g._reorder_top(await pick_deck(p, "Holy Bony — qual deck?"), 3)
			"cursedtumor":
				if v == 4:
					for q in g.players:
						dmg(q, 1)
			"cursedglobin":
				if v == 3:
					for o in g._tops():
						o.hp = min(o.max, o.hp + 2)
			"holybrain":
				if v == 3:
					for o in g._tops():
						o.temp_eva = int(o.temp_eva) - 1
			"therainmaker":
				if v == 1:
					await loot(p, 1)
			"dogma_2":
				if v == 1:
					for o in free_mons():
						if o != m:
							remove_mon(o)
	if room("floorspikes") and v == 1:
		dmg(p, 1)
	if v == 6:
		goal_add(p, "six", 1)
	g._ui()

# =====================================================================
# COMBATE
# =====================================================================
# Monstros que o jogador ainda é obrigado a atacar neste turno.
func must_targets(p: Dictionary) -> Array:
	var done: Array = p.state.get("attacked_uids", [])
	var out = []
	for m in g._tops():
		if (m.id in ["krampus", "theharbingers"] or bool(m.get("must_turn", false)) or bool(m.get("must_fb", false))) and not done.has(m.uid):
			out.append(m)
	return out

func can_attack(p: Dictionary, m: Dictionary) -> String:
	if m.has("player"):
		return ""
	var must = must_targets(p)
	if not must.is_empty() and not must.has(m) and p.attacks <= must.size():
		return "Ataque %s primeiro" % g._tname(must[0])
	if room("taxforthemighty") and souls_max() > 0 and p.soul_n == souls_max() and p.coins < 2:
		return "Tax for the Mighty: precisa de 2¢ para atacar"
	return ""

func must_attack_reason(p: Dictionary) -> String:
	if p.attacks <= 0 or p.dead:
		return ""
	var must = must_targets(p)
	if not must.is_empty():
		return "Você deve atacar %s" % g._tname(must[0])
	if int(p.state.get("must_player", 0)) > 0 and not opp(p).dead:
		return "Você deve atacar o outro jogador"
	var any_mon: bool = not g._tops().filter(func(m): return not g._has_tag(m, "untargetable")).is_empty()
	if int(p.state.get("must_extra", 0)) > 0 and any_mon:
		return "Você deve fazer o ataque adicional"
	if ((p.curses as Array).has("curseofbloodlust") or room("bloodlustroom")) and int(p.state.get("attacked_n", 0)) == 0 and any_mon:
		return "Você deve atacar neste turno"
	if room("blindrage") and not bool(p.state.get("deck_attacked", false)) and not g.monster_ids.is_empty():
		return "Blind Rage: ataque o topo do deck de monstros"
	if room("everythingmustgo") and p.bought == 0 and g.shop.any(func(s): return s != null) and p.coins >= g._shop_price(p):
		return "Everything Must Go: compre um item da loja"
	return ""

func bot_forced_attack(p: Dictionary):
	if p.dead or g.turn_over:
		return null
	if p.attacks <= 0 and int(p.state.get("deck_attacks", 0)) > 0 and not g.monster_ids.is_empty() and p.hp >= 2:
		return "deck"
	if p.attacks <= 0:
		return null
	var must = must_targets(p)
	if not must.is_empty():
		return must[0]
	if int(p.state.get("must_player", 0)) > 0 and not opp(p).dead:
		return player_target(opp(p), int(p.state.must_player))
	if room("blindrage") and not bool(p.state.get("deck_attacked", false)) and not g.monster_ids.is_empty():
		return "deck"
	# Jogador atacável e quase morto: vale o ataque.
	var o: Dictionary = opp(p)
	var dc = player_attack_dc(p, o)
	if dc > 0 and not o.dead and o.hp <= g._atk(p) and dc <= 4:
		return player_target(o, dc)
	if int(p.state.get("must_extra", 0)) > 0 or (((p.curses as Array).has("curseofbloodlust") or room("bloodlustroom")) and int(p.state.get("attacked_n", 0)) == 0):
		var ms: Array = g._tops().filter(func(m): return not g._has_tag(m, "untargetable"))
		if not ms.is_empty():
			return ms[0]
	return null

func redirect_attack(p: Dictionary, m: Dictionary) -> Dictionary:
	if m.has("player") or m.has("obj"):
		return m
	var o: Dictionary = opp(p)
	if n(o, "momseyeshadow") > 0 and g._tops().size() > 1:
		var pick = m
		if ask(o):
			var t = await g._choose_target("Mom's Eye Shadow — qual monstro %s ataca?" % p.name, "monster")
			if t != null:
				pick = t.m
		else:
			for x in g._tops():
				if g._eva(x) + g._mon_atk(x) > g._eva(pick) + g._mon_atk(pick):
					pick = x
		if pick != m:
			toast("Mom's Eye Shadow: %s ataca %s" % [p.name, g._tname(pick)])
		return pick
	return m

func on_attack_declared(p: Dictionary, m: Dictionary) -> void:
	var team: Array = g.combat.team
	var o: Dictionary = opp(p)
	if not p.state.has("attacked_uids"):
		p.state["attacked_uids"] = []
	p.state.attacked_uids.append(m.uid)
	p.state["attacked_n"] = int(p.state.get("attacked_n", 0)) + 1
	if int(p.state.get("must_extra", 0)) > 0:
		p.state.must_extra = int(p.state.must_extra) - 1
	if m.has("player"):
		m.player.state["was_attacked"] = true
		p.state.erase("must_player")
	if room("taxforthemighty") and souls_max() > 0 and p.soul_n == souls_max():
		g._lose_coins(p, 2, true)
		o.coins += 2
	if room("bloodlustroom") and not bool(p.state.get("bloodlust_done", false)):
		p.state["bloodlust_done"] = true
		p.attacks += 1
		p.state["must_extra"] = int(p.state.get("must_extra", 0)) + 1
	for w in g._tops():
		if w.id == "whipper":
			await roll(p, "Whipper", func(v: int) -> void:
				if v <= 2: dmg(p, 1))
	if rival != null:
		if not is_same(rival, p) and not team.has(rival):
			team.append(rival)
			g.combat["share"] = rival
		rival = null
	if n(p, "coopbaby") > 0 and not o.dead and not team.has(o):
		team.append(o)
	if n(p, "gamesquid") > 0 and not m.has("player") and not m.has("obj") and await yes(p, "Game Squid — dar +1 HP e +1 AT ao monstro (equipe + fichas de HP)?", false):
		m.max += 1
		m.hp += 1
		m.temp_atk = int(m.temp_atk) + 1
		m.squid = true
		if not team.has(o):
			team.append(o)
	if room("multiplayerupdate") and not team.has(o):
		team.append(o)
	match m.id:
		"ragmega":
			for q in g.players:
				if q.i != g.active:
					g._force_discard(q, 1)
		"sistersvis", "ultragreed", "giantpoop":
			if not team.has(o):
				team.append(o)
		"gus":
			await roll(o, "Gus", func(v: int) -> void:
				if v >= 4 and not team.has(o): team.append(o))
		"dogma":
			for x in free_mons():
				if x != m:
					remove_mon(x)
		"therainmaker_2":
			var skipped: Array = []
			while not g.monster_ids.is_empty():
				var id: String = g.monster_ids.pop_back()
				if D.EVENTS.has(id) and D.EVENTS[id][0].begins_with("Curse"):
					(p.curses as Array).append(id)
					toast("%s recebe %s" % [p.name, D.EVENTS[id][0]])
					break
				skipped.append(id)
			skipped.shuffle()
			for id in skipped:
				g.monster_ids.push_front(id)
			sync_decks()
		"taintedmulligan":
			if not m.has("base_max"):
				m.base_max = m.max
			m.max += p.hand.size()
			m.hp += p.hand.size()
		"thebeast":
			await _beast_roll()
		"monstercard":
			_monster_card_copy(m)
	g._ui()

func _monster_card_copy(m: Dictionary) -> void:
	for i in range(g.monster_ids.size() - 1, -1, -1):
		var id: String = g.monster_ids[i]
		if D.MONSTERS.has(id):
			var d: Array = D.MONSTERS[id]
			m.id = id
			m.hp = d[1]
			m.max = d[1]
			m.eva = d[2]
			m.atk = d[3]
			m.reward_kind = d[9]
			m.text = d[8]
			m.ambush = true
			(m.card as Card3D).set_front(id)
			toast("Monster Card vira %s!" % d[0])
			return

func attack_miss_forced(p: Dictionary, m: Dictionary, raw: int) -> bool:
	if m.id == "hush" and m.has("last_roll") and raw <= int(m.last_roll):
		toast("Hush: rolagem menor ou igual à anterior")
		return true
	if m.id == "mother_2" and (m.get("mother_nums", []) as Array).has(raw):
		toast("Mother: número escolhido, errou!")
		return true
	return false

func combat_immune(m: Dictionary, raw: int) -> bool:
	match m.id:
		"turdlings": return raw != 2
		"nullmon": return int(m.rolls) % 2 == 0
	return false

func combat_dmg(p: Dictionary, _m: Dictionary, raw: int, d: int) -> int:
	if raw == 6:
		d += 3 * n(p, "cursedeye")
		for i in n(p, "firemind"):
			d *= 2
	return d

func on_combat_hit(p: Dictionary, m: Dictionary, _raw: int, _d: int) -> void:
	if m.has("player"):
		return
	for i in n(p, "thewiz"):
		await deal_any(p, 1, "The Wiz — 1 de dano em outro alvo")
	for i in n(p, "abel"):
		await roll(p, "Abel", func(v: int) -> void:
			if v >= 4: await deal_any(p, 1, "Abel — 1 de dano"))
	for i in n(p, "bookofvirtues"):
		await roll(p, "Book of Virtues", func(v: int) -> void:
			if v >= 5: await deal_any(p, 1, "Book of Virtues — 1 de dano"))

func player_combat_dmg(p: Dictionary, m: Dictionary, raw: int, d: int) -> int:
	if m.id == "bony" and raw == 1:
		m.temp_atk = int(m.temp_atk) + 2
		d += 2
	if (raw == 1 or raw == 6) and n(p, "haloofflies") > 0:
		return 0
	if raw == 3 and n(p, "ballofbandages") > 0:
		return 0
	if raw == 1 and n(p, "deadweight") > 0:
		return 0
	if raw == 1:
		for i in n(p, "firemind"):
			d *= 2
	if m.id == "hornfel" and p.i == g.active:
		dmg(g.players.pick_random(), 1)
		toast("Hornfel desvia o golpe")
		return 0
	return d

func on_attack_miss(p: Dictionary, m: Dictionary, _raw: int) -> void:
	for i in n(p, "rubbercement"):
		await roll(p, "Rubber Cement", func(v: int) -> void:
			if v <= 3: await deal_any(p, 1, "Rubber Cement — 1 de dano"))
	for i in n(p, "tapeworm"):
		dmg(opp(p), 1)
	if m.id == "charmedglobin":
		m.hp = min(m.max, m.hp + 1)

func after_attack_roll(p: Dictionary, m: Dictionary, raw: int, hit: bool) -> void:
	p.state.erase("mm_atk")
	var rolls: Array = p.state.get("atk_rolls", [])
	var prev: int = int(rolls.back()) if not rolls.is_empty() else -1
	rolls.append(raw)
	p.state["atk_rolls"] = rolls
	if m.has("player"):
		if m.player.dead:
			g.in_combat = false
		return
	if not hit:
		m.bot_fails = int(m.get("bot_fails", 0)) + 1
	if raw == 6 and m.id == "brain":
		dmg(p, 1)
	if raw == 6 and m.id == "charmedbony":
		dmg(opp(p), 1)
	if raw == 1 and m.id == "weltling":
		for q in g.players:
			dmg(q, 2)
	if prev == raw:
		if n(p, "euthanasia") > 0 and g._find_mon(m.uid) != null and not m.has("obj"):
			toast("Euthanasia! Mesmo resultado duas vezes")
			g._damage_monster(m, 99, p)
		if m.id == "krampus_2":
			for o in g._tops():
				if o != m:
					g._damage_monster(o, 1, p)
	if raw == 1 and n(p, "cursedeye") > 0 and is_same(p, act()):
		toast("Cursed Eye: o turno acaba!", Color(1, 0.5, 0.4))
		g.in_combat = false
		g._cancel_turn()
		return
	if m.id == "turdlings" and int(g.combat.get("rolls", 0)) >= 2 and in_fight(m):
		toast("Turdlings: ataque cancelado")
		g.in_combat = false

func on_attack_end(p: Dictionary) -> void:
	for x in g.xtargets.duplicate():
		if x.has("player"):
			g.xtargets.erase(x)

# ---------- Ataque ao topo do deck ----------
func pick_slot_for_deck(p: Dictionary) -> int:
	var opts: Array = []
	for s in g.slots.size():
		var m = g._top(s)
		if m == null:
			return s
		if not in_fight(m):
			opts.append(s)
	if opts.is_empty():
		return 0
	if ask(p) and opts.size() > 1:
		var labels: Array = opts.map(func(s): return "ESPAÇO %d · %s" % [s + 1, g._tname(g._top(s))])
		return opts[await g._choose_option("Cobrir qual espaço?", labels, 0)]
	var best: int = opts[0]
	for s in opts:
		var a = g._top(s)
		var b = g._top(best)
		if g._eva(a) + a.hp > g._eva(b) + b.hp:
			best = s
	return best

func before_deck_attack(p: Dictionary) -> void:
	if room("blessingoftheinnereye") and ask(p) and await yes(p, "Blessing of the Inner Eye — olhar as 3 do topo?", false):
		await g._reorder_top("monster", 3)

func cancel_deck_attack(p: Dictionary) -> bool:
	if not room("angelicintervention"):
		return false
	var m: Dictionary = g.last_revealed
	return await yes(p, "Angelic Intervention — cancelar o ataque a %s?" % g._tname(m), g._mon_atk(m) >= p.hp or g._eva(m) >= 5)

# ---------- Jogadores atacáveis ----------
func player_attack_dc(p: Dictionary, q: Dictionary) -> int:
	if q.dead or is_same(p, q) or p.i != g.active:
		return 0
	var dc = 0
	if mon_in_play("megasatan") or mon_in_play("thesiren"):
		dc = 4
	if room("battleroyale"):
		dc = 3
	if room("battleroyale_2"):
		dc = 4
	if room("battleroyale_3"):
		dc = 5
	if n(p, "backstabber") > 0 and q.soul_n > p.soul_n and (dc == 0 or dc > 3):
		dc = 3
	if (lust_target != null and is_same(lust_target, q)) or int(p.state.get("must_player", 0)) > 0:
		dc = 4 if dc == 0 else dc
	return dc

func player_target(q: Dictionary, dc: int) -> Dictionary:
	for x in g.xtargets:
		if x.has("player") and is_same(x.player, q):
			x.eva = dc
			return x
	g.uid += 1
	var x = {"id": q.char, "uid": g.uid, "player": q, "name": q.name, "hp": q.hp, "max": g._max_hp(q), "eva": dc,
		"atk": 0, "slot": -1, "card": q.char_card, "tags": [], "temp_atk": 0, "temp_eva": 0, "hits": 0,
		"reward_kind": "", "text": "", "double": false, "prevent_full": 0, "counters": 0, "rolls": 0, "hpc": 0, "atc": 0}
	g.xtargets.append(x)
	return x

# ---------- Itens/salas/almas atacáveis ----------
func make_xtarget(ref, kind: String) -> void:
	if xtarget_of(ref) != null:
		return
	var id: String = ref.id
	if not D.ATTACKABLE.has(id) and not D.MONSTERS.has(id):
		return
	var c: Card3D = ref.card if ref is Dictionary else ref
	var x: Dictionary = g._make_mon(id, -1, c)
	x.obj = ref
	x.objkind = kind
	x.name = g._mdata(id)[0]
	if kind == "soul":
		x.eva += 1
	g.xtargets.append(x)
	g._update_monster_labels()

func xtarget_of(ref):
	for x in g.xtargets:
		if x.has("obj") and is_same(x.obj, ref):
			return x
	return null

func forget_xtarget(ref) -> void:
	var x = xtarget_of(ref)
	if x == null:
		return
	if x.get("label") != null and is_instance_valid(x.label):
		(x.label as Label3D).queue_free()
	g.xtargets.erase(x)

func kill_xtarget(m: Dictionary, by: Dictionary) -> void:
	var ap: Dictionary = act()
	if g.in_combat and g.combat.get("uid", -1) == m.uid:
		g.in_combat = false
		if g.awaiting_roll:
			g.roll_requested.emit()
	var ref = m.obj
	toast("%s derrotou %s!" % [by.name, m.name], Color(1, 0.85, 0.5))
	Sfx.play("mon_kill")
	g._burst((m.card as Card3D).global_position + Vector3(0, 0.08, 0), Color(1, 0.7, 0.3), 30, 3.0, 0.08, -4.0, 0.6)
	var d: Array = g._mdata(m.id)
	match m.id:
		"animasola_b":
			await loot(by, 2)
			forget_xtarget(ref)
			ref.id = "animasola"
			(ref.card as Card3D).set_front("animasola")
			await loot(ref.owner, 1)
			by.attacks += 1
			return
		"charmedvis":
			if not is_same(ref.owner, by):
				forget_xtarget(ref)
				g._transfer_item(ref, by)
				make_xtarget(ref, "item")
				toast("%s rouba o Charmed Vis" % by.name)
				return
		"cursedhaunt":
			await treasure(ap, 1)
			for q in g.players:
				if q.souls.has(ref) and not is_same(q, ap):
					q.souls.erase(ref)
					q.soul_n -= 1
					ap.souls.append(ref)
					ap.soul_n += 1
					ref.ref = ap
					ref.fly_to(g._soul_xf(ap, ap.souls.size() - 1), 0.6, 0.3)
					toast("%s rouba a alma Cursed Haunt" % ap.name)
			x_heal(m)
			g._check_bonus_souls()
			return
		"gus":
			for q in g.players:
				await treasure(q, 1)
	# Recompensas comuns (vão para o jogador ativo)
	if int(d[4]) > 0:
		coins(ap, int(d[4]))
	if int(d[5]) > 0:
		await loot(ap, int(d[5]))
	if int(d[6]) > 0:
		await treasure(ap, int(d[6]))
	forget_xtarget(ref)
	if m.objkind == "item":
		await g._destroy_item(ref.owner, ref)
	elif m.objkind == "room":
		if int(d[7]) > 0 and can_gain_soul(ap):
			g.rooms.erase(ref)
			var c: Card3D = ref.card
			c.zone = "soul"
			c.ref = ap
			ap.souls.append(c)
			ap.soul_n += int(d[7])
			c.fly_to(g._soul_xf(ap, ap.souls.size() - 1), 0.6, 0.3)
			on_soul_gained(ap, m.id)
			g._check_bonus_souls()
			_layout_rooms()
			await room_refill()
		else:
			await discard_room(ref)

func x_heal(m: Dictionary) -> void:
	m.hp = m.max

# =====================================================================
# SALAS (Requiem)
# =====================================================================
func room_refill() -> void:
	while g.rooms.size() < room_slots and not g.room_ids.is_empty() and not g.game_over:
		await reveal_room(g.room_ids.pop_back())

func reveal_room(id: String) -> void:
	g.decks.room.set_count(g.room_ids.size())
	g.decks.room.bump()
	var c = Card3D.make(id, "roomback")
	g.table.add_child(c)
	c.transform = g.decks.room.top_xf()
	c.zone = "room"
	c.tapped.connect(g._on_card_tapped)
	var r = {"id": id, "card": c, "tapped": false, "counters": 0, "state": {}}
	c.ref = r
	g.rooms.append(r)
	_layout_rooms()
	Sfx.play("mon_reveal")
	toast("Sala: " + g._card_disp_name(id))
	await g._wait(0.4)
	await room_enter(r)
	g._ui()

func _layout_rooms() -> void:
	for i in g.rooms.size():
		(g.rooms[i].card as Card3D).fly_to(g._room_xf(i), 0.45, 0.2)

func room_enter(r: Dictionary) -> void:
	var ap: Dictionary = act()
	match r.id:
		"diceroom":
			await reroll_all(ap)
		"diceroom_2":
			for q in g.players:
				discard_hand(q)
				await g._draw_loot(q, 3)
		"diceroom_3":
			_shop_clear()
		"diceroom_4":
			for q in g.players:
				await reroll_all(q)
		"diceroom_5":
			_mons_clear()
			await g._refill_slots()
		"diceroom_6":
			for q in g.players:
				await reroll_all(q)
			for q in g.players:
				discard_hand(q)
				await g._draw_loot(q, 3)
			_mons_clear()
			await g._refill_slots()
		"everythingmustgo":
			g._expand_shop_slots(2)
			_fill_shop()
		"redchampions":
			for m in g._all_mons():
				m.max += 1
				m.hp += 1
		"guppyspieces":
			if not bonus_active.has("soulofguppy"):
				bonus_active.append("soulofguppy")
				g.bonus_souls_taken.erase("soulofguppy")
				toast("Soul of Guppy entra em jogo")
		"gus", "dailyrun":
			make_xtarget(r, "room")

func _shop_clear() -> void:
	for s in g.shop.size():
		if g.shop[s] != null:
			g.treasure_discard.append(g.shop[s].id)
			g.shop[s].queue_free()
			g.shop[s] = null
	_fill_shop()

func _mons_clear() -> void:
	for m in free_mons():
		remove_mon(m)

func discard_room(r: Dictionary) -> void:
	if not g.rooms.has(r):
		return
	g.rooms.erase(r)
	forget_xtarget(r)
	if r.id == "redchampions":
		for m in g._all_mons():
			m.max = max(1, m.max - 1)
			m.hp = min(m.hp, m.max)
	var c: Card3D = r.card
	if D.ITEMS.has(r.id) and not D.ROOMS.has(r.id):
		g.treasure_discard.append(r.id)
	else:
		g.room_discard.append(r.id)
	c.zone = "gone"
	var t = c.fly_to(Transform3D(g.FACE_UP, Vector3(-3.4, 0.3, -2.3)), 0.5, 0.3)
	t.finished.connect(c.queue_free)
	_layout_rooms()
	await room_refill()

func give_room(id: String) -> void:
	g.room_ids.erase(id)
	g.room_ids.push_back(id)
	for r in g.rooms.duplicate():
		await discard_room(r)

# Rooms ruins para a CPU (descarta quando pode).
func bot_dislikes_room(id: String) -> bool:
	return id in ["lasereye", "redvise", "spiderwebs", "greedlooms", "bumboisloose", "butterfingers", "staticshock",
		"floorspikes", "conjoinedtwin", "blackchampions", "whitechampions", "redchampions", "shadowoffamine", "heavyisthehead",
		"taxforthemighty", "allhallowseve", "haunted", "blindrage", "bloodlustroom", "splashdamage", "shadowofwar"]

func room_has_paid(id: String) -> bool:
	return D.ROOMS.has(id) and str(D.ROOMS[id][1]).begins_with("$")

func room_has_tap(r: Dictionary) -> bool:
	if r.id == "guppyspieces":
		return true
	return D.ITEMS.has(r.id) and D.ITEMS[r.id][2] in ["tap", "both"]

func inspect_room(c: Card3D) -> void:
	var r: Dictionary = c.ref
	var me: Dictionary = g.players[0]
	var btns = []
	var mine: bool = g.active == 0 and g._human_has_priority()
	if room_has_paid(r.id):
		btns.append(["USAR ($)", func(): g._close_inspect(); room_paid(me, r), mine and room_paid_ok(me, r)])
	if room_has_tap(r):
		btns.append(["ATIVAR", func(): g._close_inspect(); room_tap(me, r), mine and not r.tapped])
	var xt = xtarget_of(r)
	if xt != null:
		btns.append(["ATACAR", func(): g._close_inspect(); g._attack(me, xt), g._human_idle() and me.attacks > 0])
	var txt: String = D.ROOMS[r.id][1] if D.ROOMS.has(r.id) else D.ITEMS[r.id][1]
	if int(r.counters) > 0:
		txt += "\nFichas: %d" % int(r.counters)
	if r.id == "socialgoals":
		txt += "\nMetas: %d/4" % _goals_done()
	g._open_inspect(r.id, g._card_disp_name(r.id), txt, btns)

func room_paid_ok(p: Dictionary, r: Dictionary) -> bool:
	match r.id:
		"beggar", "shellgame", "slotmachine", "fortuneteller": return p.coins >= 3
		"restockmachine": return p.coins >= 2
		"devilbeggar", "blooddonation": return p.hp > 1
		"bombbum", "keymaster", "eternalchest": return not p.hand.is_empty()
	return false

func _room_discard_self(r: Dictionary) -> void:
	await discard_room(r)

# Habilidade $ de sala (só o jogador ativo).
func room_paid(p: Dictionary, r: Dictionary) -> void:
	if p.i != g.active or not room_paid_ok(p, r):
		return
	Sfx.play("item_use")
	match r.id:
		"beggar":
			g._lose_coins(p, 3, true)
			await roll(p, "Beggar", func(v: int) -> void:
				if v >= 3 and v <= 4: coins(p, 2)
				elif v == 5: await loot(p, 2)
				elif v == 6:
					await treasure(p, 1)
					await _room_discard_self(r))
		"devilbeggar":
			p.hp -= 1
			await roll(p, "Devil Beggar", func(v: int) -> void:
				if v <= 2: await loot(p, 2)
				elif v <= 5: await loot(p, 1)
				else: dmg(p, 1))
		"bombbum":
			var bomb: bool = await _room_discard_named(p, "bomb")
			for i in (3 if bomb else 1):
				await roll(p, "Bomb Bum", func(v: int) -> void:
					if v <= 4: await deal_any(p, 1, "Bomb Bum — 1 de dano")
					else: dmg(p, 1))
		"keymaster":
			var key: bool = await _room_discard_named(p, "key")
			for i in (3 if key else 1):
				await roll(p, "Key Master", func(v: int) -> void:
					if v >= 5: await treasure(p, 1))
		"shellgame":
			g._lose_coins(p, 3, true)
			await roll(p, "Shell Game", func(v: int) -> void:
				if v == 3: coins(p, 1)
				elif v == 4: await loot(p, 1)
				elif v == 5: coins(p, 5)
				elif v == 6:
					await treasure(p, 1)
					await _room_discard_self(r))
		"blooddonation":
			p.hp -= 1
			coins(p, 3)
		"slotmachine":
			g._lose_coins(p, 3, true)
			await roll(p, "Slot Machine", func(v: int) -> void:
				if v >= 2 and v <= 5: coins(p, [0, 0, 1, 2, 5, 7][v - 1])
				elif v == 6:
					coins(p, 15)
					await _room_discard_self(r))
		"fortuneteller":
			g._lose_coins(p, 3, true)
			await roll(p, "Fortune Teller", func(v: int) -> void:
				if v >= 3 and v <= 5: await loot(p, v - 2)
				elif v == 6:
					await loot(p, 6)
					await _room_discard_self(r))
		"restockmachine":
			g._lose_coins(p, 2, true)
			if await choose(p, "Restock Machine", ["Itens da loja ao descarte", "Monstros ao descarte"], 0) == 0:
				_shop_clear()
			else:
				_mons_clear()
				await g._refill_slots()
		"eternalchest":
			await discard_choice(p, 1)
			await roll(p, "Eternal Chest", func(v: int) -> void:
				if v == 3: coins(p, 4)
				elif v >= 4 and v <= 5: coins(p, 7)
				elif v == 6:
					await treasure(p, 1)
					await loot(p, 1))
	g._ui()

func _room_discard_named(p: Dictionary, key: String) -> bool:
	var c: Card3D = null
	for h in p.hand:
		if D.LOOT[h.id][0].to_lower().contains(key):
			c = h
	if c == null:
		await discard_choice(p, 1)
		return false
	p.hand.erase(c)
	g._discard_card(c, true)
	g._layout_hand(p)
	return true

func room_tap(p: Dictionary, r: Dictionary) -> void:
	if p.i != g.active or r.tapped:
		return
	if r.id == "guppyspieces":
		r.tapped = true
		var top: Array = []
		for i in min(5, g.treasure_ids.size()):
			top.append(g.treasure_ids.pop_back())
		var gup: Array = top.filter(func(id): return id in g.GUPPY_ITEMS or id == "guppyseye")
		if not gup.is_empty():
			var pick: String = gup[0]
			if ask(p):
				pick = await g._choose_card(gup, "Guppy's Pieces — pegar um item Guppy")
			top.erase(pick)
			g._gain_item(p, pick, g.decks.treasure.top_xf())
		top.shuffle()
		for id in top:
			g.treasure_ids.push_front(id)
		sync_decks()
		return
	# Item virado sala: o jogador ativo usa a habilidade ↷ como se fosse dele.
	var fake = {"id": r.id, "tapped": false, "card": r.card, "owner": p, "eternal": false, "counters": r.counters}
	await g._act_item(p, fake, null)
	r.tapped = bool(fake.tapped)
	r.counters = fake.counters

# Social Goals
func goal_add(p: Dictionary, key: String, k: int) -> void:
	if not room("socialgoals"):
		return
	var cur: Dictionary = goals.get(p.i, {})
	cur[key] = int(cur.get(key, 0)) + k
	goals[p.i] = cur
	if _goals_done() >= 4 and not bool(goals.get("paid", false)):
		goals["paid"] = true
		toast("Social Goals completo! Todos ganham 2 tesouros")
		for q in g.players:
			treasure(q, 2)

func _goals_done() -> int:
	var need = {"loot": 5, "kill": 3, "give": 1, "buy": 3, "six": 3}
	var done = 0
	for k in need:
		for i in [0, 1]:
			var cur: Dictionary = goals.get(i, {})
			if int(cur.get(k, 0)) >= int(need[k]):
				done += 1
				break
	return done

# =====================================================================
# MONSTROS ENTRANDO / EVENTOS / MALDIÇÕES
# =====================================================================
func on_mon_enter(m: Dictionary) -> void:
	g.last_revealed = m
	if room("redchampions"):
		m.max += 1
		m.hp += 1
	if m.id == "coil":
		toast("Coil: cada jogador passa a mão para a direita")
		g._swap_hands()

func curse_target(p: Dictionary, id: String) -> Dictionary:
	var o: Dictionary = opp(p)
	if not ask(p) or o.dead:
		return o if not o.dead else p
	var c: int = await g._choose_option("%s — dar para quem?" % D.EVENTS[id][0], [o.name.to_upper(), "VOCÊ"], 0, false, id)
	return o if c == 0 else p

func event(id: String, c: Card3D, p: Dictionary) -> void:
	var at: Vector3 = c.global_position
	var o: Dictionary = opp(p)
	if str(D.EVENTS[id][1]).contains("-Curse-"):
		var t: Dictionary = await curse_target(p, id)
		(t.curses as Array).append(id)
		toast("%s recebe %s" % [t.name, D.EVENTS[id][0]])
		return
	match id:
		"angelroom":
			await roll(p, "Angel Room", func(v: int) -> void:
				if v == 1: await treasure(p, 2)
				elif v <= 3: await treasure(p, 1)
				else: await loot(p, 2))
		"holychest":
			await roll(p, "Holy Chest", func(v: int) -> void:
				if v <= 2:
					p.prevent_amt += 2
					p.attacks += 1
				elif v <= 5: g._gain_coins(p, 7, at)
				else: g._become_soul(p))
		"spikedchest":
			await roll(p, "Spiked Chest", func(v: int) -> void:
				dmg(p, 1)
				if v >= 3 and v <= 4: await loot(p, 1)
				elif v >= 5: await treasure(p, 1))
		"headtrauma":
			g._force_discard(p, 2)
		"bossrush":
			var found: Array = []
			var rest: Array = []
			while found.size() < 2 and not g.monster_ids.is_empty():
				var mid: String = g.monster_ids.pop_back()
				if D.MONSTERS.has(mid) and int(D.MONSTERS[mid][7]) > 0:
					found.append(mid)
				else:
					rest.append(mid)
			g.monster_discard.append_array(rest)
			sync_decks()
			for mid in found:
				await place_mon(mid)
			p.attacks += 1
			p.state["must_extra"] = int(p.state.get("must_extra", 0)) + 1
		"doubletreasure":
			await treasure(p, 1)
			await treasure(o, 1)
		"dressingtable":
			if await yes(p, "Dressing Table — rerrolar seus itens?", true):
				await reroll_all(p)
		"goldentrollbomb":
			dmg(o if not o.dead else p, 2)
			g.monster_ids.insert(max(0, g.monster_ids.size() - 4), id)
			sync_decks()
		"tntbarrel":
			var t = await pick_any(p, 2, "TNT Barrel — escolha o alvo")
			await roll(p, "TNT Barrel", func(v: int) -> void:
				if t == null: return
				if v <= 4:
					dmg(p, 2)
					g._deal_to_target(t, 2, p)
				else:
					g._deal_to_target(t, 4, p))
		"betrayal":
			await roll(p, "Betrayal!", func(v: int) -> void:
				if v <= 2: g._steal_coins(p, o, 5)
				elif v <= 4: g._steal_random_loot(p, o)
				elif v == 5:
					var it = g._pick_stealable(o)
					if it != null: g._transfer_item(it, p)
				else: steal_soul(p, o))
		"lustforblood":
			lust_target = o
			p.attacks += 1
			p.state["must_player"] = 4
			toast("Lust for Blood: ataque %s (4+)" % o.name)
		"mothersshadow":
			for q in g.players:
				if most_items(q):
					await g._kill_player(q)
			g.monster_ids.insert(max(0, g.monster_ids.size() - 6), id)
			sync_decks()
		"overflow":
			for q in g.players:
				await roll(q, "Overflow!", func(v: int) -> void:
					if v <= 2:
						q.state["skip_next"] = true
						toast("%s pula o próximo turno" % q.name))
		"pitfall":
			g._cancel_turn()
		"policelineup":
			# 1×1: o único não-ativo é o culpado e o escolhido.
			await g._kill_player(o)
			await treasure(p, 1)
		"hotpotato":
			g._gain_item(p, "hotpotato", c.transform)
		"wrathofthelamb":
			steal_soul(p, o)
		"keepersrestingplace":
			keepers_rest += 1
			if keepers_rest >= 2:
				gain_soul(p, "Keeper's Resting Place")
			else:
				g.monster_ids.insert(max(0, g.monster_ids.size() - 3 - randi() % 3), id)
				sync_decks()
		"gamecrash":
			for q in g.players:
				for it in q.items.duplicate():
					await g._destroy_item(q, it)
			_mons_clear()
			for r in g.rooms.duplicate():
				await discard_room(r)
			await g._refill_slots()
		"patchnotes":
			var order: Array = g.players.duplicate()
			order.shuffle()
			var keys = ["hpc", "atc"]
			for i in order.size():
				var q: Dictionary = order[i]
				var x = await g._choose_item(q, func(it): return is_same(it.owner, q) and not g._is_eternal(it), "Patch Notes — ficha em qual item?")
				if x != null:
					x[keys[i]] = int(x.get(keys[i], 0)) + 1
					if keys[i] == "hpc":
						q.hp += 1

# =====================================================================
# LOOT
# =====================================================================
func loot_playable(id: String) -> bool:
	match id:
		"emergencycontact":
			return g.in_combat and g._find_mon(g.combat.get("uid", -1)) != null
		"muggerbean":
			var t = g._top_cancelable()
			return t != null and t.kind == "loot"
		"megabean":
			return g._top_cancelable() != null
		"magicmarker", "pills_3":
			return true
		"questioncard":
			return all_items().any(func(i): return D.ITEMS[i.id][2] in ["tap", "both"])
	return true

func on_loot_played(p: Dictionary, id: String, e: Dictionary) -> void:
	p.state["loot_n"] = int(p.state.get("loot_n", 0)) + 1
	goal_add(p, "loot", 1)
	for m in g._tops():
		if m.id == "conjoinedfatty_2":
			m.counters = int(m.counters) + 1
	# Gnawed Leaf: cancela o primeiro loot do oponente que mira o dono neste turno.
	var t = e.get("target")
	if t is Dictionary and t.get("type", "") == "player":
		var q: Dictionary = t.p
		if not is_same(q, p) and n(q, "gnawedleaf") > 0 and not bool(q.state.get("gnawed", false)):
			q.state["gnawed"] = true
			e.valid = func() -> bool: return false
			toast("Gnawed Leaf cancela %s" % D.LOOT[id][0])

func loot_effect(p: Dictionary, id: String, target, e: Dictionary) -> Callable:
	var o: Dictionary = opp(p)
	match id:
		"pills":
			return func() -> void: await roll(p, "Pills!", func(v: int) -> void:
				if v <= 2: dmg(o, 1)
				elif v <= 4: await deal_mon(p, 1)
				else: dmg(p, 1))
		"pills_2":
			return func() -> void: await roll(p, "Pills!", func(v: int) -> void:
				if v <= 2: await reroll_one(p, true, "Rerrolar um item seu")
				elif v <= 4: await reroll_one(p, false, "Rerrolar um item")
				else: await reroll_all(p))
		"pills_3":
			return func() -> void: await roll(p, "Pills!", func(v: int) -> void:
				if v <= 2:
					var x = g._top_cancelable()
					if x != null and x.kind == "loot": g._cancel_ability(p)
				elif v <= 4: g._force_discard(o, 1))
		"pills_4":
			return func() -> void: await roll(p, "Pills!", func(v: int) -> void:
				await loot(p, 3)
				if v <= 2: await hand_to_top(p, 3)
				elif v <= 4: await hand_to_top(p, 1))
		"pills_5":
			return func() -> void:
				for i in 3:
					await roll(p, "Pills! (%d/3)" % (i + 1), func(v: int) -> void:
						if v <= 2: p.temp_atk += 1
						elif v <= 4:
							p.temp_hp += 1
							p.hp += 1
						else: dmg(p, 1))
		"ansuz":
			return func() -> void: await g._reorder_top(await pick_deck(p, "Ansuz — qual deck?"), 4)
		"perthro":
			return func() -> void: await reroll_one(p, false, "Perthro — rerrolar qual item?")
		"blackrune":
			return func() -> void: await roll(p, "Black Rune", func(v: int) -> void:
				if v <= 2:
					for m in g._tops(): g._damage_monster(m, 1, p)
				elif v <= 4: await reroll_one(p, false, "Black Rune — rerrolar qual item?")
				else:
					discard_hand(p)
					await loot(p, 3))
		"getoutofjailcard":
			return func() -> void:
				jail = p.i
				toast("Os outros não podem jogar loot nem ativar itens neste turno")
		"questioncard":
			return func() -> void:
				var x = await g._choose_item(p, func(i): return D.ITEMS[i.id][2] in ["tap", "both"], "? Card — copiar a habilidade ↷ de qual item?")
				if x != null:
					var fake = {"id": x.id, "tapped": false, "card": x.card, "owner": p, "eternal": false, "counters": 0}
					await g._act_item(p, fake, null)
		"goldkey":
			return func() -> void:
				var ap: Dictionary = act()
				ap.state["deck_attacks"] = 99
				toast("%s pode atacar o deck de monstros à vontade" % ap.name)
		"aluckypenny":
			return func() -> void:
				coins(p, 1)
				p.state["x2rewards"] = true
		"stickynickel":
			return func() -> void: await roll(p, "Sticky Nickel", func(v: int) -> void:
				if v <= 3:
					if g.loot_discard.has("stickynickel"):
						g.loot_discard.erase("stickynickel")
						sync_decks()
					g._loot_to_hand(o, "stickynickel")
					toast("Sticky Nickel gruda em %s" % o.name)
				else: coins(p, 5))
		"megabomb":
			return func() -> void: g._deal_to_target(target, 2, p)
		"blackheart":
			return func() -> void: g._target_p(target, p).prevent_amt += 1
		"hagalaz":
			return func() -> void:
				var dk: String = "monster"
				if not g.room_ids.is_empty():
					dk = ["monster", "room"][await choose(p, "Hagalaz — qual deck?", ["MONSTROS", "SALAS"], 0)]
				await g._reorder_top(dk, 5)
				if dk == "room" and not g.rooms.is_empty() and await yes(p, "Hagalaz — descartar a sala?", bot_dislikes_room(g.rooms[0].id)):
					await discard_room(g.rooms[0])
				else:
					var m = await pick_mon(p, "Hagalaz — descartar qual monstro?", false, func(x): return not in_fight(x))
					if m != null:
						remove_mon(m)
						await g._refill_slots()
		"berkano":
			return func() -> void:
				var x = await g._choose_item(p, func(i): return not g._is_eternal(i), "Berkano — destruir qual item?", true)
				if x != null:
					var ow: Dictionary = x.owner
					await g._destroy_item(ow, x)
					steal_from_shop(ow)
		"algiz":
			return func() -> void: g._target_p(target, p).state["algiz"] = true
		"twoofspades":
			return func() -> void: await loot(p, o.hand.size())
		"aceofdiamonds":
			return func() -> void: coins(p, g.slots.size() + p.hand.size())
		"emergencycontact":
			return func() -> void:
				var m = g._find_mon(g.combat.get("uid", -1))
				if m != null and not m.has("player") and not m.has("obj"):
					remove_mon(m, "bottom")
					await g._refill_slots()
		"dadsnote":
			return func() -> void:
				var pool: Array = g.monster_discard.filter(func(x): return D.MONSTERS.has(x))
				for i in min(3, pool.size()):
					var mid: String = pool[pool.size() - 1 - i]
					g.monster_discard.erase(mid)
					await place_mon(mid)
		"asack":
			return func() -> void: await loot(p, 3)
		"key":
			return func() -> void:
				if await choose(p, "Key", ["+1 ataque para o jogador ativo", "Topo do deck num espaço"], 0) == 0:
					act().attacks += 1
				elif not g.monster_ids.is_empty():
					await g._reveal_into(free_slot())
		"magicmarker":
			return func() -> void:
				var r = g._top_roll()
				if r != null:
					var c: int = await choose(p, "Magic Marker — rolagem %d" % int(r.value), ["+1", "-1"], 0 if is_same(r.owner, p) else 1)
					r.value = clampi(int(r.value) + (1 if c == 0 else -1), 1, 6)
					toast("Magic Marker: %d" % r.value)
				else:
					var x = await g._choose_item(p, func(i): return int(i.counters) > 0, "Magic Marker — qual item (fichas ±1)?")
					if x != null:
						x.counters = int(x.counters) + 1
		"megabean":
			var tgt = g._top_cancelable(e.get("uid", -1))
			return func() -> void:
				if tgt != null and g.stack.has(tgt):
					var ow: Dictionary = tgt.owner
					g.stack.erase(tgt)
					if tgt.get("card") != null:
						g._discard_card(tgt.card, tgt.kind == "loot")
					toast("Mega Bean cancela %s" % tgt.name)
					if not is_same(ow, p):
						dmg(ow, 2)
		"muggerbean":
			var tgt2 = g._top_cancelable(e.get("uid", -1))
			return func() -> void:
				if tgt2 != null and g.stack.has(tgt2) and tgt2.kind == "loot":
					g.stack.erase(tgt2)
					var cc: Card3D = tgt2.card
					cc.ref = p
					cc.zone = "hand"
					p.hand.append(cc)
					cc.reparent(g.hand_root if p.i == 0 else g.opp_hand_root, true)
					g._layout_hand(p)
					toast("Mugger Bean rouba %s" % tgt2.name)
		"erawalk":
			return func() -> void: await roll(p, "Era Walk", func(v: int) -> void:
				erawalk = {"v": v, "n": 4}
				toast("Era Walk: as próximas 4 rolagens serão %d" % v))
		"crackedkey":
			return func() -> void:
				var x = await g._choose_item(p, func(i): return not g._is_eternal(i), "Cracked Key — qual item vira sala?", true)
				if x != null:
					var ow: Dictionary = x.owner
					ow.items.erase(x)
					forget_xtarget(x)
					g._layout_items(ow)
					room_slots += 1
					var r = {"id": x.id, "card": x.card, "tapped": false, "counters": int(x.counters), "state": {}}
					(x.card as Card3D).zone = "room"
					(x.card as Card3D).ref = r
					g.rooms.append(r)
					_layout_rooms()
					toast("%s virou uma sala" % D.ITEMS[x.id][0])
		"monstercard":
			return func() -> void:
				# Emboscada: a carta vira um monstro num espaço novo.
				if g.loot_discard.has("monstercard"):
					g.loot_discard.erase("monstercard")
					sync_decks()
				g._expand_monster_slots(1)
				var s: int = g.slots.size() - 1
				var c = Card3D.make("monstercard", "lootback")
				g.table.add_child(c)
				c.transform = g._slot_xf(s, 0)
				c.zone = "monster"
				c.tapped.connect(g._on_card_tapped)
				var m: Dictionary = g._make_mon("monstercard", s, c)
				c.ref = m
				g.slots[s].append(m)
				g._ui()
	return func() -> void: pass

# =====================================================================
# ITENS ATIVADOS (↷)
# =====================================================================
func item_needs_target(_id: String) -> bool:
	return false

func item_usable(id: String) -> bool:
	match id:
		"libra", "classicroller":
			return g._top_roll() != null
		"2020":
			var r = g._top_roll()
			return r != null and bool(r.get("attack", false))
		"gello":
			return g.in_combat
		"redkey":
			return not g.in_combat
		"deadweight":
			return g._top_cancelable() != null or g._top_roll() != null
	return true

func on_item_activated(p: Dictionary, _it: Dictionary) -> void:
	if room("staticshock"):
		dmg(p, 1)
	if n(p, "brokenremote") > 0 and ask(p) and not free_mons().is_empty():
		if await yes(p, "Broken Remote — descartar um monstro que não está sendo atacado?", false):
			var m = await pick_mon(p, "Broken Remote — qual monstro?", false, func(x): return not in_fight(x))
			if m != null:
				remove_mon(m)
				await g._refill_slots()

# Define e.fn para o item; false = item sem habilidade ↷ aqui.
func item_tap(p: Dictionary, it: Dictionary, _target, e: Dictionary) -> bool:
	var o: Dictionary = opp(p)
	var r = g._top_roll()
	match it.id:
		"infestation":
			e.fn = func() -> void:
				await loot(p, 2)
				await discard_choice(p, 1)
		"ceremonialblade", "bagoholes":
			e.fn = func() -> void: p.loot_plays += 1
		"siblingrivalry":
			e.fn = func() -> void:
				rival = o if p.i == g.active else p
				toast("Sibling Rivalry: %s fará rolagens no próximo ataque" % rival.name)
		"spindowndice":
			e.fn = func() -> void:
				var x = await g._choose_item(p, func(i): return not g._is_eternal(i), "Spindown Dice — destruir qual item?", true)
				if x != null:
					var ow: Dictionary = x.owner
					await g._destroy_item(ow, x)
					steal_from_shop(ow)
		"hemoptysis", "eternald6":
			e.fn = func() -> void: it.counters = int(it.counters) + 1
		"gello":
			e.fn = func() -> void:
				var m = g._find_mon(g.combat.get("uid", -1))
				if m == null or m.has("player") or m.has("obj"):
					return
				var healed: int = m.max - m.hp
				m.hp = m.max
				var others: Array = g._tops().filter(func(x): return x != m)
				if healed > 0 and not others.is_empty():
					var t = await pick_mon(p, "Gello — %d de dano em qual monstro?" % healed, true, func(x): return x != m)
					if t != null:
						g._damage_monster(t, healed, p)
				if p.i != g.active:
					g.in_combat = false
					if g.awaiting_roll:
						g.roll_requested.emit()
					act().attacks += 1
		"keepersbargain":
			e.fn = func() -> void:
				var k = 1
				if await yes(o, "Keeper's Bargain — ganhar 1¢? (%s ganha +1¢)" % p.name, true):
					coins(o, 1)
					k += 1
				coins(p, k)
		"abyss":
			e.fn = func() -> void:
				var x = await g._choose_item(p, func(i): return is_same(i.owner, p) and i != it and not g._is_eternal(i), "Abyss — destruir qual item seu?")
				if x != null:
					await g._destroy_item(p, x)
					it.counters = int(it.counters) + 1
		"deadweight":
			e.fn = func() -> void:
				for i in range(g.stack.size() - 1, -1, -1):
					var x: Dictionary = g.stack[i]
					if x.kind == "roll" and not bool(x.get("attack", false)):
						g.stack.erase(x)
						toast("Dead Weight cancela %s" % x.name)
						return
				g._cancel_ability(p)
		"lemegeton":
			e.fn = func() -> void:
				await treasure(p, 1)
				p.state["lemegeton"] = int(p.state.get("lemegeton", 0)) + 1
		"animasola":
			e.fn = func() -> void:
				it.id = "animasola_b"
				(it.card as Card3D).set_front("animasola_b")
				make_xtarget(it, "item")
				toast("Anima Sola vira The Revenant (atacável)")
		"classicroller":
			if r == null:
				return false
			e.fn = func() -> void:
				if not g.stack.has(r):
					return
				var a: int = g._rand_roll(r.owner)
				var b: int = g._rand_roll(r.owner)
				var chooser: Dictionary = opp(r.owner)
				var v: int = min(a, b)
				if ask(chooser):
					v = [a, b][await g._choose_option("Classic Roller — escolha o resultado de %s" % r.owner.name, [str(a), str(b)], 0)]
				r.value = v
				toast("Classic Roller: %d e %d → %d" % [a, b, v])
		"club":
			e.fn = func() -> void:
				var c: int = 0
				if g._top_cancelable(e.get("uid", -1)) != null:
					c = await choose(p, "Club", ["Monstro ao fundo do deck", "Cancelar habilidade/loot"], 1)
				if c == 0:
					if p.i == g.active:
						var m = await pick_mon(p, "Club — qual monstro vai ao fundo?", false, func(x): return not in_fight(x))
						if m != null:
							remove_mon(m, "bottom")
							await g._refill_slots()
				else:
					g._cancel_ability(p)
					p.state["club_off"] = true
		"libra":
			if r == null:
				return false
			e.fn = func() -> void:
				if g.stack.has(r):
					r.value = 3
					r.bonus = 0
					toast("Libra: rolagem vira 3")
		"smartfly":
			e.fn = func() -> void:
				var dk: String = await pick_deck(p, "Smart Fly — qual deck?")
				await g._peek_maybe_bottom(p, "Smart Fly", dk)
		"2020":
			if r == null:
				return false
			e.fn = func() -> void:
				if g.stack.has(r):
					r.bonus += 2
					toast("20/20: +2 no ataque")
		"rainbowbaby":
			e.fn = func() -> void:
				match await choose(p, "Rainbow Baby", ["Todos loot 1", "Todos +2¢", "Todos tomam 1 de dano"], 0 if p.hp > 1 else 1):
					0:
						for q in g.players: await loot(q, 1)
					1:
						for q in g.players: coins(q, 2)
					2:
						for q in g.players: dmg(q, 1)
		"distantadmiration":
			e.fn = func() -> void:
				if o.hand.is_empty():
					return
				var before: int = p.hand.size()
				g._give_loot(p, o)
				if p.hand.size() == before:
					return
				var c: Card3D = p.hand.back()
				toast("%s recebe %s" % [p.name, D.LOOT[c.id][0]])
				if g._loot_playable(c.id):
					var t = null
					if D.LOOT[c.id][2] == "any":
						t = await pick_any(p, 1, "Escolha o alvo de " + D.LOOT[c.id][0])
					await g._act_play_loot(p, c, t, true)
		"blackcandle":
			e.fn = func() -> void:
				var top: Array = []
				for i in min(6, g.monster_ids.size()):
					top.append(g.monster_ids.pop_back())
				for id in top.duplicate():
					if D.EVENTS.has(id) and str(D.EVENTS[id][1]).contains("Curse"):
						top.erase(id)
						var t: Dictionary = await curse_target(p, id)
						(t.curses as Array).append(id)
						toast("%s recebe %s" % [t.name, D.EVENTS[id][0]])
				for id in top:
					g.monster_ids.push_front(id)
				sync_decks()
		"redcandle":
			e.fn = func() -> void:
				var v: int = await g._choose_roll_number(p)
				var lst: Array = p.state.get("redcandle", [])
				lst.append(v)
				p.state["redcandle"] = lst
				toast("Red Candle: cada %d rolado causa 1 de dano" % v)
		"mutantspider":
			e.fn = func() -> void:
				mutant = {"chooser": p}
				toast("Mutant Spider: a próxima rolagem usa 4 dados")
		"headofkrampus":
			e.fn = func() -> void: await roll(p, "Head of Krampus", func(v: int) -> void:
				if v <= 3:
					for q in g.players: dmg(q, 1)
				else:
					for m in g._tops(): g._damage_monster(m, 1, p))
		"forgetmenow":
			e.fn = func() -> void:
				await g._destroy_item(p, it)
				for q in g.players:
					destroy_soul(q)
		"divorcepapers":
			e.fn = func() -> void:
				await g._destroy_item(p, it)
				g._steal_coins(p, o, o.coins / 2)
				for i in o.hand.size() / 2:
					g._give_loot(p, o)
				var x = g._pick_stealable(o)
				if x != null:
					g._transfer_item(x, p)
		"auctiongavel":
			e.fn = func() -> void:
				var slots_ok: Array = []
				for s in g.shop.size():
					if g.shop[s] != null:
						slots_ok.append(s)
				if slots_ok.is_empty() or o.coins <= 0:
					return
				var s: int = slots_ok[0]
				var bid = 0
				if ask(o):
					var opts = ["NÃO DAR LANCE"]
					for k in range(1, min(o.coins, 10) + 1):
						opts.append("%d¢" % k)
					bid = await g._choose_option("Leilão: %s" % D.ITEMS[g.shop[s].id][0], opts, 0, false, g.shop[s].id)
				elif o.coins >= 3:
					bid = min(o.coins, 3 + randi() % 4)
				if bid > 0:
					g._steal_coins(p, o, bid)
					var sc: Card3D = g.shop[s]
					g.shop[s] = null
					g._gain_item(o, sc.id, sc.transform)
					sc.queue_free()
					if shop_refills():
						g._shop_fill(s)
					toast("%s arremata por %d¢" % [o.name, bid])
		"birthright":
			e.fn = func() -> void:
				var x = await g._choose_item(p, func(i): return is_same(i.owner, p) and i != it and g._is_eternal(i), "Birthright — copiar qual item eterno?")
				if x != null:
					g._copy_item(it, x.id, false)
					it.no_eternal = true
		"bookofthedead":
			e.fn = func() -> void:
				var pool: Array = g.monster_discard.filter(func(x): return D.MONSTERS.has(x))
				if pool.is_empty():
					return
				var pick: String = pool.back()
				if ask(p):
					pick = await g._choose_card(pool.slice(max(0, pool.size() - 6)), "Book of the Dead — qual monstro volta?")
				g.monster_discard.erase(pick)
				await place_mon(pick)
		"friendlyball":
			e.fn = func() -> void:
				if not it.has("under"):
					it.under = []
				if (it.under as Array).is_empty():
					var m = await pick_mon(p, "Friendly Ball — capturar qual monstro?", false, func(x): return not in_fight(x))
					if m != null:
						it.under.append(m.id)
						remove_mon(m, "none")
						await g._refill_slots()
				else:
					var id: String = it.under.pop_back()
					await place_mon(id)
					var nm = g.last_revealed
					if not nm.is_empty():
						nm.must_fb = true
					act().attacks += 1
		"friendlysack":
			e.fn = func() -> void:
				var top: Array = []
				for i in min(3, g.loot_ids.size()):
					top.append(g.loot_ids.pop_back())
				sync_decks()
				if top.is_empty():
					return
				var pick: String = top[0]
				if ask(p):
					pick = await g._choose_card(top, "Friendly Sack — qual fica com você?")
				top.erase(pick)
				g._loot_to_hand(p, pick)
				for id in top:
					g._loot_to_hand(o, id)
		"handmedowns":
			e.fn = func() -> void:
				if await yes(o, "Hand-Me-Downs — lootar 1 e dar uma carta a %s?" % p.name, o.hand.size() <= 5):
					await loot(o, 1)
					g._give_loot(p, o)
		"jarofflies":
			if counters(it) <= 0:
				return false
			e.fn = func() -> void:
				var k = counters(it)
				it.counters = 0
				if k >= 3:
					await deal_mon(p, 1)
				else:
					await loot(p, 1)
		"keeperspenny":
			e.fn = func() -> void:
				it.counters = int(it.counters) + 1
				coins(p, int(it.counters))
				give_item(it, o)
		"magicskin":
			e.fn = func() -> void:
				await treasure(p, 1)
				it.counters = int(it.counters) + 1
				give_item(it, o)
		"marbles":
			e.fn = func() -> void:
				var x = await g._choose_item(p, func(i): return not g._is_eternal(i) and int(i.counters) > 0, "Marbles — qual item?")
				if x != null:
					var c: int = await choose(p, "Marbles", ["+1 ficha", "-1 ficha"], 1 if not is_same(x.owner, p) else 0)
					x.counters = max(0, int(x.counters) + (1 if c == 0 else -1))
		"membercard":
			e.fn = func() -> void:
				await g._reorder_top("treasure", 3)
				await shop_to_discard(p)
		"redkey":
			e.fn = func() -> void:
				var dk: String = "monster"
				if not g.room_ids.is_empty():
					dk = ["monster", "room"][await choose(p, "Red Key — qual deck?", ["MONSTROS", "SALAS"], 0)]
				var arr: Array = deck_arr(dk)
				var top: Array = []
				for i in min(3, arr.size()):
					top.append(arr.pop_back())
				if top.is_empty():
					return
				var pick: String = top[0]
				if ask(p):
					pick = await g._choose_card(top, "Red Key — qual entra em jogo?")
				top.erase(pick)
				for i in range(top.size() - 1, -1, -1):
					arr.push_back(top[i])
				sync_decks()
				if dk == "room":
					g.room_ids.push_back(pick)
					if not g.rooms.is_empty():
						await discard_room(g.rooms[0])
					else:
						await room_refill()
				else:
					await place_mon(pick)
		"undefined":
			e.fn = func() -> void:
				var ids: Array = []
				for s in g.shop:
					if s != null:
						ids.append(s.id)
				if ids.is_empty():
					return
				var pick: String = ids.pick_random()
				if ask(p):
					pick = await g._choose_card(ids, "Undefined — copiar qual item da loja?")
				it.keep_orig = "undefined"
				g._copy_item(it, pick, false)
				it.tapped = false
				g._layout_items(p)
		"xrayvision":
			e.fn = func() -> void:
				if p.i == 0:
					toast("Mão de %s: %s" % [o.name, hand_names(o)])
				var dk: String = await pick_deck(p, "X-Ray Vision — qual deck?")
				await g._peek_maybe_bottom(p, "X-Ray Vision", dk)
		"mamamega":
			e.fn = func() -> void:
				await g._destroy_item(p, it)
				for m in g._tops():
					g._damage_monster(m, 3, p)
				for q in g.players:
					dmg(q, 3)
		"rkey":
			e.fn = func() -> void:
				await g._destroy_item(p, it)
				for q in g.players:
					while q.soul_n > 0:
						destroy_soul(q)
				for q in g.players:
					discard_hand(q)
					await g._draw_loot(q, 3)
		"theclicker":
			e.fn = func() -> void:
				await g._destroy_item(p, it)
				await _clicker(p)
		"carbattery":
			e.fn = func() -> void:
				var k = 0
				for q in [p, o]:
					for x in q.items:
						if k < 3 and x.tapped and x != it:
							x.tapped = false
							k += 1
					g._layout_items(q)
		"blastminertnt":
			e.fn = func() -> void: await roll(p, "Blast Miner TNT!", func(v: int) -> void:
				if v <= 2: dmg(p, 1)
				else: await deal_any(p, 1, "Blast Miner — 1 de dano"))
		"themonster":
			e.fn = func() -> void:
				if g.in_combat and is_same(g.combat.get("p", null), p):
					g.in_combat = false
					if g.awaiting_roll:
						g.roll_requested.emit()
				p.hp = g._max_hp(p)
				toast("The Monster: %s cura tudo" % p.name)
		"conjoinedd6":
			e.fn = func() -> void:
				var q: Dictionary = o if await choose(p, "Conjoined D6 — quem rola um D8?", ["O OUTRO JOGADOR", "VOCÊ"], 1) == 0 else p
				q.state["d8"] = true
		"isaacslastwill":
			e.fn = func() -> void:
				var under: Array = it.get("under", [])
				if under.is_empty():
					return
				if await choose(p, "Isaac's Last Will", ["Ganhe %d¢" % under.size(), "Carta de baixo ao topo do deck"], 0) == 0:
					coins(p, under.size())
				else:
					g.treasure_ids.push_back(under.pop_back())
					sync_decks()
		"telekinesis":
			e.fn = func() -> void:
				var x = await g._choose_item(p, func(i): return is_same(i.owner, o) and not i.tapped and D.ITEMS[i.id][2] in ["tap", "both"], "Telekinesis — qual item o outro ativa?", true)
				if x != null:
					toast("Telekinesis: %s é forçado a ativar %s" % [o.name, D.ITEMS[x.id][0]])
					g._act_item(o, x)
		"dataminer":
			e.fn = func() -> void: await roll(p, "Dataminer", _r_dataminer.bind(p, it))
		"boosterpack":
			e.fn = func() -> void:
				await g._destroy_item(p, it)
				var top: Array = []
				for i in min(5, g.loot_ids.size()):
					top.append(g.loot_ids.pop_back())
				sync_decks()
				for id in top:
					var playable: bool = not D.TRINKETS.has(id) and D.LOOT[id][2] in ["", "any"] and loot_playable(id)
					if playable and await yes(p, "Booster Pack — jogar %s?" % D.LOOT[id][0], true, id):
						g._loot_to_hand(p, id)
						var c: Card3D = p.hand.back()
						var t = await pick_any(p, 1, "Alvo de " + D.LOOT[id][0]) if D.LOOT[id][2] == "any" else null
						await g._act_play_loot(p, c, t, true)
					else:
						g.loot_discard.append(id)
				sync_decks()
		"prototype":
			if not it.has("proto") or int(it.proto[0]) != 2 or p.coins < 3:
				return false
			e.fn = func() -> void:
				g._lose_coins(p, 3, true)
				await _proto_fire(p, it)
		_:
			return false
	return true

func _r_dataminer(v: int, p: Dictionary, it: Dictionary) -> void:
	match v:
		1:
			for m in g._tops(): m.atk_set = 1
		2:
			await g._destroy_item(p, it)
			p.state["atc"] = int(p.state.get("atc", 0)) + 1
		3:
			for q in g.players:
				for x in q.items: x.tapped = true
				q.char_tapped = true
				g._layout_items(q)
		4:
			p.state["hand0"] = true
		5:
			for m in g._tops(): m.atk_set = 9
		6:
			await g._destroy_item(p, it)
			p.state["atk_set"] = 9
	toast("Dataminer: %d" % v)

# The Clicker: troca de personagem (e de item inicial) por um que está fora do jogo.
func _clicker(p: Dictionary) -> void:
	var used: Array = g.players.map(func(q): return q.char)
	var pool: Array = D.CHARACTER_ORDER.filter(func(c): return not used.has(c))
	pool.shuffle()
	pool = pool.slice(0, 3)
	if pool.is_empty():
		return
	var pick: String = pool[0]
	if ask(p):
		pick = await g._choose_card(pool, "The Clicker — novo personagem")
	var old_item: String = str(D.CHARACTERS[p.char].item)
	var oi = item(p, old_item)
	if oi != null:
		p.items.erase(oi)
		forget_xtarget(oi)
		g._discard_item(oi)
	_flip_char(p, pick)
	var ni: String = str(D.CHARACTERS[pick].item)
	if D.ITEMS.has(ni):
		g._gain_item(p, ni, (p.char_card as Card3D).transform, true)
	p.hp = min(p.hp, g._max_hp(p))
	g._layout_items(p)

# Personagem: ↷ com habilidade própria (true = já tratado; senão +1 loot).
func tap_char(p: Dictionary) -> bool:
	var opts = ["Jogar um loot adicional"]
	var keys = ["loot"]
	if p.char == "thecapricious" and g.shop.any(func(s): return s != null):
		opts.append("Item da loja ao descarte")
		keys.append("shop")
	if int(p.state.get("spider", 0)) > 0:
		opts.append("Remover ficha de aranha")
		keys.append("spider")
	if n(p, "magicmushroom") > 0:
		opts.append("Ficha no Magic Mushroom")
		keys.append("mush")
	if opts.size() == 1:
		return false
	var c: int = await choose(p, p.name + " — ↷", opts, 0)
	match keys[c]:
		"shop":
			await shop_to_discard(p)
			return true
		"spider":
			p.state.spider = int(p.state.spider) - 1
			return true
		"mush":
			var mm = item(p, "magicmushroom")
			mm.counters = int(mm.counters) + 1
			return true
	return false

# =====================================================================
# ITENS PAGOS ($) — resolvem na hora, como no jogo base
# =====================================================================
func paid_needs_target(_id: String) -> bool:
	return false

func paid_usable(it: Dictionary) -> bool:
	var p: Dictionary = it.owner
	var c = counters(it)
	var off = paid_discount(p)
	match it.id:
		"bagotrash": return p.coins >= 3 - off
		"bagofcrafting": return not p.hand.is_empty() or c >= 4
		"ibs": return not p.hand.is_empty()
		"sumptorium": return c >= 2
		"hemoptysis": return c >= 1
		"balloftar", "athame": return not p.hand.is_empty()
		"batterypack": return c >= 2
		"carbattery": return p.coins >= 7 - off and it.tapped
		"hallowedground": return c >= 3 and not g.loot_discard.is_empty()
		"keeperssack", "thejar": return p.coins >= 4 - off
		"sacrificialdagger": return c >= 3
		"eternald6": return c >= 2
		"tumorball": return c >= 2
		"magicmushroom": return c >= 1
	return true

func _pay(p: Dictionary, k: int) -> bool:
	k = max(0, k - paid_discount(p))
	if p.coins < k:
		return false
	g._lose_coins(p, k, true)
	return true

func item_paid(p: Dictionary, it: Dictionary, _target) -> bool:
	if not paid_usable(it):
		return false
	if room("shadowoffamine") and int(p.state.get("abil_n", 0)) >= 1:
		toast("Shadow of Famine: só 1 habilidade por turno")
		return false
	p.state["abil_n"] = int(p.state.get("abil_n", 0)) + 1
	var o: Dictionary = opp(p)
	var c = counters(it)
	match it.id:
		"bagotrash":
			var opts = ["3¢: +1 loot", "4¢: loot 1", "6¢: 1 de dano"]
			var k: int = await choose(p, "Bag-o-Trash", opts, 1 if p.coins >= 8 else 0)
			if not _pay(p, [3, 4, 6][k]):
				return false
			match k:
				0: p.loot_plays += 1
				1: await loot(p, 1)
				2: await deal_any(p, 1, "Bag-o-Trash — 1 de dano")
		"bagofcrafting":
			if c >= 4 and (p.hand.is_empty() or await choose(p, "Bag of Crafting", ["4 fichas: +1 tesouro", "Descartar 1 loot: +1 ficha"], 0) == 0):
				it.counters = c - 4
				await treasure(p, 1)
			else:
				await discard_choice(p, 1, "Bag of Crafting — descarte 1 loot")
				it.counters = c + 1
		"ibs":
			var opts2 = ["Descartar 1: ganhe 3¢"]
			if g.in_combat and is_same(g.combat.get("p", null), p):
				opts2.append("Descartar 1: cancelar seu ataque")
			if p.hand.size() >= 2 and g._top_cancelable() != null:
				opts2.append("Descartar 2: cancelar habilidade/loot")
			var k2: int = await choose(p, "IBS", opts2, 0)
			var txt: String = opts2[k2]
			await discard_choice(p, 2 if txt.begins_with("Descartar 2") else 1)
			if txt.ends_with("3¢"):
				coins(p, 3)
			elif txt.ends_with("ataque"):
				g.in_combat = false
				if g.awaiting_roll:
					g.roll_requested.emit()
			else:
				g._cancel_ability(p)
		"sumptorium":
			var m = await pick_mon(p, "Sumptorium — qual monstro ganha -1 DC?", true)
			if m == null:
				return false
			it.counters = c - 2
			m.temp_eva = int(m.temp_eva) - 1
		"hemoptysis":
			var k3: int = 0
			if c >= 2:
				k3 = await choose(p, "Hemoptysis", ["1 ficha: AT de um monstro vira 1", "2 fichas: 1 de dano em até 2 alvos"], 1)
			if k3 == 0:
				var m2 = await pick_mon(p, "Hemoptysis — AT de qual monstro vira 1?", false)
				if m2 == null:
					return false
				it.counters = c - 1
				m2.atk_set = 1
			else:
				it.counters = c - 2
				await deal_any(p, 1, "Hemoptysis — 1º alvo")
				await deal_any(p, 1, "Hemoptysis — 2º alvo")
		"balloftar":
			var opts3 = ["Prevenir o próximo 1 de dano", "Monstro ao descarte"]
			var top = g._top_cancelable()
			if top != null and top.kind == "loot" and not is_same(top.owner, p):
				opts3.append("Copiar o loot sendo jogado")
			var k4: int = await choose(p, "Ball of Tar", opts3, 0)
			await discard_choice(p, 1)
			match k4:
				0: p.prevent_amt += 1
				1:
					var m3 = await pick_mon(p, "Ball of Tar — qual monstro vai ao descarte?", false, func(x): return not in_fight(x))
					if m3 != null:
						remove_mon(m3)
						await g._refill_slots()
				2:
					var lid: String = top.card.id
					var e2 = {"kind": "ability", "owner": p, "name": "Cópia de " + D.LOOT[lid][0], "target": top.get("target")}
					e2.fn = g._loot_effect(p, lid, top.get("target"), e2)
					g._push(e2)
		"athame":
			await discard_choice(p, 1)
			g._force_discard(o, 2)
		"experimentaltreatment":
			p.items.erase(it)
			g._layout_items(p)
			await roll(p, "Experimental Treatment", func(v: int) -> void:
				if v == 1: await g._kill_player(p)
				elif v == 2: await loot(p, 3)
				elif v == 3: coins(p, 9)
				elif v == 4: await treasure(p, 1)
				elif v == 5: await treasure(p, 2)
				if v == 6:
					p.items.append(it)
					g._item_to_soul(p, it)
				else:
					g._discard_item(it))
		"pageantboy":
			await g._destroy_item(p, it)
			await roll(p, "Pageant Boy", func(v: int) -> void: coins(p, 4 * v))
		"batterypack":
			it.counters = c - 2
			g._recharge_all(p)
		"carbattery":
			if not _pay(p, 7):
				return false
			it.tapped = false
			g._layout_items(p)
		"hallowedground":
			it.counters = c - 3
			var id: String = g.loot_discard.pop_back()
			sync_decks()
			g._loot_to_hand(p, id)
		"keeperssack":
			if not _pay(p, 4):
				return false
			give_item(it, o)
		"sacrificialdagger":
			it.counters = c - 3
			await deal_any(p, 1, "Sacrificial Dagger — 1 de dano")
		"thejar":
			if not _pay(p, 4):
				return false
			var t = await g._choose_target("The Jar — prevenir 1 de dano em quem?") if not p.bot else null
			if t != null and t.type == "monster":
				t.m.prevent_full = int(t.m.get("prevent_full", 0)) + 1
			else:
				g._target_p(t, p).prevent_amt += 1
		"eternald6":
			it.counters = c - 2
			eternal6 = true
			toast("Eternal D6: rolagens 2 e 3 viram 1 até o fim do turno")
		"tumorball":
			it.counters = c - 2
			var q: Dictionary = p
			if ask(p) and await choose(p, "Tumor Ball — proteger quem?", ["VOCÊ", o.name.to_upper()], 0) == 1:
				q = o
			q.state["tumorball"] = true
		"magicmushroom":
			it.counters = c - 1
			if await choose(p, "Magic Mushroom", ["+1 AT no próximo ataque", "Prevenir o próximo 1 de dano"], 0) == 0:
				p.state["mm_atk"] = int(p.state.get("mm_atk", 0)) + 1
			else:
				p.prevent_amt += 1
		_:
			return false
	g._layout_items(p)
	return true

# =====================================================================
# CPU
# =====================================================================
const BOT_TAP := ["infestation", "ceremonialblade", "bagoholes", "hemoptysis", "eternald6", "lemegeton", "blackcandle",
	"headofkrampus", "divorcepapers", "keepersbargain", "magicskin", "membercard", "friendlysack", "handmedowns",
	"blastminertnt", "boosterpack", "spindowndice", "rainbowbaby", "carbattery", "isaacslastwill", "smartfly", "distantadmiration"]

func bot_wants_item(p: Dictionary, it: Dictionary) -> bool:
	var o: Dictionary = opp(p)
	match it.id:
		"jarofflies": return counters(it) >= 1
		"keeperspenny": return counters(it) >= 2
		"forgetmenow", "rkey": return o.soul_n > p.soul_n
		"mamamega": return o.hp <= 3 and p.hp > 3
		"dataminer": return randf() < 0.4
		"distantadmiration": return not o.hand.is_empty()
		"isaacslastwill": return not (it.get("under", []) as Array).is_empty()
		"prototype": return it.has("proto") and int(it.proto[0]) == 2 and p.coins >= 6
	return it.id in BOT_TAP

func bot_turn_extra(p: Dictionary) -> void:
	if g.turn_over or g.game_over:
		return
	var o: Dictionary = opp(p)
	for it in p.items.duplicate():
		if g.turn_over or g.game_over or not p.items.has(it):
			break
		var mode: String = D.ITEMS[it.id][2]
		if mode == "both" and not it.tapped and bot_wants_item(p, it):
			await g._act_item(p, it)
		if not (mode in ["paid", "both"]) or not paid_usable(it):
			continue
		var c = counters(it)
		var use = false
		match it.id:
			"bagofcrafting": use = c >= 4 or p.hand.size() >= 4
			"bagotrash": use = p.coins >= 9
			"athame": use = p.hand.size() >= 3 and o.hand.size() >= 2
			"sacrificialdagger": use = true
			"batterypack": use = p.items.any(func(x): return x.tapped)
			"hallowedground": use = true
			"experimentaltreatment": use = p.hp >= 2 and randf() < 0.3
			"pageantboy": use = true
			"keeperssack": use = true
			"ibs": use = p.hand.size() >= 4
			"hemoptysis": use = c >= 2
		if use:
			await g._act_paid(p, it)
			await g._wait(0.3)
	# Salas com $
	for r in g.rooms.duplicate():
		if g.turn_over or not g.rooms.has(r):
			continue
		if room_has_paid(r.id) and room_paid_ok(p, r):
			var use2 = false
			match r.id:
				"beggar", "shellgame", "slotmachine", "fortuneteller": use2 = p.coins >= 7
				"blooddonation", "devilbeggar": use2 = p.hp >= 3
				"eternalchest", "bombbum", "keymaster": use2 = p.hand.size() >= 4
			if use2:
				await room_paid(p, r)
				await g._wait(0.3)
		if room_has_tap(r) and not r.tapped and r.id == "guppyspieces":
			await room_tap(p, r)

func bot_pick_loot(p: Dictionary) -> Dictionary:
	var o: Dictionary = opp(p)
	for c in p.hand:
		match c.id:
			"asack", "aluckypenny", "aceofdiamonds", "stickynickel", "pills", "pills_2", "pills_4", "blackrune":
				return {"card": c}
			"twoofspades":
				if o.hand.size() >= 2: return {"card": c}
			"pills_5":
				if p.hp >= 3: return {"card": c}
			"key", "goldkey":
				if p.hp >= 2: return {"card": c}
			"berkano":
				if g._pick_stealable(o) != null: return {"card": c}
			"megabomb":
				var t = await pick_any(p, 2)
				if t != null and ((t.type == "monster" and t.m.hp <= 2) or (t.type == "player" and t.p.hp <= 2)):
					return {"card": c, "target": t}
	return {}

func bot_respond(b: Dictionary, top: Dictionary, can_loot: bool) -> bool:
	if not can_loot or is_same(top.owner, b):
		return false
	if top.kind in ["loot", "ability"] and g._threatens(top, b):
		for id in ["megabean", "muggerbean"]:
			var c: Card3D = g._bot_loot_in_hand(b, id)
			if c != null and (id == "megabean" or top.kind == "loot"):
				g._act_play_loot(b, c)
				return true
	return false

# Humano simulado (autoplay): usa salas, ataca o deck e cumpre obrigações de ataque.
func sim_extra(me: Dictionary) -> void:
	if g.turn_over or g.game_over:
		return
	for r in g.rooms.duplicate():
		if g.turn_over or not g.rooms.has(r):
			continue
		if room_has_paid(r.id) and room_paid_ok(me, r) and randf() < 0.5:
			await room_paid(me, r)
		if room_has_tap(r) and not r.tapped and randf() < 0.5:
			await room_tap(me, r)
	var guard = 0
	while guard < 4 and not g.turn_over and not g.game_over and not me.dead:
		guard += 1
		var f = bot_forced_attack(me)
		if f is String and f == "deck":
			await g._act_attack_deck(me)
		elif f is Dictionary:
			await g._attack(me, f, me.attacks <= 0)
		elif me.attacks > 0 and randf() < 0.3 and not g.monster_ids.is_empty():
			await g._act_attack_deck(me)
		else:
			break
