#!/bin/bash

COMPOSE_FILE="docker-compose.yml"
LB_CONF="nginx-lb.conf"

# -------------------------------------------------------------------------
# FUNÇÃO PARA LIMPAR CACHE E FORMATAR AMBIENTE
# -------------------------------------------------------------------------
clear_cache() {
    echo "[🧹] Iniciando limpeza profunda de cache e resíduos..."
    if [ -f "$COMPOSE_FILE" ]; then
        docker compose down -v --remove-orphans &>/dev/null
    fi
    rm -rf ./shared-data
    mkdir -p ./shared-data
    chmod 777 ./shared-data
    echo "[✅] Ambiente limpo com sucesso!"
}

install_dependencies() {
    if command -v docker &>/dev/null && docker compose version &>/dev/null; then
        return 0
    fi
    echo "❌ Erro: Instale o Docker e Docker Compose antes de prosseguir."
    exit 1
}

# -------------------------------------------------------------------------
# GERAÇÃO DINÂMICA DE CONFIGURAÇÕES
# -------------------------------------------------------------------------
generate_configs() {
    echo "[+] Gerando configuração do Load Balancer ($LB_CONF)..."
    cat << 'EOF' > $LB_CONF
events { worker_connections 1024; }
http {
    upstream backend_cluster {
        server app1:80 max_fails=1 fail_timeout=1s;
        server app2:80 max_fails=1 fail_timeout=1s;
        server app3:80 max_fails=1 fail_timeout=1s;
    }
    server {
        listen 80;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri $uri/ @proxy;
        }

        location @proxy {
            proxy_pass http://backend_cluster;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

            proxy_connect_timeout 200ms;
            proxy_read_timeout 200ms;
            proxy_send_timeout 200ms;
            proxy_next_upstream error timeout invalid_header http_502 http_503 http_504;

            add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
        }

        location /stats.json {
            root /shared;
            add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
            default_type application/json;
        }
    }
}
EOF

    # HTML do Dashboard Interativo
    DASHBOARD_HTML='<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Dashboard Cluster</title><style>body{font-family:sans-serif;text-align:center;padding-top:30px;background:#f4f6f7;margin:0;} .container{max-width:850px;margin:0 auto;} .header{background:#2c3e50;color:white;padding:20px;border-radius:8px;margin-bottom:20px;} .card{background:white;padding:20px;margin:10px;display:inline-block;width:210px;border-radius:8px;box-shadow:0 4px 6px rgba(0,0,0,0.05);transition:all 0.3s;} .online{border-top:5px solid #2ecc71;} .offline{border-top:5px solid #e74c3c;opacity:0.6;background:#fce4e4;} .badge{display:inline-block;padding:4px 8px;border-radius:12px;font-size:0.8em;font-weight:bold;color:white;} .bg-online{background:#2ecc71;} .bg-offline{background:#e74c3c;} .counter{font-size:2.5em;color:#2c3e50;margin:10px 0; font-weight:bold;}</style></head><body><div class="container"><div class="header"><h1>⚡ Painel de Infraestrutura Ativo</h1><p>Status do Cluster: <span id="live-responder" style="color:#f1c40f;font-weight:bold;">Sincronizando...</span></p></div><div><div id="card-app1" class="card"><h3>Servidor APP 1</h3><span id="badge-app1" class="badge">...</span><div id="count-app1" class="counter">0</div></div><div id="card-app2" class="card"><h3>Servidor APP 2</h3><span id="badge-app2" class="badge">...</span><div id="count-app2" class="counter">0</div></div><div id="card-app3" class="card"><h3>Servidor APP 3</h3><span id="badge-app3" class="badge">...</span><div id="count-app3" class="counter">0</div></div></div></div><script>function updateData(){fetch("/stats.json",{cache:"no-store"}).then(r=>r.json()).then(data=>{document.getElementById("live-responder").innerText="Monitorando Ativo";["app1","app2","app3"].forEach(id=>{const card=document.getElementById("card-"+id);const badge=document.getElementById("badge-"+id);document.getElementById("count-"+id).innerText=data[id].count;if(data[id].status==="online"){card.className="card online";badge.className="badge bg-online";badge.innerText="ONLINE";}else{card.className="card offline";badge.className="badge bg-offline";badge.innerText="CONGELADO";}});}).catch(e=>console.log("Aguardando JSON..."));}setInterval(updateData,500);updateData();</script></body></html>'

    # SCRIPT DE CONTAGEM INDIVIDUAL E SOMA DE REQUISIÇÕES DOS CAÍDOS
    INTERNAL_APP_SCRIPT='
    rm -f /var/log/nginx/access.log && touch /var/log/nginx/access.log
    nginx
    sleep 1

    echo "0" > /shared/${MY_ID}.txt
    echo "0" > /shared/${MY_ID}.inherited

    while true; do
        date +%s > /shared/${MY_ID}.heartbeat
        now=$(date +%s)
        
        h1=$([ -f /shared/app1.heartbeat ] && cat /shared/app1.heartbeat || echo 0)
        h2=$([ -f /shared/app2.heartbeat ] && cat /shared/app2.heartbeat || echo 0)
        h3=$([ -f /shared/app3.heartbeat ] && cat /shared/app3.heartbeat || echo 0)
        
        s1="online"; [ $((now - h1)) -gt 3 ] && s1="offline"
        s2="online"; [ $((now - h2)) -gt 3 ] && s2="offline"
        s3="online"; [ $((now - h3)) -gt 3 ] && s3="offline"

        # LÓGICA DO FAILOVER: Se o APP atual está vivo, ele verifica se precisa herdar dados
        if [ "$s1" = "offline" ] && [ "${MY_ID}" != "app1" ]; then
            # Se app1 caiu, o primeiro nó disponível (app2 ou app3) assume as requisições dele
            if [ "${MY_ID}" = "app2" ] || { [ "${MY_ID}" = "app3" ] && [ "$s2" = "offline" ]; }; then
                v1=$(cat /shared/app1.txt 2>/dev/null || echo 0)
                if [ "$v1" -gt 0 ]; then
                    inherited=$(cat /shared/${MY_ID}.inherited 2>/dev/null || echo 0)
                    echo "$((inherited + v1))" > /shared/${MY_ID}.inherited
                    echo "0" > /shared/app1.txt
                fi
            fi
        fi

        if [ "$s2" = "offline" ] && [ "${MY_ID}" != "app2" ]; then
            if [ "${MY_ID}" = "app1" ] || { [ "${MY_ID}" = "app3" ] && [ "$s1" = "offline" ]; }; then
                v2=$(cat /shared/app2.txt 2>/dev/null || echo 0)
                if [ "$v2" -gt 0 ]; then
                    inherited=$(cat /shared/${MY_ID}.inherited 2>/dev/null || echo 0)
                    echo "$((inherited + v2))" > /shared/${MY_ID}.inherited
                    echo "0" > /shared/app2.txt
                fi
            fi
        fi

        if [ "$s3" = "offline" ] && [ "${MY_ID}" != "app3" ]; then
            if [ "${MY_ID}" = "app1" ] || { [ "${MY_ID}" = "app2" ] && [ "$s1" = "offline" ]; }; then
                v3=$(cat /shared/app3.txt 2>/dev/null || echo 0)
                if [ "$v3" -gt 0 ]; then
                    inherited=$(cat /shared/${MY_ID}.inherited 2>/dev/null || echo 0)
                    echo "$((inherited + v3))" > /shared/${MY_ID}.inherited
                    echo "0" > /shared/app3.txt
                fi
            fi
        fi

        # Montagem do JSON final lido pelo navegador
        c1=$(cat /shared/app1.txt 2>/dev/null || echo 0)
        c2=$(cat /shared/app2.txt 2>/dev/null || echo 0)
        c3=$(cat /shared/app3.txt 2>/dev/null || echo 0)

        # Adiciona os herdados se o nó principal estiver online
        i1=$(cat /shared/app1.inherited 2>/dev/null || echo 0)
        i2=$(cat /shared/app2.inherited 2>/dev/null || echo 0)
        i3=$(cat /shared/app3.inherited 2>/dev/null || echo 0)

        total_c1=$((c1 + i1))
        total_c2=$((c2 + i2))
        total_c3=$((c3 + i3))

        # Se congelado, exibe o último valor antes de sumir
        [ "$s1" = "offline" ] && total_c1=$(cat /shared/app1.frozen 2>/dev/null || echo 0)
        [ "$s2" = "offline" ] && total_c2=$(cat /shared/app2.frozen 2>/dev/null || echo 0)
        [ "$s3" = "offline" ] && total_c3=$(cat /shared/app3.frozen 2>/dev/null || echo 0)

        echo "{\"app1\":{\"count\":$total_c1,\"status\":\"$s1\"},\"app2\":{\"count\":$total_c2,\"status\":\"$s2\"},\"app3\":{\"count\":$total_c3,\"status\":\"$s3\"}}" > /shared/stats.json
        sleep 1
    done &

    # Capturador de requisições em tempo real (1 em 1)
    tail -f /var/log/nginx/access.log | while read -r line; do
        if echo "$line" | grep -q '"GET / HTTP/'; then
            count=$(cat /shared/${MY_ID}.txt 2>/dev/null || echo 0)
            count=$((count+1))
            echo "$count" > /shared/${MY_ID}.txt
            
            # Atualiza o congelado para segurança caso caia logo em seguida
            inherited=$(cat /shared/${MY_ID}.inherited 2>/dev/null || echo 0)
            echo "$((count + inherited))" > /shared/${MY_ID}.frozen
        fi
    done
    '

    echo "[+] Gerando topologia Docker Compose ($COMPOSE_FILE)..."
    cat << EOF > $COMPOSE_FILE
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
    entrypoint: 
      - /bin/sh
      - -c
      - |
        mkdir -p /usr/share/nginx/html
        echo '$DASHBOARD_HTML' > /usr/share/nginx/html/index.html
        nginx -g 'daemon off;'
    depends_on:
      - app1
      - app2
      - app3
    networks:
      - infra_network

  app1:
    image: nginx:alpine
    container_name: app1
    environment:
      - MY_ID=app1
    networks:
      - infra_network
    volumes:
      - ./shared-data:/shared
    command: ["/bin/sh", "-c", "$INTERNAL_APP_SCRIPT"]

  app2:
    image: nginx:alpine
    container_name: app2
    environment:
      - MY_ID=app2
    networks:
      - infra_network
    volumes:
      - ./shared-data:/shared
    command: ["/bin/sh", "-c", "$INTERNAL_APP_SCRIPT"]

  app3:
    image: nginx:alpine
    container_name: app3
    environment:
      - MY_ID=app3
    networks:
      - infra_network
    volumes:
      - ./shared-data:/shared
    command: ["/bin/sh", "-c", "$INTERNAL_APP_SCRIPT"]

networks:
  infra_network:
    driver: bridge
EOF
}

# -------------------------------------------------------------------------
# INTERFACES DE CONTROLE CLI
# -------------------------------------------------------------------------
case "$1" in
    up)
        clear_cache
        install_dependencies
        generate_configs
        echo "[+] Subindo a infraestrutura..."
        docker compose up -d --remove-orphans
        echo "[✅] Sucesso! Painel em: http://localhost:8090"
        ;;
    down)
        docker compose down -v
        rm -rf ./shared-data
        echo "[✅] Cluster removido."
        ;;
    stop)
        if [ -z "$2" ]; then exit 1; fi
        docker compose stop $2
        echo "[🛑] Nó $2 parado."
        ;;
    start)
        if [ -z "$2" ]; then exit 1; fi
        docker compose start $2
        echo "[🚀] Nó $2 reativado."
        ;;
    *)
        echo "Uso: sudo $0 {up|down|stop|start}"
        exit 1
        ;;
esac
