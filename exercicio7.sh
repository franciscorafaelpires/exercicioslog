#!/usr/bin/env bash

# Exercício 7 - Lista todos os eventos de desligamento (shutdown) ou
# reinicialização (reboot) registrados no sistema.
#
# Fontes usadas:
#   1. /var/log/wtmp  → lido com "last", que distingue "reboot" de "shutdown".
#   2. journalctl     → fallback quando wtmp não está disponível.

echo "Eventos de desligamento e reinicialização"
echo "========================================="

if command -v last >/dev/null 2>&1 && [[ -r /var/log/wtmp ]]; then
    echo "Fonte: /var/log/wtmp"
    echo ""

    # "last" registra entradas "reboot" para boots e "shutdown" para desligamentos.
    # -F exibe a data completa; -w evita truncar nomes de host.
    last -F -w 2>/dev/null | \
        awk '$1 ~ /^(reboot|shutdown)$/ {
            tipo = ($1 == "reboot") ? "REINICIALIZAÇÃO" : "DESLIGAMENTO   "
            # Campos 3 em diante são data/hora nos logs com -F
            printf "Tipo: %s | Data/hora: %s %s %s %s %s\n",
                   tipo, $3, $4, $5, $6, $7
        }'
else
    # Fallback: journalctl. O systemd registra eventos de boot e desligamento
    # com IDs de mensagem específicos:
    #   6bbd2fd6... → "System is powering down"
    #   7d4958e8... → "System is rebooting"
    #   1dee0369... → "Reached target Shutdown"
    if command -v journalctl >/dev/null 2>&1; then
        echo "Fonte: journalctl"
        echo ""

        journalctl -o short-iso 2>/dev/null | \
            grep -Ei "systemd-shutdown|system is (rebooting|powering down)|reached target (system )?(shutdown|reboot)|starting reboot" | \
            awk '{
                tipo = ($0 ~ /[Rr]eboot/) ? "REINICIALIZAÇÃO" : "DESLIGAMENTO   "
                printf "Tipo: %s | %s\n", tipo, $0
            }'
    else
        echo "Erro: nenhuma fonte disponível (last/wtmp ou journalctl)." >&2
        exit 1
    fi
fi
