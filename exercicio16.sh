#!/usr/bin/env bash

# Exercício 16 - Conta a frequência de mensagens por serviço/processo nos logs
# e lista em ordem decrescente, identificando qual serviço gera mais logs.
#
# Fontes:
#   1. journalctl    → campo _COMM ou SYSLOG_IDENTIFIER = nome do serviço.
#   2. /var/log/syslog ou /var/log/messages → campo 5 é "serviço[pid]:".

echo "Frequência de mensagens por serviço (ordem decrescente)"
echo "========================================================="

if command -v journalctl >/dev/null 2>&1; then
    echo "Fonte: journalctl"
    echo ""
    printf "%-10s %-40s\n" "Mensagens" "Serviço"
    echo "----------+----------------------------------------"

    # -o short-iso: formato "timestamp hostname servico[pid]: mensagem".
    journalctl -o short-iso --no-pager 2>/dev/null | \
        grep -v "^--" | \
        awk '
            NF >= 5 {
                # No formato short-iso, o campo 3 é "servico[pid]:".
                servico = $3
                gsub(/\[.*/, "", servico)   # remove [pid]
                gsub(/:$/, "",  servico)    # remove ":" final
                if (servico != "") contagem[servico]++
            }
        END {
            for (s in contagem) print contagem[s], s
        }' | sort -k1,1nr | head -30 | \
        awk '{printf "%-10s %s\n", $1, $2}'

else
    # Fallback: arquivo de log de texto
    for LOG in /var/log/syslog /var/log/messages; do
        if [[ -r "$LOG" ]]; then
            echo "Fonte: $LOG"
            echo ""
            printf "%-10s %-40s\n" "Mensagens" "Serviço"
            echo "----------+----------------------------------------"

            # Logs clássicos: "Mmm DD HH:MM:SS host servico[pid]: msg"
            awk '
                NF >= 5 {
                    servico = $5
                    gsub(/\[.*/, "", servico)
                    gsub(/:$/, "",  servico)
                    if (servico != "") contagem[servico]++
                }
            END {
                for (s in contagem) print contagem[s], s
            }' "$LOG" | sort -k1,1nr | head -30 | \
            awk '{printf "%-10s %s\n", $1, $2}'

            exit 0
        fi
    done
    echo "Nenhuma fonte disponível." >&2
    exit 1
fi
