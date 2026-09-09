#!/usr/bin/env bash

# Exercício 8 - Lista serviços que foram iniciados ou parados recentemente,
# mostrando a data/hora e o nome do serviço.
#
# Fontes usadas em ordem de preferência:
#   1. journalctl  → registra todos os eventos de unidades systemd com precisão.
#   2. /var/log/syslog ou /var/log/messages → fallback para sistemas sem journald.

echo "Serviços com status alterado recentemente"
echo "========================================="

# Função que formata a saída: Ação | Serviço | Data/hora.
formatar() {
    awk '{
        linha = $0
        acao = "?"

        # Detecta o tipo de evento pela mensagem do systemd
        if (linha ~ /Started/)          acao = "INICIADO  "
        else if (linha ~ /Stopped/)     acao = "PARADO    "
        else if (linha ~ /Starting/)    acao = "INICIANDO "
        else if (linha ~ /Stopping/)    acao = "PARANDO   "
        else if (linha ~ /Failed/)      acao = "FALHOU    "
        else if (linha ~ /Reloading/)   acao = "RECARREG. "
        else if (linha ~ /Reloaded/)    acao = "RECARREG. "

        # Data/hora: primeiros campos da linha
        split(linha, campos, " ")
        data = campos[1]           # journalctl -o short-iso: campo 1 = timestamp ISO
        # O nome da unidade aparece após a ação, antes da descrição.
        servico = linha
        if (acao ~ /INICIADO/)  sub(/^.*Started /, "", servico)
        if (acao ~ /PARADO/)    sub(/^.*Stopped /, "", servico)
        if (acao ~ /INICIANDO/) sub(/^.*Starting /, "", servico)
        if (acao ~ /PARANDO/)   sub(/^.*Stopping /, "", servico)
        if (acao ~ /FALHOU/)    sub(/^.*Failed /, "", servico)
        if (acao ~ /RECARREG/)  sub(/^.*Reloaded? /, "", servico)
        sub(/ - .*/, "", servico)
        sub(/\.$/, "", servico)

        printf "Ação: %s | Serviço: %-45s | Data/hora: %s\n", acao, servico, data
    }'
}

if command -v journalctl >/dev/null 2>&1; then
    echo "Fonte: journalctl"
    echo ""
    # _SYSTEMD_UNIT filtra apenas mensagens do próprio PID 1 (systemd),
    # que é quem registra mudanças de estado das unidades.
    journalctl -o short-iso _PID=1 2>/dev/null | \
        grep -E "Started|Stopped|Starting|Stopping|Failed|Reloading|Reloaded" | \
        formatar
else
    # Fallback para logs de texto clássicos
    for LOG in /var/log/syslog /var/log/messages; do
        if [[ -r "$LOG" ]]; then
            echo "Fonte: $LOG"
            echo ""
            grep -Ei "systemd.*started|systemd.*stopped|systemd.*starting|systemd.*stopping|systemd.*failed" "$LOG" | \
                awk '{
                    # Logs clássicos: "Mês Dia HH:MM:SS host systemd: mensagem"
                    data = $1 " " $2 " " $3
                    acao = "?"
                    if ($0 ~ /[Ss]tarted/)  acao = "INICIADO  "
                    if ($0 ~ /[Ss]topped/)  acao = "PARADO    "
                    if ($0 ~ /[Ff]ailed/)   acao = "FALHOU    "

                    # Pega tudo após o ":" do campo systemd
                    msg = $0; sub(/^.*systemd[^:]*: /, "", msg)
                    printf "Ação: %s | %-50s | Data/hora: %s\n", acao, msg, data
                }'
            exit 0
        fi
    done
    echo "Erro: nem journalctl nem /var/log/syslog|messages estão disponíveis." >&2
    exit 1
fi
