#!/usr/bin/env bash

# Exercício 1 - contabiliza tentativas de senha incorreta por usuário.
# Em Debian/Ubuntu o log costuma ser /var/log/auth.log; em RHEL/Fedora,
# /var/log/secure. O journalctl é usado como alternativa.
if [[ -f /var/log/auth.log ]]; then
    LOG="/var/log/auth.log"
elif [[ -f /var/log/secure ]]; then
    LOG="/var/log/secure"
else
    LOG=""
fi

echo "Usuário                         Tentativas falhas"
echo "-------------------------------------------------"

if [[ -n "$LOG" ]]; then
    # "invalid user" também é uma tentativa de senha, mas o nome vem depois
    # dessa expressão; para os demais casos, vem logo depois de "for".
    grep -E "Failed password for (invalid user )?[[:alnum:]_.-]+" "$LOG" |
        awk '{
            for (i = 1; i <= NF; i++) {
                if ($i == "user" && $(i + 1) != "") {
                    usuario = $(i + 1)
                } else if ($i == "for" && $(i + 1) == "invalid" &&
                           $(i + 2) == "user") {
                    usuario = $(i + 3)
                } else if ($i == "for" && $(i + 1) != "invalid") {
                    usuario = $(i + 1)
                }
            }
            if (usuario != "") {
                contagem[usuario]++
                usuario = ""
            }
        }
        END {
            for (usuario in contagem) print usuario, contagem[usuario]
        }' | sort -k2,2nr -k1,1
else
    # -o cat remove metadados do journal para o grep/awk receber a mensagem.
    journalctl -o cat 2>/dev/null |
        grep -E "Failed password for (invalid user )?[[:alnum:]_.-]+" |
        awk '{
            for (i = 1; i <= NF; i++)
                if ($i == "for") {
                    usuario = ($(i + 1) == "invalid") ? $(i + 3) : $(i + 1)
                    contagem[usuario]++
                }
        }
        END { for (usuario in contagem) print usuario, contagem[usuario] }' |
        sort -k2,2nr -k1,1
fi
