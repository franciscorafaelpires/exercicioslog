#!/usr/bin/env bash

# Exercício 11 - Lista os pacotes instalados na última semana, com a data.
#
# Fontes usadas:
#   - /var/log/dpkg.log   → principal log do dpkg (Debian/Ubuntu)
#   - /var/log/apt/history.log → histórico de transações do apt (mais legível)
#
# O dpkg.log registra uma linha por pacote com formato:
#   YYYY-MM-DD HH:MM:SS install <pacote>:<arq> <versao-old> <versao-new>

LOG_DPKG="/var/log/dpkg.log"
LOG_APT="/var/log/apt/history.log"

echo "Pacotes instalados na última semana"
echo "===================================="

# Calcula a data de corte (7 dias atrás) no formato YYYY-MM-DD.
DATA_CORTE=$(date -d "7 days ago" +"%Y-%m-%d" 2>/dev/null \
             || date -v-7d +"%Y-%m-%d" 2>/dev/null)

if [[ -r "$LOG_DPKG" ]]; then
    echo "Fonte: $LOG_DPKG"
    echo "Data de corte: $DATA_CORTE"
    echo ""
    echo "Data/hora            Pacote"
    echo "--------------------+--------------------------------------------------"

    # Filtra apenas ações "install" e "upgrade" ocorridas desde DATA_CORTE.
    grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}.*( install | upgrade )" "$LOG_DPKG" | \
        awk -v corte="$DATA_CORTE" '
            $1 >= corte && ($3 == "install" || $3 == "upgrade") {
                # $1 = data, $2 = hora, $3 = ação, $4 = pacote:arq
                split($4, p, ":")          # remove arquitetura do nome
                printf "%-20s %s\n", $1 " " $2, p[1]
            }
        '

elif [[ -r "$LOG_APT" ]]; then
    echo "Fonte: $LOG_APT"
    echo "Data de corte: $DATA_CORTE"
    echo ""

    # history.log agrupa transações; "Install:" lista pacotes instalados.
    # Usamos awk para associar cada bloco à sua data.
    awk -v corte="$DATA_CORTE" '
        /^Start-Date:/ {
            split($2, d, "-"); data = $2
            dentro = (data >= corte)
        }
        dentro && /^Install:/ {
            sub(/^Install: /, "")
            n = split($0, pkgs, ", ")
            for (i = 1; i <= n; i++) {
                sub(/ \(.*\)/, "", pkgs[i])
                printf "Data: %s | Pacote: %s\n", data, pkgs[i]
            }
        }
        dentro { inside = 1 }
        /^End-Date:/ { inside = 0; dentro = 0 }
    ' "$LOG_APT"
else
    echo "Nenhum log de pacotes encontrado (dpkg.log ou apt/history.log)." >&2
    exit 1
fi
