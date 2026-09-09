#!/usr/bin/env bash

# Exercício 19 - Busca mensagens de erro ou aviso (error, warning) geradas
# por um serviço específico do sistema.
#
# Uso: ./exercicio19.sh [nome-do-servico]
# Exemplo: ./exercicio19.sh sshd
#          ./exercicio19.sh cron
#
# Se nenhum serviço for informado, usa "sshd" como padrão.

SERVICO="${1:-sshd}"

echo "Erros e avisos do serviço: $SERVICO"
echo "========================================"

# Padrão para capturar erros e avisos.
PADRAO_NIVEL="[Ee]rror|[Ee]rro|[Ww]arning|[Aa]viso|[Ff]ail|[Cc]ritical|[Cc]rit|[Aa]lert|[Ee]mergency"

processar() {
    awk -v svc="$SERVICO" '
    {
        # Determina o nível da mensagem
        nivel = "DESCONHECIDO"
        linha_lower = tolower($0)
        if (linha_lower ~ /critical|crit/)  nivel = "CRITICO "
        else if (linha_lower ~ /error|erro/) nivel = "ERRO    "
        else if (linha_lower ~ /warning|aviso/) nivel = "AVISO   "
        else if (linha_lower ~ /fail/)       nivel = "FALHA   "
        else if (linha_lower ~ /alert/)      nivel = "ALERTA  "
        else if (linha_lower ~ /emergency/)  nivel = "EMERG.  "

        # Data/hora: campo 1 (ISO) ou campos 1-3 (clássico)
        data = ($1 ~ /T/) ? $1 : $1 " " $2 " " $3

        printf "[%s] Nível: %s | %s\n", data, nivel, $0
    }'
}

if command -v journalctl >/dev/null 2>&1; then
    echo "Fonte: journalctl -u $SERVICO"
    echo ""

    # -u filtra pela unidade systemd; -p warning inclui warning, err, crit, alert, emerg.
    journalctl -u "${SERVICO}.service" -p warning --no-pager 2>/dev/null | \
        grep -v "^--" | processar

    # Tenta também pelo identificador do syslog (sem .service)
    if [[ $? -ne 0 ]]; then
        journalctl -t "$SERVICO" -p warning --no-pager 2>/dev/null | \
            grep -v "^--" | processar
    fi

else
    # Fallback: arquivos de log clássicos
    for LOG in /var/log/syslog /var/log/messages /var/log/auth.log /var/log/secure; do
        if [[ -r "$LOG" ]]; then
            echo "Fonte: $LOG"
            echo ""

            # Filtra linhas que contenham o serviço E a palavra de nível
            grep -i "$SERVICO" "$LOG" | \
                grep -Ei "$PADRAO_NIVEL" | \
                processar

            exit 0
        fi
    done
    echo "Nenhuma fonte disponível (journalctl ou arquivos de log)." >&2
    exit 1
fi

