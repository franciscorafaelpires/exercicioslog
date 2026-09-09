#!/usr/bin/env bash

# Exercício 18 - Monitora tentativas de login falhas em tempo real,
# exibindo a linha de log imediatamente após o evento ocorrer.
#
# Implementação:
#   - "tail -f" segue o arquivo de log continuamente.
#   - "grep --line-buffered" filtra em tempo real sem bufferizar a saída.
#   - Se o log não existir, usa "journalctl -f" (follow mode do journal).
#
# Para encerrar o monitoramento pressione Ctrl+C.

echo "Monitoramento em tempo real — tentativas de login falhas"
echo "=========================================================="
echo "Pressione Ctrl+C para encerrar."
echo ""

# Padrão de regex para capturar tentativas de autenticação falhas.
PADRAO="Failed password|authentication failure|FAILED LOGIN|Invalid user"

if [[ -f /var/log/auth.log ]]; then
    LOG="/var/log/auth.log"
elif [[ -f /var/log/secure ]]; then
    LOG="/var/log/secure"
else
    LOG=""
fi

if [[ -n "$LOG" ]]; then
    echo "Fonte: $LOG (tail -f)"
    echo "---"

    # --line-buffered garante que cada linha filtrada seja impressa imediatamente,
    # sem esperar o buffer ser preenchido — fundamental para monitoramento em tempo real.
    tail -f "$LOG" | grep --line-buffered -E "$PADRAO" | \
        awk '{
            # Formata a saída para destacar os campos mais importantes.
            data = $1 " " $2 " " $3

            # Extrai usuário
            usuario = "?"
            for (i = 1; i <= NF; i++) {
                if ($i == "for" && $(i+1) == "invalid" && $(i+2) == "user") {
                    usuario = $(i+3); break
                } else if ($i == "for" && $(i+1) != "invalid" && $(i+1) != "") {
                    usuario = $(i+1); break
                }
            }

            printf "[%s] Usuário: %-20s | %s\n", data, usuario, $0
        }'

else
    echo "Fonte: journalctl -f"
    echo "---"

    # journalctl -f equivale ao "tail -f" para o journal do systemd.
    journalctl -f 2>/dev/null | grep --line-buffered -E "$PADRAO" | \
        awk '{
            printf "[TEMPO REAL] %s\n", $0
        }'
fi

