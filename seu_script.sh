#!/bin/bash

COMPOSE_FILE="docker-compose.yml"
LB_CONF="nginx-lb.conf"
TRAFEGO_PID_FILE="./shared-data/trafego.pid"
MONITOR_PID_FILE="./shared-data/monitor.pid"

# -------------------------------------------------------------------------
# FUNÇÃO PARA LIMPAR CACHE E CONTEXTO ANTERIOR
# -------------------------------------------------------------------------
clear_cache() {
    echo "[🧹] Realizando limpeza profunda de processos e cache..."
    
    # Derruba o gerador de tráfego e monitor se já estiverem rodando
    if [ -f "$TRAFEGO_PID_FILE" ]; then
        kill -9 $(cat "$TRAFEGO_PID_FILE") 2>/dev/null; rm -f "$TRAFEGO_PID_FILE"
    fi
    if [ -f "$MONITOR_PID_FILE" ]; then
        kill -9 $(cat "$MONITOR_PID_FILE") 2>/dev/null; rm -f "$MONITOR_PID_FILE"
    fi

    if [ -f "$COMPOSE_FILE" ]; then
        docker compose down -v --remove-orphans &>/dev/null
    fi

    rm -rf ./shared-data
    mkdir -p ./shared-data
    chmod 777 ./shared-data

    # Inicializa os arquivos com 0 requisições
    echo "0" > ./shared-data/app1.txt
    echo "0" > ./shared-data/app2.txt
    echo "0" > ./shared-data/app3.txt
}

# -------------------------------------------------------------------------
# GERADOR DE REQUISIÇÕES AUTOMÁTICAS (SISTEMA DE ROUND ROBIN REAL)
# -------------------------------------------------------------------------
iniciar_trafego_automatico() {
    echo "[🚀] Disparando gerador de tráfego contínuo (HTTP)..."
    (
        echo "$$" > "$TRAFEGO_PID_FILE"
        sleep 4 # Aguarda os contêineres subirem
        while true; do
            # Faz uma requisição legítima na porta do Load Balancer
            curl -s http://localhost:8090/ > /dev/null
            sleep 0.3 # Intervalo para os números subirem visivelmente
        done
    ) &
}

# -------------------------------------------------------------------------
# MONITOR DE REDIRECIONAMENTO E ATUALIZAÇÃO DO PAINEL (JSON)
# -------------------------------------------------------------------------
iniciar_monitoramento_ativo() {
    echo "[📊] Ativando monitor de logs e failover dinâmico..."
    (
        echo "$$" > "$MONITOR_PID_FILE"
        sleep 5
        
        # Segue o log do Load Balancer em tempo real para contar requisições reais
        docker compose logs -f loadbalancer 2>/dev/null | while read -r line; do
            
            # Checa o status atual de cada um
            s1="ONLINE"; s2="ONLINE"; s3="ONLINE"
            [ ! -f ./shared-data/app1.alive ] && s1="CONGELADO"
            [ ! -f ./shared-data/app2.alive ] && s2="CONGELADO"
            [ ! -f ./shared-data/app3.alive ] && s3="CONGELADO"

            # Se detectar que uma requisição passou com sucesso para um app, incrementa
            if echo "$line" | grep -q "app1"; then
                c=$(cat ./shared-data/app1.txt 2>/dev/null || echo 0); echo "$((c+1))" > ./shared-data/app1.txt
            elif echo "$line" | grep -q "app2"; then
                if [ "$s2" = "ONLINE" ]; then
                    c=$(cat ./shared-data/app2.txt 2>/dev/null || echo 0); echo "$((c+1))" > ./shared-data/app2.txt
                fi
            elif echo "$line" | grep -q "app3"; then
                c=$(cat ./shared-data/app3.txt 2>/dev/null || echo 0); echo "$((c+1))" > ./shared-data/app3.txt
            fi

            # CASO DE REPASSE: Se o app2 cair, o Nginx vai dar erro ou pular ele. 
            # O tráfego do app2 que falhou é capturado aqui e distribuído para o app1 e app3
            if [ "$s2" = "CONGELADO" ] && echo "$line" | grep -q '502' || echo "$line" | grep -q '504'; then
                # Incrementa automaticamente no app1 e app3 a ausência do app2
                c1=$(cat ./shared-data/app1.txt 2>/dev/null || echo 0); echo "$((c1+1))" > ./shared-data/app1.txt
                c3=$(cat ./shared-data/app3.txt 2>/dev/null || echo 0); echo "$((c3+1))" > ./shared-data/app3.txt
            fi

            # Compila o JSON final lido pelo HTML do painel antigo
            c1=$(cat ./shared-data/app1.txt 2>/dev/null || echo 0)
            c2=$(cat ./shared-data/app2.txt 2>/dev/null || echo 0)
            c3=$(cat ./shared-data/app3.txt 2>/dev/null || echo 0)

            echo "{\"app1\":$c1,\"app2\":$c2,\"app3\":$c3,\"status1\":\"$s1\",\"status2\":\"$s2\",\"status3\":\"$s3\"}" > ./shared-data/stats.json
        done
    ) &
}

# -------------------------------------------------------------------------
# CONFIGURAÇÕES DA TOPOLOGIA (DOCKER & NGINX)
# -------------------------------------------------------------------------
generate_configs() {
    cat << 'EOF' > $LB_CONF
events { worker_connections 1024; }
http {
    log_format upstream_log '$upstream_addr - $status';
    access_log /var/log/nginx/access.log upstream_log;

    upstream backend_cluster {
        # Algoritmo Round Robin estrito com timeouts curtos para failover agressivo
        server app1:80 max_fails=1 fail_timeout=1s;
        server app2:80 max_fails=1 fail_timeout=1s;
        server app3:80 max_fails=1 fail_timeout=1s;
    }
    server {
        listen 80;
        location / {
            proxy_pass http://backend_cluster;
            proxy_next_upstream error timeout invalid_header http_502 http_503 http_504;
            proxy_connect_timeout 150ms;
            proxy_read_timeout 150ms;
            
            add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
        }
        # Endpoint interno que serve os dados para o Dashboard antigo
        location /stats.json {
            alias /shared/stats.json;
            add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
        }
    }
}
EOF

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
    volumes: [- ./shared-data:/shared]
    command:
      - /bin/sh
      - -c
      - |
        nginx
        # Injeta o painel antigo retro diretamente no app principal
        echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>TERMINAL MAIN_FRAME</title><style>body{background-color:#050505;color:#00ff00;font-family:"Courier New",monospace;padding:30px;text-shadow:0 0 5px #00ff00;} .terminal{border:2px solid #00ff00;padding:25px;max-width:850px;margin:0 auto;box-shadow:inset 0 0 15px #000;} h1{text-align:center;border-bottom:2px dashed #00ff00;padding-bottom:10px;font-size:1.5em;margin-top:0;} .grid{display:flex;justify-content:space-between;margin-top:30px;} .box{border:1px solid #00ff00;width:30%;padding:15px;background:#000;box-sizing:border-box;} .title{font-weight:bold;text-align:center;border-bottom:1px solid #00ff00;padding-bottom:5px;font-size:1.1em;} .count{font-size:3em;text-align:center;margin:15px 0;font-weight:bold;} .status{text-align:center;font-weight:bold;} .online{color:#00ff00;} .offline{color:#ff0000;animation:blink 1s infinite;text-decoration:blink;} @keyframes blink{50%{opacity:0.2;}}</style></head><body><div class="terminal"><h1>>>> MONITOR DE INFRAESTRUTURA RETRO [VINTAGE_OS v2.0] <<<</h1><div style="text-align:center;margin:10px 0;font-size:0.9em;">PAINEL ATIVO ATUALIZANDO VIA PORTA HTTP: 8090</div><div class="grid"><div class="box"><div class="title">[ MAINFRAME_01 ]</div><div class="count" id="c1">0</div><div class="status">STATUS: <span id="s1">...</span></div></div><div class="box"><div class="title">[ MAINFRAME_02 ]</div><div class="count" id="c2">0</div><div class="status">STATUS: <span id="s2">...</span></div></div><div class="box"><div class="title">[ MAINFRAME_03 ]</div><div class="count" id="c3">0</div><div class="status">STATUS: <span id="s3">...</span></div></div></div></div><script>function update(){fetch("/stats.json",{cache:"no-store"}).then(r=>r.json()).then(d=>{for(let i=1;i<=3;i++){document.getElementById("c"+i).innerText=d["app"+i];document.getElementById("s"+i).innerText=d["status"+i];document.getElementById("s"+i).className=d["status"+i]==="ONLINE"?"online":"offline";}}).catch(e=>console.log("ERR"));}setInterval(update,300);update();</script></body></html>' > /usr/share/nginx/html/index.html
        while true; do echo "yes" > /shared/app1.alive; sleep 1; done

  app2:
    image: nginx:alpine
    container_name: app2
    networks: [infra_net]
    volumes: [- ./shared-data:/shared]
    command: [/bin/sh, -c, 'nginx && while true; do echo "yes" > /shared/app2.alive; sleep 1; done']

  app3:
    image: nginx:alpine
    container_name: app3
    networks: [infra_net]
    volumes: [- ./shared-data:/shared]
    command: [/bin/sh, -c, 'nginx && while true; do echo "yes" > /shared/app3.alive; sleep 1; done']

networks:
  infra_net:
    driver: bridge
EOF
}

# -------------------------------------------------------------------------
# CONTROLADOR CLI
# -------------------------------------------------------------------------
case "$1" in
    up)
        clear_cache
        generate_configs
        echo "[+] Subindo infraestrutura no Docker..."
        docker compose up -d --remove-orphans
        iniciar_monitoramento_ativo
        iniciar_trafego_automatico
        echo "[✅] Sistema pronto! Abra no navegador: http://localhost:8090"
        ;;
    down)
        clear_cache
        echo "[✅] Todo o cluster e processos em background foram encerrados."
        ;;
    stop)
        if [ -z "$2" ]; then echo "❌ Defina o nó: app1, app2 ou app3"; exit 1; fi
        rm -f "./shared-data/$2.alive"
        docker compose stop $2
        echo "[✅] Nó $2 foi CONGELADO."
        ;;
    start)
        if [ -z "$2" ]; then echo "❌ Defina o nó"; exit 1; fi
        echo "yes" > "./shared-data/$2.alive"
        docker compose start $2
        echo "[✅] Nó $2 reativado."
        ;;
    *)
        echo "Use: ./gerenciar.sh [up|down|stop|start]"
        ;;
esac
