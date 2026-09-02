#!/usr/bin/env bash

# Exercício 3 - audita o uso do sudo, mostrando data/hora e usuário.
if [[ -f /var/log/auth.log ]]; then
    LOG="/var/log/auth.log"
elif [[ -f /var/log/secure ]]; then
    LOG="/var/log/secure"
else
    LOG=""
fi

echo "Eventos de sudo"
echo "==============="

if [[ -n "$LOG" ]]; then
    # Localiza o campo "sudo:" (ou "sudo[pid]:") e usa o campo seguinte
    # como usuário. Os três primeiros campos são a data nos logs clássicos.
    grep -E "sudo(\[[0-9]+\])?:[[:space:]]+[[:alnum:]_.-]+[[:space:]]+:" "$LOG" |
        awk '{
            for (i = 1; i <= NF; i++)
                if ($i ~ /^sudo(\[[0-9]+\])?:$/) {
                    data = ($1 ~ /T/) ? $1 : $1 " " $2 " " $3
                    printf "Data/hora: %s | Usuário: %s\n", data, $(i + 1)
                    break
                }
        }'
else
    # No journald, -o short-iso coloca toda a data/hora no primeiro campo.
    journalctl -o short-iso -t sudo 2>/dev/null |
        awk '{
            for (i = 1; i <= NF; i++)
                if ($i ~ /^sudo(\[[0-9]+\])?:$/) {
                    printf "Data/hora: %s | Usuário: %s\n", $1, $(i + 1)
                    break
                }
        }'
fi
