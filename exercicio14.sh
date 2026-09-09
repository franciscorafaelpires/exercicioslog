#!/usr/bin/env bash

# Exercício 14 - Calcula o tempo de atividade do sistema analisando a
# diferença entre o último evento de boot e o evento de desligamento.
#
# Fontes:
#   1. /var/log/wtmp  → lido com "last", contém boots e shutdowns.
#   2. journalctl     → fallback para sistemas sem wtmp.
#
# Nota: se o sistema ainda estiver em execução, o "desligamento" não existe;
# nesse caso, usa-se a hora atual como fim do período.

echo "Tempo de atividade do sistema"
echo "=============================="

# Converte uma data no formato "Www Mmm DD HH:MM:SS YYYY" para epoch.
# Usado para calcular a diferença entre boot e shutdown.
data_para_epoch() {
    date -d "$1" +%s 2>/dev/null || date -j -f "%a %b %d %T %Y" "$1" +%s 2>/dev/null
}

formatar_duracao() {
    local segundos=$1
    local horas=$(( segundos / 3600 ))
    local minutos=$(( (segundos % 3600) / 60 ))
    local segs=$(( segundos % 60 ))
    printf "%dh %02dmin %02ds" "$horas" "$minutos" "$segs"
}

if command -v last >/dev/null 2>&1 && [[ -r /var/log/wtmp ]]; then
    echo "Fonte: /var/log/wtmp (last)"
    echo ""

    # Captura o boot mais recente
    BOOT_LINHA=$(last -F reboot 2>/dev/null | awk '/^reboot/{print; exit}')
    # Captura o shutdown mais recente
    SHUT_LINHA=$(last -F shutdown 2>/dev/null | awk '/^shutdown/{print; exit}')

    if [[ -z "$BOOT_LINHA" ]]; then
        echo "Nenhum evento de boot encontrado no wtmp." >&2
        exit 1
    fi

    # Extrai a data do boot (campos 4 a 8 no formato: Www Mmm DD HH:MM:SS YYYY)
    BOOT_DATA=$(echo "$BOOT_LINHA" | awk '{print $4, $5, $6, $7, $8}')
    BOOT_EPOCH=$(data_para_epoch "$BOOT_DATA")

    if [[ -n "$SHUT_LINHA" ]]; then
        SHUT_DATA=$(echo "$SHUT_LINHA" | awk '{print $4, $5, $6, $7, $8}')
        SHUT_EPOCH=$(data_para_epoch "$SHUT_DATA")
        FIM_LABEL="Desligamento"
    else
        # Sistema ainda em execução: usa hora atual
        SHUT_EPOCH=$(date +%s)
        SHUT_DATA=$(date)
        FIM_LABEL="Agora (sistema em execução)"
    fi

    DURACAO=$(( SHUT_EPOCH - BOOT_EPOCH ))

    echo "Último boot:   $BOOT_DATA"
    echo "$FIM_LABEL: $SHUT_DATA"
    echo ""
    echo "Tempo de atividade: $(formatar_duracao $DURACAO)"

elif command -v journalctl >/dev/null 2>&1; then
    echo "Fonte: journalctl"
    echo ""

    # journalctl --list-boots exibe: ID DataInício DataFim
    # Pega o boot mais recente (primeira linha após cabeçalho)
    BOOT_INFO=$(journalctl --list-boots 2>/dev/null | tail -n 1)

    if [[ -z "$BOOT_INFO" ]]; then
        echo "Nenhum boot encontrado via journalctl." >&2
        exit 1
    fi

    # Extrai campos: ID  data-início  hora-início  data-fim  hora-fim
    INICIO=$(echo "$BOOT_INFO" | awk '{print $4, $5, $6}')
    FIM=$(echo "$BOOT_INFO"    | awk '{print $8, $9, $10}')
    [[ "$FIM" == *now* || -z "$FIM" ]] && FIM=$(date '+%Y-%m-%d %H:%M:%S %z')

    INICIO_EPOCH=$(date -d "$INICIO" +%s 2>/dev/null)
    FIM_EPOCH=$(date -d "$FIM" +%s 2>/dev/null)

    if [[ -z "$INICIO_EPOCH" || -z "$FIM_EPOCH" ]]; then
        echo "Não foi possível calcular o tempo de atividade." >&2
        exit 1
    fi

    DURACAO=$(( FIM_EPOCH - INICIO_EPOCH ))

    echo "Boot:           $INICIO"
    echo "Fim do período: $FIM"
    echo ""
    echo "Tempo de atividade: $(formatar_duracao $DURACAO)"
else
    # Fallback simples: uptime
    echo "Fonte: uptime"
    echo ""
    uptime
fi
