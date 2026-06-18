#!/bin/bash
# balanceador.sh
# Simulação de balanceamento de carga Round-Robin em Shell Script

# Lista de servidores (pode ser IP ou domínio)
SERVERS=("server1.com" "server2.com" "server3.com")

# Contador para alternar servidores
COUNTER=0

# Função para obter próximo servidor
get_next_server() {
    local server=${SERVERS[$COUNTER]}
    COUNTER=$(( (COUNTER + 1) % ${#SERVERS[@]} ))
    echo "$server"
}

# Loop para simular requisições
while true; do
    SERVER=$(get_next_server)
    echo "Enviando requisição para: $SERVER"
    
    # Simulação de requisição (pode trocar por curl real)
    curl -s -o /dev/null -w "Status: %{http_code}\n" "http://$SERVER"
    
    sleep 1 # intervalo entre requisições
done
