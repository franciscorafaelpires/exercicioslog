#!/usr/bin/env bash

# Exercício 15 - Filtra um log para exibir apenas os eventos ocorridos
# entre 14h e 15h de um dia específico.
#
# Uso: ./exercicio15.sh [YYYY-MM-DD] [HH_inicio] [HH_fim]
# Exemplo: ./exercicio15.sh 2024-06-10 14 15
#
# Se nenhum argumento for passado, usa hoje como data e 14-15 como intervalo.

# --- Parâmetros ---
DIA="${1:-$(date +%Y-%m-%d)}"   # data no formato YYYY-MM-DD
H_INI="${2:-14}"                 # hora de início (inteiro, ex: 14)
H_FIM="${3:-15}"                 # hora de fim    (inteiro, ex: 15)

echo "Eventos entre ${H_INI}h e ${H_FIM}h do dia $DIA"
echo "================================================="

# --- Escolha do log ---
# Preferência: syslog (mais completo); fallback: auth.log ou journalctl.
if [[ -r /var/log/syslog ]]; then
    LOG="/var/log/syslog"
elif [[ -r /var/log/messages ]]; then
    LOG="/var/log/messages"
elif [[ -r /var/log/auth.log ]]; then
    LOG="/var/log/auth.log"
elif [[ -r /var/log/secure ]]; then
    LOG="/var/log/secure"
else
    LOG=""
fi

# Monta padrão de hora: "14:" até "14:59:" — cada hora do intervalo.
# Gera um padrão de regex que captura HH:MM do período desejado.
horas_regex() {
    local inicio=$1 fim=$2
    local padrao=""
    for (( h = inicio; h < fim; h++ )); do
        padrao+=$(printf "%02d:" "$h")"|"
    done
    echo "${padrao%|}"   # remove "|" final
}

HORAS_REGEX=$(horas_regex "$H_INI" "$H_FIM")

if [[ -n "$LOG" ]]; then
    echo "Fonte: $LOG"
    echo ""

    # Logs clássicos: "Mmm DD HH:MM:SS ..."
    # Convertemos DIA (YYYY-MM-DD) para "Mmm DD" para bater com o formato do log.
    MES_DIA=$(date -d "$DIA" +"%-m" 2>/dev/null)
    MES_ABREV=$(date -d "$DIA" +"%b" 2>/dev/null || date -j -f "%Y-%m-%d" "$DIA" +"%b" 2>/dev/null)
    DIA_NUM=$(date -d "$DIA" +"%-d" 2>/dev/null  || date -j -f "%Y-%m-%d" "$DIA" +"%-d" 2>/dev/null)

    # Padrão: "Mmm  D HH:" ou "Mmm DD HH:" (com espaço simples ou duplo)
    PREFIXO="${MES_ABREV} ${DIA_NUM}"

    grep -E "^${MES_ABREV} +${DIA_NUM} (${HORAS_REGEX})" "$LOG"

else
    echo "Fonte: journalctl"
    echo ""

    # journalctl aceita --since e --until no formato "YYYY-MM-DD HH:MM:SS"
    journalctl \
        --since="${DIA} ${H_INI}:00:00" \
        --until="${DIA} ${H_FIM}:00:00" \
        --no-pager 2>/dev/null
fi

