#!/usr/bin/env bash

# Exercício 17 - Para cada tentativa de login falha, extrai o nome do usuário
# e o método/serviço de autenticação (ex: sshd, su, login, PAM, etc.).
#
# Fontes:
#   1. /var/log/auth.log ou /var/log/secure → log clássico de autenticação.
#   2. journalctl                           → fallback.

if [[ -f /var/log/auth.log ]]; then
    LOG="/var/log/auth.log"
elif [[ -f /var/log/secure ]]; then
    LOG="/var/log/secure"
else
    LOG=""
fi

echo "Tentativas de login falhas — usuário e método de autenticação"
echo "==============================================================="

# Extrai o serviço (método) a partir do nome do processo no campo 5 do log.
# Ex: "sshd[1234]:" → "sshd" | "su[5678]:" → "su"
extrair_servico() {
    # Recebe a linha completa e retorna o nome do processo sem PID nem ":"
    echo "$1" | awk '{s=$5; gsub(/\[.*|\:$/, "", s); print s}'
}

processar() {
    awk '
    {
        linha = $0

        # No formato ISO, o processo fica no campo 3; em logs clássicos, no 5.
        servico = ($1 ~ /T/) ? $3 : $5
        gsub(/\[[^]]*\]/, "", servico)
        gsub(/:$/, "", servico)
        gsub(/\]$/, "", servico)
        if (servico ~ /^pam_unix/) {
            sub(/^pam_unix\(/, "", servico)
            sub(/:.*$/, "", servico)
        }

        # Extrai usuário: procura "for <usuario>" ou "for invalid user <usuario>"
        usuario = "?"
        for (i = 1; i <= NF; i++) {
            if ($i == "user=") {
                usuario = $(i+1)
                break
            } else if ($i ~ /^user=/) {
                usuario = $i
                sub(/^user=/, "", usuario)
                break
            } else if ($i == "for" && $(i+1) == "invalid" && $(i+2) == "user") {
                usuario = $(i+3)
                break
            } else if ($i == "for" && $(i+1) != "invalid" && $(i+1) != "") {
                usuario = $(i+1)
                break
            }
        }

        # Data/hora: campos 1-3 (log clássico) ou campo 1 (ISO)
        data = ($1 ~ /T/) ? $1 : $1 " " $2 " " $3

        printf "Data: %-20s | Método: %-12s | Usuário: %s\n", data, servico, usuario
    }'
}

if [[ -n "$LOG" ]]; then
    echo "Fonte: $LOG"
    echo ""
    grep -E "Failed password|authentication failure|FAILED LOGIN|Invalid user" "$LOG" | processar
else
    echo "Fonte: journalctl"
    echo ""
    journalctl -o cat 2>/dev/null | \
        grep -E "Failed password|authentication failure|FAILED LOGIN|Invalid user" | \
        processar
fi
