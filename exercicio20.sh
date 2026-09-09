#!/usr/bin/env bash

# Exercício 20 - Calcula o tempo que um usuário permaneceu logado no sistema,
# usando as informações de login e logout do wtmp.
#
# Uso: ./exercicio20.sh [usuario]
# Exemplo: ./exercicio20.sh francisco
#
# Se nenhum usuário for passado, lista o tempo de sessão de TODOS os usuários.

USUARIO="${1:-}"

echo "Tempo de sessão dos usuários"
echo "============================="

formatar_duracao() {
    local segundos=$1
    # Trata durações negativas (sistema reiniciado antes do logout)
    if (( segundos < 0 )); then
        echo "sessão interrompida (reboot)"
        return
    fi
    local horas=$(( segundos / 3600 ))
    local minutos=$(( (segundos % 3600) / 60 ))
    local segs=$(( segundos % 60 ))
    printf "%dh %02dmin %02ds" "$horas" "$minutos" "$segs"
}

if command -v last >/dev/null 2>&1 && [[ -r /var/log/wtmp ]]; then
    echo "Fonte: /var/log/wtmp (last)"
    echo ""
    printf "%-20s %-25s %-25s %s\n" "Usuário" "Login" "Logout" "Duração"
    echo "--------------------+-------------------------+-------------------------+------------------"

    # "last -F" exibe data completa; "-w" não trunca hostnames.
    # Filtra pelo usuário se especificado, ou todos se não for.
    if [[ -n "$USUARIO" ]]; then
        FILTRO="$USUARIO"
    else
        FILTRO=""
    fi

    last -F -w $FILTRO 2>/dev/null | \
        awk '$1 !~ /^(reboot|shutdown|wtmp|btmp|$)/ && NF >= 10 {

            usuario = $1
            # Com -F: campo 3=dia_semana, 4=mes, 5=dia, 6=hora, 7=ano, 8="-", 9=dia_semana, 10=mes, 11=dia, 12=hora, 13=ano
            # Formato real de "last -F": "user pts/0 host Www Mmm DD HH:MM:SS YYYY - Www Mmm DD HH:MM:SS YYYY (HH:MM)"

            login  = $4 " " $5 " " $6 " " $7 " " $8  # 5 campos após hostname
            logout = $10 " " $11 " " $12 " " $13 " " $14

            # Converte para epoch
            cmd_login  = "date -d \"" login  "\" +%s 2>/dev/null"
            cmd_logout = "date -d \"" logout "\" +%s 2>/dev/null"

            cmd_login  | getline ep_login;  close(cmd_login)
            cmd_logout | getline ep_logout; close(cmd_logout)

            if (ep_login != "" && ep_logout != "") {
                duracao = ep_logout - ep_login
                horas   = int(duracao / 3600)
                minutos = int((duracao % 3600) / 60)
                segs    = duracao % 60
                dur_str = sprintf("%dh %02dmin %02ds", horas, minutos, segs)
            } else {
                dur_str = "ainda conectado / indisponível"
            }

            printf "%-20s %-25s %-25s %s\n", usuario, login, logout, dur_str
        }'

elif command -v journalctl >/dev/null 2>&1; then
    echo "Fonte: journalctl (pam_unix sessões)"
    echo ""

    # journalctl registra abertura e fechamento de sessões PAM.
    FILTRO_GREP=""
    [[ -n "$USUARIO" ]] && FILTRO_GREP="$USUARIO"

    journalctl -o short-iso 2>/dev/null | \
        grep -E "pam_unix.*session (opened|closed)" | \
        { [[ -n "$FILTRO_GREP" ]] && grep "$FILTRO_GREP" || cat; } | \
        awk '
        {
            timestamp = $1
            usuario = "?"
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^user=/) {
                    usuario = $i
                    sub(/^user=/, "", usuario)
                    break
                }
                if ($i == "user" && $(i + 1) != "") {
                    usuario = $(i + 1)
                    break
                }
            }
            sub(/\(.*/, "", usuario)

            tipo = ($0 ~ /opened/) ? "ABERTA " : "FECHADA"

            printf "%s | Sessão %-8s | Usuário: %s\n", timestamp, tipo, usuario
        }'
else
    echo "Nenhuma fonte disponível (last/wtmp ou journalctl)." >&2
    exit 1
fi
