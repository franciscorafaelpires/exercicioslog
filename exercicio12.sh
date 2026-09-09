#!/usr/bin/env bash

# Exercício 12 - Identifica todos os pacotes que foram removidos do sistema.
#
# Fontes usadas:
#   - /var/log/dpkg.log       → registra ações "remove" e "purge" por pacote.
#   - /var/log/apt/history.log → agrupa removals por transação do apt.

LOG_DPKG="/var/log/dpkg.log"
LOG_APT="/var/log/apt/history.log"

echo "Pacotes removidos do sistema"
echo "=============================="

if [[ -r "$LOG_DPKG" ]]; then
    echo "Fonte: $LOG_DPKG"
    echo ""
    echo "Data/hora            Ação    Pacote"
    echo "--------------------+--------+------------------------------------------"

    # O dpkg.log registra uma linha por pacote.
    # Ações relevantes: "remove" (remoção simples) e "purge" (remove + conf).
    grep -E " (remove|purge) " "$LOG_DPKG" | \
        awk '
            $3 == "remove" || $3 == "purge" {
                split($4, p, ":")          # separa o nome da arquitetura
                acao = ($3 == "purge") ? "PURGE  " : "REMOVE "
                printf "%-20s %s %s\n", $1 " " $2, acao, p[1]
            }
        '

elif [[ -r "$LOG_APT" ]]; then
    echo "Fonte: $LOG_APT"
    echo ""

    # O history.log registra remoções em "Remove:" dentro de cada bloco.
    awk '
        /^Start-Date:/ { data = $2 }
        /^Remove:/     {
            sub(/^Remove: /, "")
            n = split($0, pkgs, ", ")
            for (i = 1; i <= n; i++) {
                sub(/ \(.*\)/, "", pkgs[i])
                printf "Data: %s | Pacote: %s\n", data, pkgs[i]
            }
        }
    ' "$LOG_APT"
else
    echo "Nenhum log de pacotes encontrado (dpkg.log ou apt/history.log)." >&2
    exit 1
fi

