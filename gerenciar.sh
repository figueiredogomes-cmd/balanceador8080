#!/bin/bash

COMPOSE_FILE="docker-compose.yml"
LB_CONF="nginx-lb.conf"
TRAFEGO_PID_FILE="./shared-data/trafego.pid"

# -------------------------------------------------------------------------
# LIMPEZA DO AMBIENTE
# -------------------------------------------------------------------------
clear_cache() {
    echo "[🧹] Realizando limpeza profunda de processos e cache..."
    
    if [ -f "$TRAFEGO_PID_FILE" ]; then
        kill -9 $(cat "$TRAFEGO_PID_FILE") 2>/dev/null
        rm -f "$TRAFEGO_PID_FILE"
    fi

    if [ -f "$COMPOSE_FILE" ]; then
        docker compose down -v --remove-orphans &>/dev/null
    fi

    rm -rf ./shared-data
    mkdir -p ./shared-data
    chmod -R 777 ./shared-data

    # Cada servidor inicia rigorosamente com zero requisições
    echo "0" > ./shared-data/app1.txt
    echo "0" > ./shared-data/app2.txt
    echo "0" > ./shared-data/app3.txt
}

# -------------------------------------------------------------------------
# GERADOR DE TRÁFEGO REAL (SIMULADOR DE USUÁRIOS ACESSANDO)
# -------------------------------------------------------------------------
iniciar_trafego_real() {
    echo "[🚀] Iniciando fluxo de requisições contínuas de usuários..."
    (
        echo "$$" > "$TRAFEGO_PID_FILE"
        sleep 5 # Aguarda o Nginx iniciar completamente
        while true; do
            # Faz uma requisição HTTP real no balanceador de carga (Porta 8090)
            curl -s http://localhost:8090/ > /dev/null
            sleep 0.25 # Intervalo para os números subirem de forma visível
        done
    ) &
}

# -------------------------------------------------------------------------
# GERAÇÃO DAS CONFIGURAÇÕES DA INFRAESTRUTURA
# -------------------------------------------------------------------------
generate_configs() {
    # Configuração nativa do Nginx para Load Balancing Real
    cat << 'EOF' > $LB_CONF
events { worker_connections 1024; }
http {
    upstream backend_cluster {
        # Distribuição Round Robin pura entre os 3 servidores de aplicação
        server app1:80 max_fails=1 fail_timeout=1s;
        server app2:80 max_fails=1 fail_timeout=1s;
        server app3:80 max_fails=1 fail_timeout=1s;
    }
    server {
        listen 80;
        location / {
            proxy_pass http://backend_cluster;
            
            # Garante failover agressivo: se um nó falhar, o Nginx redireciona na hora para o próximo saudável
            proxy_next_upstream error timeout invalid_header http_502 http_503 http_504;
            proxy_connect_timeout 150ms;
            proxy_read_timeout 150ms;
            
            add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
        }
        # Endpoint onde o Dashboard busca os dados JSON atualizados em tempo real
        location /stats.json {
            alias /shared/stats.json;
            add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
        }
    }
}
EOF

    # Arquivo Docker Compose que monta o ecossistema isolado
    cat << 'EOF' > $COMPOSE_FILE
version: '3.8'
services:
  loadbalancer:
    image: nginx:alpine
    container_name: loadbalancer
    ports:
      - "8090:80"
    volumes:
      - ./nginx-lb.conf:/etc/nginx/nginx.conf:ro
      - ./shared-data:/shared
    depends_on: [app1, app2, app3]
    networks: [infra_net]

  app1:
    image: nginx:alpine
    container_name: app1
    networks: [infra_net]
    volumes:
      - ./shared-data:/shared
    command:
      - /bin/sh
      - -c
      - |
        nginx
        # HTML do Dashboard no formato de Terminal CRT Antigo (Fundo Preto / Letras Verdes)
        echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>TERMINAL MONITOR</title><style>body{background-color:#050505;color:#00ff00;font-family:"Courier New",monospace;padding:30px;text-shadow:0 0 5px #00ff00;} .terminal{border:2px solid #00ff00;padding:25px;max-width:850px;margin:0 auto;box-shadow:inset 0 0 15px #000;} h1{text-align:center;border-bottom:2px dashed #00ff00;padding-bottom:10px;font-size:1.5em;margin-top:0;} .grid{display:flex;justify-content:space-between;margin-top:30px;} .box{border:1px solid #00ff00;width:30%;padding:15px;background:#000;box-sizing:border-box;} .title{font-weight:bold;text-align:center;border-bottom:1px solid #00ff00;padding-bottom:5px;font-size:1.1em;} .count{font-size:3em;text-align:center;margin:15px 0;font-weight:bold;} .status{text-align:center;font-weight:bold;} .online{color:#00ff00;} .offline{color:#ff0000;animation:blink 1s infinite;} @keyframes blink{50%{opacity:0.2;}}</style></head><body><div class="terminal"><h1>>>> MONITOR DE INFRAESTRUTURA [BALANCEAMENTO REAL] <<<</h1><div style="text-align:center;margin:10px 0;font-size:0.9em;">CONCEITO DE DISTRIBUIÇÃO EQUILIBRADA ATIVA - HTTP://LOCALHOST:8090</div><div class="grid"><div class="box"><div class="title">[ SERVIDOR_01 ]</div><div class="count" id="c1">0</div><div class="status">STATUS: <span id="s1">...</span></div></div><div class="box"><div class="title">[ SERVIDOR_02 ]</div><div class="count" id="c2">0</div><div class="status">STATUS: <span id="s2">...</span></div></div><div class="box"><div class="title">[ SERVIDOR_03 ]</div><div class="count" id="c3">0</div><div class="status">STATUS: <span id="s3">...</span></div></div></div></div><script>function update(){fetch("/stats.json",{cache:"no-store"}).then(r=>r.json()).then(d=>{for(let i=1;i<=3;i++){document.getElementById("c"+i).innerText=d["app"+i];document.getElementById("s"+i).innerText=d["status"+i];document.getElementById("s"+i).className=d["status"+i]==="ONLINE"?"online":"offline";}}).catch(e=>console.log("ERR"));}setInterval(update,300);update();</script></body></html>' > /usr/share/nginx/html/index.html
        
        # Interceptador interno de requisições REAIS do Servidor 1
        tail -f /var/log/nginx/access.log | while read -r line; do
          if echo "$line" | grep -q '"GET / HTTP/'; then
            c=$(cat /shared/app1.txt 2>/dev/null || echo 0); echo "$((c+1))" > /shared/app1.txt
          fi
        done &

        # Consolidador de dados central do Cluster (Gera o JSON lido pela página)
        while true; do
          echo "yes" > /shared/app1.alive
          
          s1="ONLINE"; [ ! -f /shared/app1.alive ] && s1="CONGELADO"
          s2="ONLINE"; [ ! -f /shared/app2.alive ] && s2="CONGELADO"
          s3="ONLINE"; [ ! -f /shared/app3.alive ] && s3="CONGELADO"

          c1=$(cat /shared/app1.txt 2>/dev/null || echo 0)
          c2=$(cat /shared/app2.txt 2>/dev/null || echo 0)
          c3=$(cat /shared/app3.txt 2>/dev/null || echo 0)

          echo "{\"app1\":$c1,\"app2\":$c2,\"app3\":$c3,\"status1\":\"$s1\",\"status2\":\"$s2\",\"status3\":\"$s3\"}" > /shared/stats.json
          sleep 0.4
        done

  app2:
    image: nginx:alpine
    container_name: app2
    networks: [infra_net]
    volumes:
      - ./shared-data:/shared
    command:
      - /bin/sh
      - -c
      - |
        nginx
        # Envia sinal de atividade (Heartbeat)
        while true; do echo "yes" > /shared/app2.alive; sleep 1; done &
        
        # Interceptador interno de requisições REAIS do Servidor 2
        tail -f /var/log/nginx/access.log | while read -r line; do
          if echo "$line" | grep -q '"GET / HTTP/'; then
            c=$(cat /shared/app2.txt 2>/dev/null || echo 0); echo "$((c+1))" > /shared/app2.txt
          fi
        done

  app3:
    image: nginx:alpine
    container_name: app3
    networks: [infra_net]
    volumes:
      - ./shared-data:/shared
    command:
      - /bin/sh
      - -c
      - |
        nginx
        # Envia sinal de atividade (Heartbeat)
        while true; do echo "yes" > /shared/app3.alive; sleep 1; done &
        
        # Interceptador interno de requisições REAIS do Servidor 3 (Corrigido)
        tail -f /var/log/nginx/access.log | while read -r line; do
          if echo "$line" | grep -q '"GET / HTTP/'; then
            c=$(cat /shared/app3.txt 2>/dev/null || echo 0); echo "$((c+1))" > /shared/app3.txt
          fi
        done

networks:
  infra_net:
    driver: bridge
EOF
}

# -------------------------------------------------------------------------
# INTERFACE DE COMANDO CLI
# -------------------------------------------------------------------------
case "$1" in
    up)
        clear_cache
        generate_configs
        echo "[+] Inicializando infraestrutura real com Docker Compose..."
        docker compose up -d --remove-orphans
        iniciar_trafego_real
        echo "[✅] Sucesso! Painel ativo baseado em métricas REAIS: http://localhost:8090"
        ;;
    down)
        clear_cache
        echo "[✅] Todos os recursos foram finalizados e limpos."
        ;;
    stop)
        if [ -z "$2" ]; then echo "❌ Especifique o nó: app1, app2 ou app3"; exit 1; fi
        rm -f "./shared-data/$2.alive"
        docker compose stop $2
        echo "[✅] Nó $2 foi parado com sucesso (Estado: CONGELADO)."
        ;;
    start)
        if [ -z "$2" ]; then echo "❌ Especifique o nó: app1, app2 ou app3"; exit 1; fi
        echo "yes" > "./shared-data/$2.alive"
        docker compose start $2
        echo "[✅] Nó $2 foi reiniciado e reintroduzido no balanceamento."
        ;;
    *)
        echo "Use: ./gerenciar.sh [up | down | stop | start]"
        ;;
esac
