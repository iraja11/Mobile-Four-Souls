# ARCHITECTURE — Four Souls Mobile (Godot 4.7, GDScript)

Adaptação digital de *The Binding of Isaac: Four Souls* (Base Game V2 + Four Souls+, Requiem, Summer of Isaac e Anniversary). 1 humano vs 1 CPU, retrato 540×960, renderer `mobile`. Texto das cartas em inglês (fiel ao físico); UI em pt-BR.

## Árvore
```
game/
├─ project.godot          # cena inicial: menu.tscn · autoload Settings, Sfx
├─ menu.tscn              # só um Control com scripts/menu.gd
├─ select.tscn            # só um Control com scripts/select.gd
├─ main.tscn              # só um Node3D com scripts/main.gd (partida)
├─ scripts/
│  ├─ menu.gd             # menu principal: Novo Jogo → select.tscn · Opções (volumes, tela cheia) · classe Scrawl
│  ├─ select.gd           # seleção de personagem (anel girável, atributos/item, "?" aleatório, sequência de vitórias) + perfil
│  ├─ settings.gd         # autoload Settings: opções em user://settings.cfg, buses Master/Music/SFX
│  ├─ sfx.gd              # autoload Sfx: tabela evento→amostras, variação, cooldown, vozes, limitador
│  ├─ main.gd   (~5k)     # o jogo: mundo 3D, HUD, regras, efeitos do Base Game, CPU, autoplay
│  ├─ xp.gd     (~3.9k)   # cartas das expansões: ganchos chamados pelo main (`xp.<gancho>`), efeito por id
│  ├─ data.gd             # banco de cartas (consts puras, sem lógica)
│  ├─ card3d.gd           # class_name Card3D: carta física, shaders, animações, toque
│  ├─ deck3d.gd           # class_name Deck3D: pilha de cartas na mesa
│  └─ dice3d.gd           # class_name Dice3D: dado animado
├─ assets/
│  ├─ cards/<id>.jpg      # arte por id (id = chave em data.gd), 560px de largura (base antiga: 400); import lossy WebP 0.8
│  │                      # salas: arte guardada em pé (girada 90°); mesa e inspeção desviram
│  ├─ fonts/              # NotoSerif (UI da partida) + DejaVuSans (fallback) + Upheaval (menu, pixel)
│  ├─ sfx/<nome>.wav      # efeitos escolhidos de ../tboi sounds (minúsculas, espaço→_)
│  ├─ ui/                 # logo + recortes da UI do TBOI (quadros de papel, seta, rabiscos) usados no menu
│  │  ├─ select/          # recortes de charactermenu.png: quadro "WHO AM I?", nomes, setas, ícones ♥/espada, "?", sangue
│  │  └─ hud/             # HUD da partida: heart/skull/coin, die.png (faces 1..6 do dado vermelho), paper/paper_s/scrap (nine-patch de seedentry.png sem rabiscos)
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
| `BONUS_SOULS` | `id: [nome, texto]` · 3 das 8 sorteadas por partida (`xp.setup`) |
| `ROOMS` | `id: [nome, texto]` (Requiem; deck de salas + 1 espaço) |
| `ATTACKABLE` | formato de `MONSTERS` para o que pode ser atacado sem ser monstro (itens, salas, Monster Card) |
| `OUTSIDE` | monstros fora do deck (The Harbingers / The Beast) |

Comportamento de monstro = tags em `main.gd › MON_TAG` (`id → [tag...]`), lidas com `_has_tag(m, tag)`; os monstros das expansões são tratados por id em `xp.gd`.
Colisões de id com o base: `bumbochar`, `isaacboss`, `daddylonglegsitem`, `edensblessingroom`, `bloodlustroom`, `questioncard`, `nullmon`, `<monstro>_2` (versões Summer). Loots repetidos só somam cópias em `LOOT_DECK`.

## Estado (dicionários em `main.gd`)
- **player**: `i, char, name, bot, hp, base_hp, base_atk, coins, hand[Card3D], items[item], souls[Card3D], soul_n, char_card, char_tapped, loot_plays, attacks, bought, buy_limit, first_roll, temp_atk, temp_hp, temp_roll, prevent_full, prevent_amt, reduce_to1, shield, curses[id], state{}, dead`
- **item**: `id, tapped, card, owner, eternal, counters, trinket?, orig_id?` (orig_id = cópia temporária, desfeita em `_revert_copies`)
- **monster**: `id, uid, hp, max, eva, atk, slot, card, label, tags[], temp_atk, temp_eva, hits, reward_kind, kill_roll, double`
- **stack entry**: `kind (loot|ability|roll), owner, name, uid, bonus, fn|on_res, card?, target?, valid?`
- Decks: `loot_ids / monster_ids / treasure_ids / room_ids` (topo = `back()`; o deck de monstros inclui os eventos), descartes `loot_discard / monster_discard / treasure_discard / room_discard`. Mesa: `slots[s]` (pilha por espaço, topo = `back()`), `shop[]`, `rooms[]` (`{id, card, tapped, counters}`).
- `xtargets[]`: pseudo-monstros atacáveis (`obj` = item/sala/alma, ou `player` = jogador atacado); `_find_mon` também os encontra, `_tops()` não.
- Fichas: `it.counters` (genéricas), `hpc`/`atc` (HP/AT), `gold`, `eternal_ctr`, `under[]`; por jogador em `p.state` (por turno: limpos em `xp.on_cleanup`).

## Fluxo
```
menu.tscn: Novo Jogo → select.tscn → main.tscn · Opções ↔ quadro de opções (salva ao voltar) · --autoplay* pula direto p/ main.tscn
select.tscn: escolhe → Sel.chosen/random_mode (statics) · ‹ VOLTAR → menu
main._ready → _new_game(Sel.pick()) → _turn_loop   (Sel.pick re-sorteia no "jogar novamente" se veio do "?")
_turn_loop: _start_phase(p) → [_bot_turn | humano até end_turn_requested] → _end_phase(p) → troca active
Ação (loot/item/ataque) → _push(entry) → _run_stack:
	loop: prioridade (humano: botão PASSAR se _human_relevant; CPU: _bot_respond) → pop → _resolve(e)
_resolve: loot → trinket? _play_trinket : descarta + e.fn() · ability → e.fn() · roll → e.on_res(v)
Ataque: _act_attack(slot) / _act_attack_deck (topo do deck cobre um espaço) / _attack(alvo) → _roll(attack) na pilha → _resolve_attack → _damage_monster/_damage_player → _kill_*
	Team Up: `combat.team` rola contra o mesmo alvo depois de cada rolagem do atacante. Obrigações de ataque: `xp.must_attack_reason`.
Fim da pilha → _refill_slots (revela monstros/eventos; guarda `refilling` contra reentrada)
```
Sinais internos: `priority_event`, `end_turn_requested`, `roll_requested`, `target_chosen`. Alvo do humano: `await _choose_target(...)`. Escolhas modais: `_choose_option`, `_choose_card`, `_choose_item`.

## Mapa do `main.gd` (procure pelo cabeçalho `# ===`)
| seção | responsabilidade |
|---|---|
| topo | consts, `MON_TAG`, sinais, variáveis de mundo/estado/game feel/HUD |
| MUNDO 3D | câmera, luz; mesa (`_table_material`: table.jpg em escala real + relevo/veio), tapete (`_mat_material`: zonas impressas — atualizar se mudar posição de zona — costura, pentagrama), velas em pratos (`_candle_dish`/`_candle`, chama em shader), moedas (`_coin_pile`); props só na faixa de madeira do topo; transforms de zona (`_hand_xf`, `_item_xf`, `_slot_xf`...) |
| HUD 2D | estilo papel/tinta (`_paper`, `_ulbl`, `_icon`, `_ic`/`_ic_die` p/ BBCode), placas (`SoulPips`), botões, pausa, feed (`_toast`), faixa (`_banner`), inspeção (`insp_forced` = escolha obrigatória; carta 2D usa `_card_mat` = cantos/borda da Card3D), partículas, sangue, moedas, hitstop, tremor |
| FIM DE JOGO | vitória/derrota: `Sel.record` (sequência + vitórias por personagem), JOGAR NOVAMENTE / PERSONAGEM |
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

## Ganchos `xp.*` (onde o main chama)
modificadores (`atk_mod`, `hp_mod`, `eva_mod`, `mon_atk_mod`, `price_off`, `loot_amount`, `coin_amount`...) · turno (`recharge_step`, `on_turn_start` antes do passo de loot, `on_turn_end`, `on_cleanup`, `after_end` = troca de sala) · rolagem (`adjust_roll` antes do dado, `change_roll` depois, `roll_triggers`) · combate (`can_attack`, `on_attack_declared`, `combat_immune`, `combat_dmg`, `player_combat_dmg`, `on_combat_hit`, `on_attack_miss`, `after_attack_roll`) · dano/morte (`pre_*_damage`, `on_*_damaged`, `prevent_mon_death`, `on_mon_killed`, `prevent_death`, `before_penalties`, `penalty_item`, `after_death`) · cartas (`loot_effect`, `item_tap`, `item_paid`, `event`, `on_item_enter`, `on_destroy`, `room_enter`, `room_paid`) · CPU (`bot_*`, `sim_extra`).

## Como adicionar uma carta
1. Arte em `assets/cards/<id>.jpg` (+ `.import` gerado pelo Godot).
2. Entrada em `data.gd` (tabela certa + deck).
3. Efeito: Base Game no `main.gd` (`_loot_effect`, `_act_item`, `_act_paid`, `MON_TAG`...); expansões no gancho certo do `xp.gd` (`match` por id). Passivo → no gancho do gatilho (procure `n(p, "<id parecido>")`).
4. Testar: `GIVE=<id> tools/autoplay.sh 1 2` (precisa de zero `ERROR` e `GAME OVER`). `GIVE` aceita item, loot, monstro/evento (vai ao topo do deck) e sala (entra no espaço).

## Testes
`tools/autoplay.sh [seeds]` roda partidas completas headless (`--autoplay-human --seed=N [--give=ids]`, tempo 10×). Mensagens do jogo saem como `[log]`. Sem suíte unitária ainda.
Lote de todas as cartas: `GIVE` com ~6 ids por partida (ids via `data.gd`), seeds 1 e 2. Avisos `... at exit` são do `quit()` no GAME OVER e o `autoplay.sh` os ignora.
APK: preset `Android` em `export_presets.cfg` (arm64, sem gradle; precisa ETC2/ASTC ligado) → `../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --export-debug Android ../build/FourSouls.apk` (SDK em `~/Android/Sdk`, keystore de debug do Godot).
Revisão visual: sem `--headless`, `--resolution 540x960 -- --autoplay-human --seed=N --shots=DIR` salva uma captura a cada 1,5 s (tempo 2×).

## Convenções
- Código e comentários em pt-BR; ids de carta em minúsculas sem espaço (iguais ao nome do jpg).
- evite use ferramentas de busca global (como grep, find ou list_files) a menos que explicitamente solicitado pelo usuário.
- Limite-se consideravelmente a ler e modificar os arquivos fornecidos diretamente nos prompts do usuário.
- Otimize tokens, nao perca tempo e processamento em processos desnecessarios e/ou redundantes
- `D` = `preload("res://scripts/data.gd")`. Card3D/Deck3D/Dice3D são classes globais.
- Toda animação passa por `Card3D.fly_to/punch/shake/lunge/sheen`; efeitos visuais por `_burst`, `_splat`, `_float3d`.
- `.godot/` é cache (fora do git).
- Som: sempre `Sfx.play("evento")` (ou `Sfx.later`, `Sfx.riffle`); evento novo = linha em `sfx.gd › EV` `[amostras, dB, ±pitch, cooldown, vozes]` + wav em `assets/sfx/`. Nada de AudioStreamPlayer solto. Ganchos: `_btn` (clique), `Card3D.fly_to` (deslize se distância > 0.6), `press_pulse`, `Dice3D.throw` (quiques), `_float3d` ("Prevenido"/"ERROU"/"IMUNE"), `_plate_feedback` (cura) e as funções de regra (dano, morte, moedas, alma, compra...). Em headless o Sfx não toca (só valida). Eventos `char_*` prontos para a tela de seleção. Bus Music ainda sem uso (não há trilha na lista).
- Menu: estilo "tinta no papel" em `menu.gd` (Upheaval desenhada letra a letra torta pela classe `Scrawl`, traços do sprite como trilho de slider); a seleção (`select.gd`) reusa `Scrawl` e desenha bilhetes/tachinhas (`Note`/`Tack`) no mesmo estilo; a partida usa o mesmo vocabulário: papel rasgado (`_paper`), tinta (`INK*`), Upheaval (`font_ui`) e ícones de `assets/ui/hud/`; NotoSerif só para texto longo de carta. Cor de aviso pensada p/ fundo escuro passa por `_ink_of`.
