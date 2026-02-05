#!/bin/bash
# Simulador de RTP com menu interativo + Banner gamer colorido
# Probabilidades corrigidas + relatório parcial + oscilação RTP

TOTAL_RODADAS=100000
APOSTA=1
BLOCO=1000   # tamanho do bloco para mostrar oscilação

# Banner gamer em ASCII
banner="
   ██████╗  █████╗ ███╗   ███╗███████╗██████╗ 
  ██╔════╝ ██╔══██╗████╗ ████║██╔════╝██╔══██╗
  ██║  ███╗███████║██╔████╔██║█████╗  ██████╔╝
  ██║   ██║██╔══██║██║╚██╔╝██║██╔══╝  ██╔═══╝ 
  ╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗██║     
   ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝     
"

# Cores ANSI
cores=("\033[1;31m" "\033[1;32m" "\033[1;34m" "\033[1;35m" "\033[1;36m" "\033[1;33m")
RESET="\033[0m"

while true; do
    GANHO_TOTAL=0
    clear

    # Exibir banner mudando de cor
    for i in {0..5}; do
        clear
        echo -e "${cores[$i]}$banner${RESET}"
        sleep 0.15
    done

    # Lista de jogos PG Soft
    jogos_pg=(
        "Mahjong Ways"
        "Treasures of Aztec"
        "Fortune Mouse"
        "Fortune Tiger"
    )

    # Lista de jogos Pragmatic Play
    jogos_pragmatic=(
        "Sweet Bonanza"
        "Gates of Olympus"
        "The Dog House"
        "Joker's Jewels"
    )

    echo "=============================="
    echo "      MENU DE JOGOS RTP       "
    echo "=============================="
    echo "PG Soft:"
    for i in "${!jogos_pg[@]}"; do
        echo "$((i+1))) ${jogos_pg[$i]}"
    done
    echo
    echo "Pragmatic Play:"
    for i in "${!jogos_pragmatic[@]}"; do
        echo "$((i+1+${#jogos_pg[@]}))) ${jogos_pragmatic[$i]}"
    done
    echo
    echo "0) Voltar / Sair"
    echo "=============================="

    read -p "Escolha o número do jogo: " OPCAO

    if [ "$OPCAO" -eq 0 ]; then
        echo "Voltando ao menu principal... Encerrando."
        break
    fi

    # Probabilidades corrigidas: [probabilidade ganho]
    case $OPCAO in
        1) JOGO="Mahjong Ways (PG Soft)"; PROBS=(800 0 150 50 40 200 10 500) ;;
        2) JOGO="Treasures of Aztec (PG Soft)"; PROBS=(780 0 160 40 50 150 10 600) ;;
        3) JOGO="Fortune Mouse (PG Soft)"; PROBS=(850 0 120 30 20 200 10 400) ;;
        4) JOGO="Fortune Tiger (PG Soft)"; PROBS=(820 0 120 30 40 150 20 500) ;;
        5) JOGO="Sweet Bonanza (Pragmatic)"; PROBS=(750 0 180 20 50 100 20 500 10 1000) ;;
        6) JOGO="Gates of Olympus (Pragmatic)"; PROBS=(760 0 150 30 60 200 20 600 10 1000) ;;
        7) JOGO="The Dog House (Pragmatic)"; PROBS=(780 0 160 40 50 150 10 500 10 800) ;;
        8) JOGO="Joker's Jewels (Pragmatic)"; PROBS=(800 0 150 100 40 250 9 1000 1 25000) ;;
        *) echo "Opção inválida!"; sleep 2; continue ;;
    esac

    clear
    echo "Simulando $JOGO..."
    echo "Rodadas: $TOTAL_RODADAS | Aposta: $APOSTA crédito(s)"

    declare -A contagem

    for ((i=1; i<=TOTAL_RODADAS; i++)); do
        RESULTADO=$((RANDOM % 1000))
        TEMP=$RESULTADO
        GANHO=0

        # Loop para aplicar probabilidades corretamente
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

        # Mostrar oscilação do RTP a cada BLOCO
        if (( i % BLOCO == 0 )); then
            RTP_BLOCO=$(awk "BEGIN {print ($GANHO_TOTAL / ($i * $APOSTA)) * 100}")
            echo "Rodada $i -> RTP acumulado: $RTP_BLOCO %"
        fi
    done

    RTP=$(awk "BEGIN {print ($GANHO_TOTAL / ($TOTAL_RODADAS * $APOSTA)) * 100}")

    # Classificação com cores
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
        perc=$(awk "BEGIN {print ($qtd / $TOTAL_RODADAS) * 100}")
        contrib=$(awk "BEGIN {print ($qtd * $ganho / ($TOTAL_RODADAS * $APOSTA)) * 100}")
        echo "Prêmio $ganho créditos -> $qtd vezes (${perc}% das rodadas) | Contribuição RTP: ${contrib}%"
    done

    echo
    echo "Retorno total: $GANHO_TOTAL créditos"
    echo -e "RTP estimado final: $RTP % -> $CHANCE"
    echo "RTP teórico oficial aproximado: ~96 %"
    echo
    read -p "Pressione ENTER para voltar ao menu..." dummy
done
