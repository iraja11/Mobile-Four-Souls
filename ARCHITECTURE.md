# ARCHITECTURE — Four Souls Mobile (Godot 4.7, GDScript)

Adaptação digital de *The Binding of Isaac: Four Souls* (Base Game V2). 1 humano vs 1 CPU, retrato 540×960, renderer `mobile`. Texto das cartas em inglês (fiel ao físico); UI em pt-BR.

## Árvore
```
game/
├─ project.godot          # cena principal: main.tscn
├─ main.tscn              # só um Node3D com scripts/main.gd
├─ scripts/
│  ├─ main.gd   (~4.5k)   # TODO o jogo: mundo 3D, HUD, regras, efeitos, CPU, autoplay
│  ├─ data.gd             # banco de cartas (consts puras, sem lógica)
│  ├─ card3d.gd           # class_name Card3D: carta física, shaders, animações, toque
│  ├─ deck3d.gd           # class_name Deck3D: pilha de cartas na mesa
│  └─ dice3d.gd           # class_name Dice3D: dado animado
├─ assets/
│  ├─ cards/<id>.jpg      # arte por id de carta (id = chave em data.gd)
│  ├─ fonts/              # NotoSerif (UI) + DejaVuSans (fallback de símbolos)
│  └─ table.jpg
└─ tools/autoplay.sh      # partidas headless (teste de fumaça)
```
Fora de `game/` (raiz do workspace): arte bruta das coleções, sons (`tboi sounds/`), PDFs de regras (`main.pdf`), mod do TTS e `ASSET_INDEX.md` (índice dessa arte). Nada disso é carregado pelo jogo.

## Dados (`data.gd`)
| const | formato |
|---|---|
| `CHARACTERS` | `id: {name, hp, atk, item}` · ordem em `CHARACTER_ORDER` |
| `ITEMS` | `id: [nome, texto, modo, eterno]` · modo ∈ `passive tap paid both` · inclui os trinkets |
| `TREASURE_DECK` / `STARTING_ITEMS` | listas de ids |
| `TRINKETS` | loots que viram item passivo ao resolver |
| `LOOT` | `id: [nome, texto, alvo, trinket]` · alvo ∈ `"" any player roll cancel` |
| `LOOT_DECK` | `id: cópias` |
| `MONSTERS` | `id: [nome, hp, evasão, atk, ¢, loot, tesouro, almas, texto, recompensa]` · recompensa ∈ `"" rollcents rollloot` |
| `EVENTS` | `id: [nome, texto]` (entram no deck de monstros) |
| `BONUS_SOULS` | `id: [nome, texto]` |

Comportamento de monstro = tags em `main.gd › MON_TAG` (`id → [tag...]`), lidas com `_has_tag(m, tag)`.

## Estado (dicionários em `main.gd`)
- **player**: `i, char, name, bot, hp, base_hp, base_atk, coins, hand[Card3D], items[item], souls[Card3D], soul_n, char_card, char_tapped, loot_plays, attacks, bought, buy_limit, first_roll, temp_atk, temp_hp, temp_roll, prevent_full, prevent_amt, reduce_to1, shield, curses[id], state{}, dead`
- **item**: `id, tapped, card, owner, eternal, counters, trinket?, orig_id?` (orig_id = cópia temporária, desfeita em `_revert_copies`)
- **monster**: `id, uid, hp, max, eva, atk, slot, card, label, tags[], temp_atk, temp_eva, hits, reward_kind, kill_roll, double`
- **stack entry**: `kind (loot|ability|roll), owner, name, uid, bonus, fn|on_res, card?, target?, valid?`
- Decks: `loot_ids / monster_ids / treasure_ids` (topo = `back()`), descartes `loot_discard / monster_discard / treasure_discard`. Mesa: `slots[s]` (pilha por espaço, topo = `back()`), `shop[]`.

## Fluxo
```
_ready → _show_select → _new_game(char) → _turn_loop
_turn_loop: _start_phase(p) → [_bot_turn | humano até end_turn_requested] → _end_phase(p) → troca active
Ação (loot/item/ataque) → _push(entry) → _run_stack:
    loop: prioridade (humano: botão PASSAR se _human_relevant; CPU: _bot_respond) → pop → _resolve(e)
_resolve: loot → trinket? _play_trinket : descarta + e.fn() · ability → e.fn() · roll → e.on_res(v)
Ataque: _act_attack → _roll(attack) na pilha → _resolve_attack → _damage_monster/_damage_player → _kill_*
Fim da pilha → _refill_slots (revela monstros/eventos; guarda `refilling` contra reentrada)
```
Sinais internos: `priority_event`, `end_turn_requested`, `roll_requested`, `target_chosen`. Alvo do humano: `await _choose_target(...)`. Escolhas modais: `_choose_option`, `_choose_card`, `_choose_item`.

## Mapa do `main.gd` (procure pelo cabeçalho `# ===`)
| seção | responsabilidade |
|---|---|
| topo | consts, `MON_TAG`, sinais, variáveis de mundo/estado/game feel/HUD |
| MUNDO 3D | mesa, câmera, luz, velas; transforms de zona (`_hand_xf`, `_item_xf`, `_slot_xf`...) |
| HUD 2D | placas, botões, feed de mensagens (`_toast`), faixa (`_banner`), inspeção, partículas, sangue, moedas, hitstop, tremor |
| SELEÇÃO / FIM | tela de personagem e de vitória/derrota |
| SETUP DA PARTIDA | `_new_player`, `_new_game` (Eden escolhe item), modais |
| CARTAS | compra de loot, layout de mão/itens, ganhar/descartar item, trinkets (`_play_trinket`, `_discard_item`), loja |
| MONSTROS | revelar, evasão (`_eva`), eventos (`_event_resolve`), dano e morte de monstro + recompensas |
| JOGADORES | atributos derivados (`_atk`, `_roll_bonus`, `_max_hp`), moedas, dano/morte de jogador, roubo, espiar decks |
| TURNOS | `_turn_loop`, `_start_phase`, `_end_phase`, gatilhos de início/fim |
| PILHA E PRIORIDADE | `_push`, `_run_stack`, `_resolve`, rolagens (`_roll`, `_reroll`, `_roll_triggers`) |
| AÇÕES | ataque, compra, `_act_play_loot` + `_loot_effect` (efeito por id), `_act_item` / `_act_paid` (efeito por id), helpers |
| INPUT DO HUMANO | toque/arrasto de cartas, inspeção, escolha de alvo |
| CPU | `_bot_turn`, escolha de loot/itens, `_bot_respond` |
| AUTOPLAY | humano simulado para testes headless |

## Como adicionar uma carta
1. Arte em `assets/cards/<id>.jpg` (+ `.import` gerado pelo Godot).
2. Entrada em `data.gd` (tabela certa + deck).
3. Efeito: loot → caso em `_loot_effect`; item ↷ → caso em `_act_item`; item $ → `_act_paid`; passivo → onde o gatilho acontece (procure `_n(p, "<id parecido>")`); monstro → tag em `MON_TAG` + tratamento (`_mon_death_effect`, `_resolve_attack`, `_eva`...).
4. Testar: `GIVE=<id> tools/autoplay.sh 1 2` (precisa de zero `ERROR` e `GAME OVER`).

## Testes
`tools/autoplay.sh [seeds]` roda partidas completas headless (`--autoplay-human --seed=N [--give=ids]`, tempo 10×). Mensagens do jogo saem como `[log]`. Sem suíte unitária ainda.

## Convenções
- Código e comentários em pt-BR; ids de carta em minúsculas sem espaço (iguais ao nome do jpg).
- `D` = `preload("res://scripts/data.gd")`. Card3D/Deck3D/Dice3D são classes globais.
- Toda animação passa por `Card3D.fly_to/punch/shake/lunge/sheen`; efeitos visuais por `_burst`, `_splat`, `_float3d`.
- `.godot/` é cache (fora do git).
