#!/usr/bin/env bash

# Exercício 6 - Mostra a data e hora do último boot do sistema.
#
# Estratégia: o comando "last reboot" lê /var/log/wtmp e lista as
# reinicializações registradas; a primeira linha é sempre a mais recente.
# Como alternativa, "who -b" ou "uptime -s" também fornecem essa informação.

echo "Último boot do sistema"
echo "======================"

# Tenta "last reboot" primeiro (mais detalhado, disponível na maioria das distros).
if command -v last >/dev/null 2>&1 && [[ -r /var/log/wtmp ]]; then
    # Filtra apenas as linhas de "reboot" e pega a primeira (mais recente).
    # -F garante que a data completa seja exibida.
    ULTIMO=$(last -F reboot 2>/dev/null | awk '/^reboot/{print; exit}')
    if [[ -n "$ULTIMO" ]]; then
        echo "Fonte: /var/log/wtmp (comando last)"
        echo "$ULTIMO"
        exit 0
    fi
fi

# Alternativa: "uptime -s" mostra o horário de início do sistema.
if uptime -s >/dev/null 2>&1; then
    echo "Fonte: uptime -s"
    echo "Boot em: $(uptime -s)"
    exit 0
fi

# Última alternativa: journalctl, que armazena o horário do primeiro evento.
if command -v journalctl >/dev/null 2>&1; then
    echo "Fonte: journalctl"
    journalctl --list-boots 2>/dev/null | \
        awk 'NR==1 {
            # Saída do --list-boots: ID  Data-Início  Data-Fim
            # Remove a coluna ID e exibe o restante
            $1 = ""; print "Último boot:", $0
        }'
    exit 0
fi

echo "Não foi possível determinar a data do último boot." >&2
exit 1

