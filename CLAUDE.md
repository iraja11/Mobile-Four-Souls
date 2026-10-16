# Four Souls Mobile — guia rápido para agentes

Leia `ARCHITECTURE.md` antes de mexer (árvore, estado, fluxo, mapa do main.gd).

- Godot 4.7.2: binário em `../Godot_v4.7.2-stable_linux.x86_64`.
- Depois de qualquer mudança em `scripts/`: `tools/autoplay.sh 1 2 3` tem que terminar com `erros=0` e `GAME OVER` em todas as seeds. Para testar uma carta específica: `GIVE=id1,id2 tools/autoplay.sh 1 2`.
- `scripts/main.gd` é grande: use grep pelos cabeçalhos `# ===` e pelo id da carta em vez de ler o arquivo inteiro.
- Não leia `assets/cards/` nem `.godot/` (binário/cache). O texto das cartas está em `scripts/data.gd`.
- Fidelidade às regras oficiais: `../main.pdf`. Arte bruta e sons ficam fora de `game/` (ver `../ASSET_INDEX.md`).
- UI em pt-BR; texto das cartas em inglês, como no físico.
