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

    # Inicializa os contadores reais zerados
    echo "0" > ./shared-data/app1.txt
    echo "0" > ./shared-data/app2.txt
    echo "0" > ./shared-data/app3.txt
}

# -------------------------------------------------------------------------
# GERADOR DE TRÁFEGO AUTOMÁTICO (ENVIA SOLICITAÇÕES HTTP REAIS)
# -------------------------------------------------------------------------
iniciar_trafego_real() {
    echo "[🚀] Iniciando fluxo automático de requisições de usuários..."
    (
        echo "$$" > "$TRAFEGO_PID_FILE"
        sleep 5 # Aguarda os serviços estabilizarem
        while true; do
            # Dispara um acesso real contra a porta exposta do balanceador de carga
            curl -s http://localhost:8090/ > /dev/null
            sleep 0.25 # Frequência estável para os números subirem de forma fluida
        done
    ) &
}

# -------------------------------------------------------------------------
# GERAÇÃO DAS CONFIGURAÇÕES DA INFRAESTRUTURA
# -------------------------------------------------------------------------
generate_configs() {
    # Nginx configurado para ler cabeçalhos customizados que controlam o contador real
    cat << 'EOF' > $LB_CONF
events { worker_connections 1024; }
http {
    upstream backend_cluster {
        # Algoritmo puro de distribuição equilibrada (Round Robin)
        server app1:80 max_fails=1 fail_timeout=1s;
        server app2:80 max_fails=1 fail_timeout=1s;
        server app3:80 max_fails=1 fail_timeout=1s;
    }
    server {
        listen 80;
        location / {
            proxy_pass http://backend_cluster;
            proxy_set_header X-Real-IP $remote_addr;
            
            # Failover: retira nós caídos da rota em tempo de execução
            proxy_next_upstream error timeout invalid_header http_502 http_503 http_504;
            proxy_connect_timeout 150ms;
            proxy_read_timeout 150ms;
            
            add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
        }
        # Compartilhamento do arquivo centralizado com as métricas dinâmicas coletadas
        location /stats.json {
            alias /shared/stats.json;
            add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
            add_header Access-Control-Allow-Origin "*";
        }
    }
}
EOF

    # Docker Compose montando a aplicação isolada
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
        # Injeta o painel original com fundo claro e cartões modernos diretamente no servidor principal
        echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Dashboard Ativo</title><link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet"><style>body{background-color:#f3f4f6;color:#1f2937;font-family:"Inter",sans-serif;margin:0;padding:40px;display:flex;justify-content:center;} .container{width:100%;max-width:1000px;} .header-panel{background-color:#2d3748;color:#ffffff;border-radius:12px;padding:30px;text-align:center;box-shadow:0 4px 6px -1px rgba(0,0,0,0.1);margin-bottom:30px;} .header-panel h1{margin:0;font-size:2em;font-weight:700;display:flex;justify-content:center;align-items:center;gap:10px;} .status-api{font-size:0.95em;color:#cbd5e0;margin-top:12px;font-weight:400;} .grid{display:flex;gap:20px;justify-content:space-between;} .card{background:#ffffff;border-radius:12px;width:32%;padding:30px;box-sizing:border-box;box-shadow:0 4px 6px -1px rgba(0,0,0,0.05);border:1px solid #e2e8f0;text-align:center;transition:all 0.3s ease;} .card-title{font-size:1.15em;font-weight:700;color:#2d3748;margin-bottom:20px;} .count{font-size:4.5em;font-weight:700;color:#1a202c;margin:20px 0;} .status-badge{display:inline-block;padding:6px 16px;border-radius:20px;font-weight:600;font-size:0.85em;} .online-badge{background-color:#c6f6d5;color:#22543d;} .offline-badge{background-color:#fed7d7;color:#742a2a;animation:pulse 1.5s infinite;} @keyframes pulse{0%{opacity:1;}50%{opacity:0.5;}100%{opacity:1;}}</style></head><body><div class="container"><div class="header-panel"><h1>⚡ Painel de Infraestrutura Ativo</h1><div class="status-api">Estado operacional do cluster em tempo real</div></div><div class="grid"><div class="card"><div class="card-title">Servidor APP 1</div><div class="count" id="c1">0</div><div><span id="s1" class="status-badge online-badge">ONLINE</span></div></div><div class="card"><div class="card-title">Servidor APP 2</div><div class="count" id="c2">0</div><div><span id="s2" class="status-badge online-badge">ONLINE</span></div></div><div class="card"><div class="card-title">Servidor APP 3</div><div class="count" id="c3">0</div><div><span id="s3" class="status-badge online-badge">ONLINE</span></div></div></div></div><script>function update(){fetch("/stats.json",{cache:"no-store"}).then(r=>r.json()).then(d=>{for(let i=1;i<=3;i++){document.getElementById("c"+i).innerText=d["app"+i];let sEl=document.getElementById("s"+i);if(d["status"+i]==="ONLINE"){sEl.innerText="ONLINE";sEl.className="status-badge online-badge";}else{sEl.innerText="CONGELADO";sEl.className="status-badge offline-badge";}}}).catch(e=>console.log("Aguardando sincronia..."));}setInterval(update,300);update();</script></body></html>' > /usr/share/nginx/html/index.html
        nginx

        # Interceptador e consolidador central que roda em background monitorando o tráfego legítimo
        while true; do
          # Se o próprio container receber conexão (porta local 80), adiciona +1 ao seu arquivo de contagem
          if netstat -an | grep :80 | grep ESTABLISHED >/dev/null; then
             c=$(cat /shared/app1.txt 2>/dev/null || echo 0); echo "$((c+1))" > /shared/app1.txt
          fi

          echo "yes" > /shared/app1.alive
          s1="ONLINE"; [ ! -f /shared/app1.alive ] && s1="CONGELADO"
          s2="ONLINE"; [ ! -f /shared/app2.alive ] && s2="CONGELADO"
          s3="ONLINE"; [ ! -f /shared/app3.alive ] && s3="CONGELADO"

          c1=$(cat /shared/app1.txt 2>/dev/null || echo 0)
          c2=$(cat /shared/app2.txt 2>/dev/null || echo 0)
          c3=$(cat /shared/app3.txt 2>/dev/null || echo 0)

          echo "{\"app1\":$c1,\"app2\":$c2,\"app3\":$c3,\"status1\":\"$s1\",\"status2\":\"$s2\",\"status3\":\"$s3\"}" > /shared/stats.json
          sleep 0.25
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
        while true; do
          if netstat -an | grep :80 | grep ESTABLISHED >/dev/null; then
             c=$(cat /shared/app2.txt 2>/dev/null || echo 0); echo "$((c+1))" > /shared/app2.txt
          fi
          echo "yes" > /shared/app2.alive
          sleep 0.25
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
        while true; do
          if netstat -an | grep :80 | grep ESTABLISHED >/dev/null; then
             c=$(cat /shared/app3.txt 2>/dev/null || echo 0); echo "$((c+1))" > /shared/app3.txt
          fi
          echo "yes" > /shared/app3.alive
          sleep 0.25
        done

networks:
  infra_net:
    driver: bridge
EOF
}

# -------------------------------------------------------------------------
# INTERFACE CLI DE COMANDO
# -------------------------------------------------------------------------
case "$1" in
    up)
        clear_cache
        generate_configs
        echo "[+] Inicializando infraestrutura ativa no Docker..."
        docker compose up -d --remove-orphans
        iniciar_trafego_real
        echo "[✅] Sucesso! Painel operacional ativo: http://localhost:8090"
        ;;
    down)
        clear_cache
        echo "[✅] Ambiente limpo e processos de background encerrados."
        ;;
    stop)
        if [ -z "$2" ]; then echo "❌ Defina o nó: app1, app2 ou app3"; exit 1; fi
        rm -f "./shared-data/$2.alive"
        docker compose stop $2
        echo "[✅] Nó $2 parado com sucesso (Métricas preservadas)."
        ;;
    start)
        if [ -z "$2" ]; then echo "❌ Defina o nó: app1, app2 ou app3"; exit 1; fi
        echo "yes" > "./shared-data/$2.alive"
        docker compose start $2
        echo "[✅] Nó $2 reintroduzido no balanceamento de carga."
        ;;
    *)
        echo "Use: ./gerenciar.sh [up | down | stop | start]"
        ;;
esac
