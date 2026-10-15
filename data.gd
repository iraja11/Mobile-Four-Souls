extends RefCounted
# Dados das cartas — textos e stats das cartas originais (Base Game V2).

const SOULS_TO_WIN := 4
const SHOP_PRICE := 10
const START_COINS := 3
const START_LOOT := 3
const HAND_LIMIT := 10

const CHARACTERS := {
	"isaac": {"name": "Isaac", "hp": 2, "atk": 1, "item": "d6"},
	"maggy": {"name": "Maggy", "hp": 2, "atk": 1, "item": "yumheart"},
}

# id: [nome, texto, "tap" | "passive", eterno]
const ITEMS := {
	"d6": ["The D6", "Escolha uma rolagem de dado. Ela é rerrolada.", "tap", true],
	"yumheart": ["Yum Heart", "Previne a próxima instância de dano que você levaria neste turno.", "tap", true],
	"meat": ["Meat!", "+1 nas suas rolagens de ataque.", "passive", false],
	"synthoil": ["Synthoil", "+1 nas suas rolagens de ataque.", "passive", false],
	"booksin": ["Book of Sin", "Rola — 1-2: +1¢ · 3-4: loot 1 · 5-6: +1♥ até o fim do turno.", "tap", false],
	"spoon": ["Spoon Bender", "Adiciona 1 a uma rolagem.", "tap", false],
	"breakfast": ["Breakfast", "+1♥.", "passive", false],
	"dinner": ["Dinner", "+1♥.", "passive", false],
	"brimstone": ["Brimstone", "+1⚔. Ao causar dano de combate a um monstro, causa 1 de dano ao oponente.", "passive", false],
	"championbelt": ["Champion Belt", "+1⚔ na primeira rolagem de ataque do turno. Pode atacar uma vez a mais.", "passive", false],
	"polydactyly": ["Polydactyly", "Pode jogar um loot a mais no seu turno. +1⚔ na primeira rolagem de ataque.", "passive", false],
	"sacredheart": ["Sacred Heart", "Quando você rolaria 1, o resultado vira 6.", "passive", false],
	"momsrazor": ["Mom's Razor", "Cada vez que um oponente rola 6, causa 1 de dano a ele.", "passive", false],
	"relic": ["The Relic", "Cada vez que um jogador rola 1, você faz loot 1.", "passive", false],
	"guppyshead": ["Guppy's Head", "O oponente te dá uma carta de loot.", "tap", false],
	"razorblade": ["Razor Blade", "Causa 1 de dano a um jogador.", "tap", false],
	"sackofpennies": ["Sack of Pennies", "Ganhe 1¢. Quando um jogador rola 1, recarrega.", "tap", false],
}
const TREASURE_DECK := ["meat", "synthoil", "booksin", "spoon", "breakfast", "dinner", "brimstone",
	"championbelt", "polydactyly", "sacredheart", "momsrazor", "relic", "guppyshead", "razorblade", "sackofpennies"]

# id: [nome, texto, precisa de alvo]
const LOOT := {
	"penny": ["A Penny!", "Ganhe 1¢.", ""],
	"twocents": ["2 Cents!", "Ganhe 2¢.", ""],
	"threecents": ["3 Cents!", "Ganhe 3¢.", ""],
	"fourcents": ["4 Cents!", "Ganhe 4¢.", ""],
	"nickel": ["A Nickel", "Ganhe 5¢.", ""],
	"dime": ["A Dime!!", "Ganhe 10¢.", ""],
	"bomb": ["Bomb!", "Causa 1 de dano a um monstro ou jogador.", "any"],
	"goldbomb": ["Gold Bomb!!", "Causa 3 de dano a um monstro ou jogador.", "any"],
	"battery": ["Lil Battery", "Recarrega um item.", ""],
	"megabattery": ["Mega Battery", "Recarrega todos os seus itens.", ""],
	"diceshard": ["Dice Shard", "Escolha uma rolagem de dado. Ela é rerrolada.", "roll"],
	"butterbean": ["Butter Bean!", "Cancela uma habilidade de item ou loot sendo jogado.", "cancel"],
	"soulheart": ["Soul Heart", "Previne o próximo 1 de dano que você levaria neste turno.", ""],
	"pills": ["Pills!", "Rola — 1-2: +1⚔ · 3-4: +1♥ até o fim do turno · 5-6: leve 1 de dano.", ""],
	"strength": ["XI. Strength", "+1⚔ até o fim do turno e pode atacar uma vez a mais.", ""],
}
const LOOT_DECK := {
	"penny": 5, "twocents": 4, "threecents": 3, "fourcents": 2, "nickel": 3, "dime": 1,
	"bomb": 4, "goldbomb": 1, "battery": 3, "megabattery": 1, "diceshard": 3,
	"butterbean": 3, "soulheart": 2, "pills": 3, "strength": 1,
}

# id: [nome, hp, evasão, ataque, ¢, loot, tesouro, almas, tag]
const MONSTERS := {
	"fly": ["Fly", 1, 2, 1, 1, 0, 0, 0, ""],
	"dip": ["Dip", 1, 4, 1, 1, 0, 0, 0, ""],
	"spider": ["Spider", 1, 4, 1, 0, 1, 0, 0, ""],
	"pooter": ["Pooter", 2, 3, 1, 0, 1, 0, 0, ""],
	"trite": ["Trite", 1, 5, 1, 0, 2, 0, 0, ""],
	"horf": ["Horf", 1, 4, 1, 3, 0, 0, 0, "plus2"],
	"hopper": ["Hopper", 2, 3, 1, 3, 0, 0, 0, "immune6"],
	"clotty": ["Clotty", 2, 3, 1, 4, 0, 0, 0, ""],
	"squirt": ["Squirt", 2, 3, 1, 0, 1, 0, 0, ""],
	"mulligan": ["Mulligan", 1, 3, 1, 3, 0, 0, 0, ""],
	"boomfly": ["Boom Fly", 1, 4, 1, 4, 0, 0, 0, "boom"],
	"codworm": ["Cod Worm", 2, 5, 0, 3, 0, 0, 0, ""],
	"leaper": ["Leaper", 2, 4, 1, 5, 0, 0, 0, "dbl1"],
	"fatty": ["Fatty", 4, 2, 1, 0, 1, 0, 0, ""],
	"palefatty": ["Pale Fatty", 4, 3, 1, 6, 0, 0, 0, ""],
	"fatbat": ["Fat Bat", 3, 5, 1, 0, 0, 1, 0, ""],
	"leech": ["Leech", 1, 4, 2, 0, 1, 0, 0, ""],
	"dinga": ["Dinga", 3, 3, 1, 4, 0, 0, 0, ""],
	"blackbony": ["Black Bony", 3, 4, 1, 0, 2, 0, 0, "bony"],
	"bigspider": ["Big Spider", 3, 4, 1, 0, 1, 0, 0, ""],
	"ragecreep": ["Rage Creep", 1, 5, 1, 0, 2, 0, 0, ""],
	"redhost": ["Red Host", 2, 3, 2, 5, 0, 0, 0, ""],
	"wizoob": ["Wizoob", 3, 5, 1, 0, 3, 0, 0, ""],
	"megafatty": ["Mega Fatty", 3, 3, 1, 0, 2, 0, 1, "lifesteal"],
	"monstro": ["Monstro", 4, 4, 1, 6, 0, 0, 1, ""],
	"larryjr": ["Larry Jr.", 4, 3, 1, 6, 0, 0, 1, "larry"],
	"gurdyjr": ["Gurdy Jr.", 2, 5, 1, 0, 0, 1, 1, "gurdyjr"],
	"pin": ["Pin", 2, 4, 1, 5, 0, 0, 1, "immune6"],
	"gurdy": ["Gurdy", 5, 4, 1, 7, 0, 0, 1, ""],
	"peep": ["Peep", 3, 4, 1, 0, 0, 1, 1, ""],
	"chub": ["Chub", 4, 3, 1, 7, 0, 0, 1, "chub"],
	"carrionqueen": ["Carrion Queen", 3, 4, 1, 0, 0, 1, 1, "immune45"],
	"littlehorn": ["Little Horn", 2, 6, 1, 0, 2, 0, 1, ""],
	"darkone": ["Dark One", 3, 4, 1, 0, 0, 1, 1, ""],
	"duke": ["The Duke of Flies", 4, 3, 1, 0, 2, 0, 1, "duke"],
	"daddylonglegs": ["Daddy Long Legs", 4, 4, 1, 7, 0, 0, 1, ""],
	"bloat": ["The Bloat", 4, 4, 2, 0, 0, 1, 1, ""],
	"mom": ["Mom!", 5, 4, 2, 0, 0, 1, 2, "dbl1"],
}
const EVENTS := {
	"chest": ["Chest", "Rola — 1-2: +1¢ · 3-4: +3¢ · 5-6: +6¢"],
}
const MONSTER_EXTRA := ["chest", "chest", "chest"]

const TAG_TEXT := {
	"plus2": "Rolagem de ataque 2: causa +1 de dano.",
	"immune6": "Não leva dano de combate em rolagens de 6.",
	"immune45": "Não leva dano de combate em rolagens de 4 ou 5.",
	"dbl1": "Rolagem de ataque 1: dano de combate dobrado.",
	"boom": "Ao morrer, causa 1 de dano a cada jogador.",
	"bony": "Ao morrer, causa 1 de dano a quem o matou.",
	"lifesteal": "Cada vez que causa dano de combate, cura 1♥.",
	"larry": "Com 2♥ ou menos, tem +1 de evasão.",
	"gurdyjr": "Cada vez que o atacante ativa um item, leva 1 de dano.",
	"chub": "Rolagem de ataque 1: cura 2♥.",
	"duke": "Ao levar dano, o atacante rola — 1: previne o dano.",
}
