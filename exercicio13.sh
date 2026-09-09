#!/usr/bin/env bash

# Exercício 13 - Rastreia o uso dos comandos de gerenciamento de pacotes
# (apt, apt-get, dpkg), mostrando quem executou e qual ação foi realizada.
#
# Fontes:
#   1. /var/log/auth.log ou /var/log/secure → mostra quem chamou sudo + apt/dpkg
#   2. /var/log/apt/history.log             → registra o usuário em "Commandline:"
#   3. /var/log/dpkg.log                    → fallback; sem info de usuário

echo "Uso de comandos de gerenciamento de pacotes"
echo "============================================="

# -------------------------------------------------------------------
# Fonte 1: apt/history.log — forma mais rica: tem usuário e ação
# -------------------------------------------------------------------
LOG_APT_HIST="/var/log/apt/history.log"
if [[ -r "$LOG_APT_HIST" ]]; then
    echo "Fonte: $LOG_APT_HIST"
    echo ""
    echo "Data                 Usuário                Ação realizada"
    echo "--------------------+----------------------+------------------------------"

    awk '
        /^Start-Date:/ { data = $2 " " $3; usuario = "?"; acao = "" }
        /^Requested-By:/ { usuario = $2 }
        /^Commandline:/ {
            # Linha ex: Commandline: apt-get install vim (como root)
            linha = $0
            sub(/^Commandline: /, "", linha)

            # Extrai usuário entre parênteses ao final da linha, se existir
            # Determina a ação principal: install, remove, upgrade, etc.
            if (linha ~ /dist-upgrade/)    acao = "DIST-UPGRADE"
            else if (linha ~ /autoremove/) acao = "AUTOREMOVE"
            else if (linha ~ /purge/)      acao = "PURGAR"
            else if (linha ~ /remove/)     acao = "REMOVER"
            else if (linha ~ /install/)    acao = "INSTALAR"
            else if (linha ~ /upgrade/)    acao = "ATUALIZAR"
            else                           acao = "OUTRO: " linha
        }
        /^End-Date:/ && acao != "" {
            printf "%-20s %-22s %s\n", data, usuario, acao
        }
    ' "$LOG_APT_HIST"

# -------------------------------------------------------------------
# Fonte 2: auth.log/secure — mostra usuário que chamou sudo + apt/dpkg
# -------------------------------------------------------------------
elif [[ -f /var/log/auth.log || -f /var/log/secure ]]; then
    LOG=$( [[ -f /var/log/auth.log ]] && echo /var/log/auth.log || echo /var/log/secure )
    echo "Fonte: $LOG"
    echo ""
    echo "Data/hora            Usuário     Comando executado"
    echo "--------------------+-----------+-----------------------------------------------"

    # Filtra linhas de sudo onde o comando contém apt, apt-get ou dpkg.
    grep -Ei "sudo.*COMMAND.*(apt|dpkg)" "$LOG" | \
        awk '{
            # Formato clássico: "Mês Dia HH:MM:SS host sudo: usuario : TTY=... COMMAND=..."
            data = $1 " " $2 " " $3

            # Extrai usuário (campo antes de ":")
            usuario = "?"
            for (i = 1; i <= NF; i++)
                if ($i ~ /^sudo:$/) { usuario = $(i+1); break }

            # Extrai o comando após "COMMAND="
            cmd = $0; sub(/.*COMMAND=/, "", cmd)

            # Determina a ação
            acao = "OUTRO"
            if (cmd ~ /install/)    acao = "INSTALAR"
            else if (cmd ~ /remove/) acao = "REMOVER"
            else if (cmd ~ /purge/)  acao = "PURGAR"
            else if (cmd ~ /upgrade/) acao = "ATUALIZAR"

            printf "%-20s %-11s [%s] %s\n", data, usuario, acao, cmd
        }'

# -------------------------------------------------------------------
# Fonte 3: dpkg.log — sem info de usuário, mas lista as ações
# -------------------------------------------------------------------
elif [[ -r /var/log/dpkg.log ]]; then
    echo "Fonte: /var/log/dpkg.log (usuário indisponível)"
    echo ""
    echo "Data/hora            Ação    Pacote"
    echo "--------------------+--------+------------------------------------------"

    grep -E " (install|upgrade|remove|purge|half-installed|half-configured) " /var/log/dpkg.log | \
        awk '{
            split($4, p, ":")
            printf "%-20s %-8s %s\n", $1 " " $2, $3, p[1]
        }'
else
    echo "Nenhuma fonte disponível para rastrear uso de gerenciadores de pacotes." >&2
    exit 1
fi
