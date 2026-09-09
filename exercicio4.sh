#!/usr/bin/env bash

# Exercício 4 - Identifica logins rejeitados por motivos além de senha incorreta,
# como usuários inexistentes ou falta de permissão.
#
# Padrões buscados:
#   - "Invalid user"      → usuário não existe no sistema
#   - "User not allowed"  → PAM bloqueou o usuário (ex: AllowUsers/DenyUsers no sshd)
#   - "not allowed"       → variação de bloqueio por permissão
#   - "Connection closed" after authentication → cliente desconectou sem autenticar
#   - "Did not receive"   → timeout / conexão abandonada pelo cliente

if [[ -f /var/log/auth.log ]]; then
    LOG="/var/log/auth.log"
elif [[ -f /var/log/secure ]]; then
    LOG="/var/log/secure"
else
    LOG=""
fi

echo "Logins rejeitados por motivo diferente de senha incorreta"
echo "=========================================================="

# Função que processa as linhas já filtradas e exibe de forma legível.
processar() {
    awk '{
        # Os três primeiros campos dos logs clássicos são: Mês Dia HH:MM:SS
        data = $1 " " $2 " " $3

        motivo = "desconhecido"

        # Detecta o tipo de rejeição pela linha inteira
        linha = tolower($0)
        if (linha ~ /invalid user/)           motivo = "usuário inexistente"
        else if (linha ~ /user not allowed/)  motivo = "usuário sem permissão"
        else if (linha ~ /not allowed/)       motivo = "acesso não permitido"
        else if (linha ~ /did not receive/)   motivo = "sem identificação / timeout"
        else if (linha ~ /connection closed/) motivo = "conexão encerrada pelo cliente"
        else if (linha ~ /maximum auth/)      motivo = "máximo de tentativas atingido"
        else if (linha ~ /no supported/)      motivo = "método de autenticação inválido"

        # Tenta extrair o usuário da linha
        usuario = "?"
        for (i = 1; i <= NF; i++) {
            if (($i == "user" || $i == "for") && $(i+1) != "" &&
                $(i+1) !~ /^(invalid|not|from|port)$/) {
                usuario = $(i+1)
                break
            }
        }

        printf "Data/hora: %-18s | Usuário: %-20s | Motivo: %s\n",
               data, usuario, motivo
    }'
}

if [[ -n "$LOG" ]]; then
    grep -Ei \
        "Invalid user|User not allowed|not allowed to log|Did not receive identification|Connection closed by|maximum authentication|no supported authentication" \
        "$LOG" | processar
else
    # Usa journalctl quando não há arquivo de log clássico.
    journalctl -o cat 2>/dev/null | \
        grep -Ei \
            "Invalid user|User not allowed|not allowed to log|Did not receive identification|Connection closed by|maximum authentication|no supported authentication" | \
        processar
fi

