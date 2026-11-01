#!/bin/bash
# Simulador de RTP com menu interativo + suporte para análise de histórico real
# Mantém a experiência do menu original e adiciona coleta e análise de dados históricos

TOTAL_RODADAS=100000
APOSTA=1
BLOCO=1000
HISTORICO_ARQUIVO=""

banner="
    ██████╗  █████╗ ███╗   ███╗███████╗██████╗ 
   ██╔════╝ ██╔══██╗████╗ ████║██╔════╝██╔══██╗
   ██║  ███╗███████║██╔████╔██║█████╗  ██████╔╝
   ██║   ██║██╔══██║██║╚██╔╝██║██╔══╝  ██╔═══╝ 
   ╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗██║     
    ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝     
"

cores=("\033[1;31m" "\033[1;32m" "\033[1;34m" "\033[1;35m" "\033[1;36m" "\033[1;33m")
RESET="\033[0m"

mostrar_banner() {
    for i in {0..5}; do
        clear
        echo -e "${cores[$i]}$banner${RESET}"
        sleep 0.15
    done
}

calcular_rtp() {
    local ganho="$1"
    local total_apostado="$2"
    local rtp="0"

    if (( $(awk -v a="$total_apostado" 'BEGIN {print (a > 0) ? 1 : 0}') )); then
        rtp=$(awk -v g="$ganho" -v a="$total_apostado" 'BEGIN { printf "%.2f", (g / a) * 100 }')
    fi

    echo "$rtp"
}

simular_jogo() {
    local JOGO="$1"
    shift
    local -a PROBS=("$@")
    local TOTAL_RODADAS_LOCAL="$TOTAL_RODADAS"
    local GANHO_TOTAL=0
    local RESULTADO TEMP GANHO
    declare -A contagem=()

    echo "Simulando $JOGO..."
    echo "Rodadas: $TOTAL_RODADAS_LOCAL | Aposta: $APOSTA crédito(s)"

    for ((i=1; i<=TOTAL_RODADAS_LOCAL; i++)); do
        RESULTADO=$((RANDOM % 1000))
        TEMP=$RESULTADO
        GANHO=0

        for ((j=0; j<${#PROBS[@]}; j+=2)); do
            PROB=${PROBS[$j]}
            VALOR=${PROBS[$((j+1))]}
            if [ $TEMP -lt $PROB ]; then
                GANHO=$VALOR
                contagem[$VALOR]=$((contagem[$VALOR]+1))
                break
            else
                TEMP=$((TEMP - PROB))
            fi
        done

        GANHO_TOTAL=$((GANHO_TOTAL + GANHO))

        if (( i % BLOCO == 0 )); then
            RTP_BLOCO=$(awk "BEGIN {print ($GANHO_TOTAL / ($i * $APOSTA)) * 100}")
            echo "Rodada $i -> RTP acumulado: $RTP_BLOCO %"
        fi
    done

    RTP=$(awk "BEGIN {print ($GANHO_TOTAL / ($TOTAL_RODADAS_LOCAL * $APOSTA)) * 100}")

    if (( $(echo "$RTP >= 100" | bc -l) )); then
        CHANCE="\033[1;34mAlta chance de acerto\033[0m"
    elif (( $(echo "$RTP >= 70" | bc -l) )); then
        CHANCE="\033[1;33mMédia chance de acerto\033[0m"
    else
        CHANCE="\033[1;31mBaixa chance de acerto\033[0m"
    fi

    echo
    echo "=== Relatório Parcial ==="
    for ganho in "${!contagem[@]}"; do
        qtd=${contagem[$ganho]}
        perc=$(awk "BEGIN {print ($qtd / $TOTAL_RODADAS_LOCAL) * 100}")
        contrib=$(awk "BEGIN {print ($qtd * $ganho / ($TOTAL_RODADAS_LOCAL * $APOSTA)) * 100}")
        echo "Prêmio $ganho créditos -> $qtd vezes (${perc}% das rodadas) | Contribuição RTP: ${contrib}%"
    done

    echo
    echo "Retorno total: $GANHO_TOTAL créditos"
    echo -e "RTP estimado final: $RTP % -> $CHANCE"
    echo "RTP teórico oficial aproximado: ~96 %"
    echo
}

analizar_historico_real() {
    local arquivo="$1"

    if [[ -z "$arquivo" ]]; then
        echo "Uso: $0 --historico <arquivo.csv|arquivo.json>"
        return 1
    fi

    if [[ ! -f "$arquivo" ]]; then
        echo "Arquivo não encontrado: $arquivo"
        return 1
    fi

    local ext="${arquivo##*.}"
    if [[ "$ext" =~ ^(csv|CSV|json|JSON)$ ]]; then
        python3 - "$arquivo" <<'PY'
import csv
import json
import os
import sys
from collections import defaultdict

path = sys.argv[1]
rows = []

try:
    if path.lower().endswith('.json'):
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        if isinstance(data, dict):
            data = data.get('historico') or data.get('jogos') or data.get('dados') or [data]

        for item in data:
            if isinstance(item, dict):
                rows.append(item)
    else:
        with open(path, newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                rows.append(row)
except Exception as exc:
    print(f"Erro ao ler o arquivo: {exc}")
    sys.exit(1)

if not rows:
    print("Nenhuma linha válida foi encontrada no arquivo histórico.")
    print("Formato esperado: colunas como data_hora, jogo, aposta, ganho, status ou campos equivalentes.")
    sys.exit(1)

summary = defaultdict(lambda: {'rodadas': 0, 'aposta': 0.0, 'ganho': 0.0})
total_rodadas = 0
total_aposta = 0.0
total_ganho = 0.0

for row in rows:
    nome = (
        row.get('jogo') or row.get('game') or row.get('nome') or row.get('slot') or 'Desconhecido'
    ).strip()

    if not nome:
        continue

    try:
        aposta = float(row.get('aposta') or row.get('bet') or row.get('valor_apostado') or 0)
        ganho = float(row.get('ganho') or row.get('payout') or row.get('win') or row.get('valor_ganho') or 0)
    except (TypeError, ValueError):
        continue

    if aposta == 0 and ganho == 0:
        continue

    total_rodadas += 1
    total_aposta += aposta
    total_ganho += ganho

    s = summary[nome]
    s['rodadas'] += 1
    s['aposta'] += aposta
    s['ganho'] += ganho

rtp = (total_ganho / total_aposta * 100) if total_aposta else 0.0

print('=== Análise de histórico real ===')
print(f'Arquivo: {os.path.basename(path)}')
print(f'Rodadas processadas: {total_rodadas}')
print(f'Total apostado: {total_aposta:.2f}')
print(f'Total pago: {total_ganho:.2f}')
print(f'RTP geral: {rtp:.2f}%')
print('--- por jogo ---')

if summary:
    for nome, dados in sorted(summary.items(), key=lambda x: x[1]['ganho'], reverse=True):
        jogo_rtp = (dados['ganho'] / dados['aposta'] * 100) if dados['aposta'] else 0.0
        print(f"{nome}: {dados['rodadas']} rodadas | apostado={dados['aposta']:.2f} | pago={dados['ganho']:.2f} | RTP={jogo_rtp:.2f}%")
else:
    print('Nenhum dado válido foi identificado.')
PY
    else
        echo "Formato de arquivo não suportado: $arquivo"
        echo "Use .csv ou .json."
        return 1
    fi
}

mostrar_menu() {
    clear
    mostrar_banner
    echo
    echo "=============================="
    echo "      MENU DE JOGOS RTP       "
    echo "=============================="
    echo "1) Simular RTP de jogos"
    echo "2) Analisar histórico real (.csv/.json)"
    echo "3) Sair"
    echo "=============================="
    read -p "Escolha a opção: " OPCAO

    case "$OPCAO" in
        1)
            clear
            echo "PG Soft:"
            jogos_pg=(
                "Mahjong Ways"
                "Treasures of Aztec"
                "Fortune Mouse"
                "Fortune Tiger"
            )

            echo "Pragmatic Play:"
            jogos_pragmatic=(
                "Sweet Bonanza"
                "Gates of Olympus"
                "The Dog House"
                "Joker's Jewels"
            )

            for i in "${!jogos_pg[@]}"; do
                echo "$((i+1))) ${jogos_pg[$i]}"
            done
            for i in "${!jogos_pragmatic[@]}"; do
                echo "$((i+1+${#jogos_pg[@]}))) ${jogos_pragmatic[$i]}"
            done
            echo
            read -p "Escolha o número do jogo: " JOGO_ESCOLHIDO

            case "$JOGO_ESCOLHIDO" in
                1) JOGO="Mahjong Ways (PG Soft)"; PROBS=(800 0 150 50 40 200 10 500) ;;
                2) JOGO="Treasures of Aztec (PG Soft)"; PROBS=(780 0 160 40 50 150 10 600) ;;
                3) JOGO="Fortune Mouse (PG Soft)"; PROBS=(850 0 120 30 20 200 10 400) ;;
                4) JOGO="Fortune Tiger (PG Soft)"; PROBS=(820 0 120 30 40 150 20 500) ;;
                5) JOGO="Sweet Bonanza (Pragmatic)"; PROBS=(750 0 180 20 50 100 20 500 10 1000) ;;
                6) JOGO="Gates of Olympus (Pragmatic)"; PROBS=(760 0 150 30 60 200 20 600 10 1000) ;;
                7) JOGO="The Dog House (Pragmatic)"; PROBS=(780 0 160 40 50 150 10 500 10 800) ;;
                8) JOGO="Joker's Jewels (Pragmatic)"; PROBS=(800 0 150 100 40 250 9 1000 1 25000) ;;
                *) echo "Opção inválida!"; sleep 2; return 0 ;;
            esac

            simular_jogo "$JOGO" "${PROBS[@]}"
            read -p "Pressione ENTER para voltar ao menu..." dummy
            ;;
        2)
            read -p "Informe o caminho do arquivo CSV/JSON com histórico: " HISTORICO_ARQUIVO
            analisar_historico_real "$HISTORICO_ARQUIVO"
            read -p "Pressione ENTER para voltar ao menu..." dummy
            ;;
        3)
            echo "Encerrando..."
            exit 0
            ;;
        *)
            echo "Opção inválida!"
            sleep 1
            ;;
    esac
}

if [[ $# -gt 0 ]]; then
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --historico)
                shift
                if [[ $# -lt 1 ]]; then
                    echo "Falta o caminho do arquivo histórico."
                    exit 1
                fi
                analisar_historico_real "$1"
                exit $?
                ;;
            --rodadas)
                shift
                if [[ $# -lt 1 ]]; then
                    echo "Falta o valor de rodadas."
                    exit 1
                fi
                TOTAL_RODADAS="$1"
                ;;
            --aposta)
                shift
                if [[ $# -lt 1 ]]; then
                    echo "Falta o valor da aposta."
                    exit 1
                fi
                APOSTA="$1"
                ;;
            --bloco)
                shift
                if [[ $# -lt 1 ]]; then
                    echo "Falta o valor do bloco."
                    exit 1
                fi
                BLOCO="$1"
                ;;
            --help|-h)
                echo "Uso: $0 [--historico <arquivo.csv|arquivo.json>] [--rodadas N] [--aposta N] [--bloco N]"
                echo
                echo "Exemplo:"
                echo "  $0 --historico dados/historico.csv"
                echo "  $0 --rodadas 20000 --aposta 2"
                exit 0
                ;;
            *)
                echo "Opção desconhecida: $1"
                echo "Use --help para ver as opções."
                exit 1
                ;;
        esac
        shift
    done
fi

while true; do
    mostrar_menu
    echo
    if [[ "$OPCAO" == "3" ]]; then
        break
    fi
    OPCAO=""
done
