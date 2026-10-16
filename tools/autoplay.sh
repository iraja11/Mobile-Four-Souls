#!/bin/bash
# Teste de fumaça: partidas completas headless (humano simulado vs CPU), em paralelo.
# Uso: tools/autoplay.sh [seed ...]   (padrão: 1 2)   Saída: resumo por seed + erros agregados.
# GIVE=id,id dá cartas ao jogador simulado (ex.: GIVE=thed20,placebo,cainseye).
# GODOT=caminho/do/binário sobrescreve o padrão (../Godot_v4.7.2-stable_linux.x86_64).
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-../Godot_v4.7.2-stable_linux.x86_64}"
LOG="${TMPDIR:-/tmp}/fs_autoplay"; mkdir -p "$LOG"
SEEDS=("$@"); [ ${#SEEDS[@]} -eq 0 ] && SEEDS=(1 2)
for s in "${SEEDS[@]}"; do
	timeout "${TIMEOUT:-165}" "$GODOT" --headless --path . -- --autoplay-human --seed="$s" ${GIVE:+--give=$GIVE} > "$LOG/s$s.log" 2>&1 &
done
wait
fail=0
for s in "${SEEDS[@]}"; do
	e=$(grep -c "ERROR" "$LOG/s$s.log"); [ "$e" -gt 0 ] && fail=1
	g=$(grep -o "GAME OVER.*" "$LOG/s$s.log" || echo "SEM FIM (timeout?)")
	echo "seed $s · erros=$e · $g"
done
grep -h -A2 "ERROR" "$LOG"/s*.log | grep -v '^--' | sort | uniq -c | sort -rn | head -20
exit $fail
