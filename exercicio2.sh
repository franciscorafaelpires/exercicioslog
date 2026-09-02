#!/usr/bin/env bash

# Exercício 2 - gera um relatório dos logins aceitos.
# O arquivo /var/log/wtmp é binário e deve ser consultado pelo comando "last",
# que interpreta seus registros e fornece usuário e data/hora do acesso.
if [[ ! -r /var/log/wtmp ]]; then
    echo "Erro: /var/log/wtmp não está disponível para leitura." >&2
    exit 1
fi
if ! command -v last >/dev/null 2>&1; then
    echo "Erro: o comando 'last' não está instalado; ele é necessário para ler /var/log/wtmp." >&2
    exit 1
fi

echo "Relatório de logins bem-sucedidos"
echo "================================="

# Exclui cabeçalho, reinicializações, desligamentos e a linha de resumo.
# -F exibe a data completa; -w evita truncar nomes de host.
last -F -w |
    awk '$1 !~ /^(reboot|shutdown|wtmp|btmp)$/ && NF >= 7 {
        printf "Usuário: %-20s Data/hora: ", $1
        for (i = 4; i <= NF; i++) {
            if ($i == "still") break
            if ($i == "-") break
            printf "%s%s", $i, (i < NF ? " " : "")
        }
        print ""
    }'
