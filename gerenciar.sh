#!/bin/bash

COMPOSE_FILE="docker-compose.yml"
LB_CONF="nginx-lb.conf"

clear_cache() {
    echo "[🧹] Removendo contêineres antigos e limpando volumes..."
    # Força a paragem e remoção absoluta pelo nome para evitar o erro do daemon
    sudo docker rm -f balanceador asr_node1 asr_node2 asr_node3 2>/dev/null
    
    if [ -f "$COMPOSE_FILE" ]; then
        sudo docker compose down -v --remove-orphans &>/dev/null
    fi

    rm -rf ./shared-data
    mkdir -p ./shared-data
    chmod -R 777 ./shared-data

    echo "0" > ./shared-data/app1.txt
    echo "0" > ./shared-data/app2.txt
    echo "0" > ./shared-data/app3.txt
    echo "Nenhum" > ./shared-data/last_node.txt
}

generate_configs() {
    # Nginx Load Balancer Config
    cat << 'EOF' > $LB_CONF
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    upstream asr_cluster {
        server asr_node1:3000 max_fails=1 fail_timeout=1s;
        server asr_node2:3000 max_fails=1 fail_timeout=1s;
        server asr_node3:3000 max_fails=1 fail_timeout=1s;
    }
    server {
        listen 80;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        location /api {
            proxy_pass http://asr_cluster/;
            proxy_next_upstream error timeout invalid_header http_502 http_503 http_504;
            proxy_connect_timeout 150ms;
            proxy_read_timeout 150ms;
            add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
        }
        location /stats.json {
            alias /shared/stats.json;
            add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
            add_header Access-Control-Allow-Origin "*";
        }
    }
}
EOF

    # Docker Compose sem escaping dinâmico de variáveis para o shell
    cat << 'EOF' > $COMPOSE_FILE
services:
  balanceador:
    image: nginx:alpine
    container_name: balanceador
    ports:
      - "8090:80"
    volumes:
      - ./nginx-lb.conf:/etc/nginx/nginx.conf:ro
      - ./shared-data:/shared
    command:
      - /bin/sh
      - -c
      - |
        echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Topologia ASR</title><link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet"><style>body{background-color:#f3f4f6;color:#1f2937;font-family:"Inter",sans-serif;margin:0;padding:40px;display:flex;justify-content:center;} .container{width:100%;max-width:1000px;} .header-panel{background-color:#2d3748;color:#ffffff;border-radius:12px;padding:30px;text-align:center;box-shadow:0 4px 6px -1px rgba(0,0,0,0.1);margin-bottom:30px;} .header-panel h1{margin:0;font-size:2em;font-weight:700;} .status-api{font-size:1.2em;color:#cbd5e0;margin-top:12px;font-weight:600;} #current-node{color:#63b3ed;text-shadow:0 0 4px rgba(99,179,237,0.5);font-weight:700;} .grid{display:flex;gap:20px;justify-content:space-between;} .card{background:#ffffff;border-radius:12px;width:32%;padding:30px;box-sizing:border-box;box-shadow:0 4px 6px -1px rgba(0,0,0,0.05);border:1px solid #e2e8f0;text-align:center;} .card-title{font-size:1.15em;font-weight:700;color:#2d3748;margin-bottom:20px;} .count{font-size:4.5em;font-weight:700;color:#1a202c;margin:20px 0;} .status-badge{display:inline-block;padding:6px 16px;border-radius:20px;font-weight:600;font-size:0.85em;} .online-badge{background-color:#c6f6d5;color:#22543d;} .offline-badge{background-color:#fed7d7;color:#742a2a;animation:pulse 1s infinite;} @keyframes pulse{0%{opacity:1;}50%{opacity:0.4;}100%{opacity:1;}}</style></head><body><div class="container"><div class="header-panel"><h1>⚡ Topologia Cluster ASR Ativo</h1><div class="status-api">Instância respondendo agora: <span id="current-node">...</span></div></div><div class="grid"><div class="card"><div class="card-title">Servidor ASR 1</div><div class="count" id="c1">0</div><div><span id="s1" class="status-badge online-badge">ONLINE</span></div></div><div class="card"><div class="card-title">Servidor ASR 2</div><div class="count" id="c2">0</div><div><span id="s2" class="status-badge online-badge">ONLINE</span></div></div><div class="card"><div class="card-title">Servidor ASR 3</div><div class="count" id="c3">0</div><div><span id="s3" class="status-badge online-badge">ONLINE</span></div></div></div></div><script>function enviarRequisicaoCliente(){fetch("/api",{cache:"no-store"}).catch(e=>console.log("Requisitando..."));}function atualizarPainel(){fetch("/stats.json",{cache:"no-store"}).then(r=>r.json()).then(d=>{document.getElementById("current-node").innerText=d.last_node||"...";for(let i=1;i<=3;i++){document.getElementById("c"+i).innerText=d["app"+i];let sEl=document.getElementById("s"+i);if(d["status"+i]==="ONLINE"){sEl.innerText="ONLINE";sEl.className="status-badge online-badge";}else{sEl.innerText="CONGELADO";sEl.className="status-badge offline-badge";}}}).catch(e=>console.log("Sincronizando..."));}setInterval(enviarRequisicaoCliente,120);setInterval(atualizarPainel,200);atualizarPainel();</script></body></html>' > /usr/share/nginx/html/index.html
        nginx
        while true; do
          s1="ONLINE"; [ ! -f /shared/app1.alive ] && s1="CONGELADO"
          s2="ONLINE"; [ ! -f /shared/app2.alive ] && s2="CONGELADO"
          s3="ONLINE"; [ ! -f /shared/app3.alive ] && s3="CONGELADO"
          c1=$(cat /shared/app1.txt 2>/dev/null || echo 0)
          c2=$(cat /shared/app2.txt 2>/dev/null || echo 0)
          c3=$(cat /shared/app3.txt 2>/dev/null || echo 0)
          ln=$(cat /shared/last_node.txt 2>/dev/null || echo "Nenhum")
          echo "{\"app1\":$c1,\"app2\":$c2,\"app3\":$c3,\"status1\":\"$s1\",\"status2\":\"$s2\",\"status3\":\"$s3\",\"last_node\":\"$ln\"}" > /shared/stats.json
          rm -f /shared/*.alive
          sleep 0.2
        done
    depends_on: [asr_node1, asr_node2, asr_node3]
    networks: [cluster_net]

  asr_node1:
    image: node:18-alpine
    container_name: asr_node1
    networks: [cluster_net]
    volumes:
      - ./shared-data:/shared
    command:
      - sh
      - -c
      - |
        echo "const http = require('http'); const fs = require('fs'); http.createServer((req, res) => { try { const c = parseInt(fs.readFileSync('/shared/app1.txt', 'utf8').trim() || 0) + 1; fs.writeFileSync('/shared/app1.txt', String(c)); fs.writeFileSync('/shared/last_node.txt', 'Servidor ASR 1'); } catch(e){} res.writeHead(200, {'Content-Type': 'text/plain'}); res.end('OK'); }).listen(3000);" > server.js
        while true; do
          echo "yes" > /shared/app1.alive
          node server.js
          sleep 0.2
        done

  asr_node2:
    image: node:18-alpine
    container_name: asr_node2
    networks: [cluster_net]
    volumes:
      - ./shared-data:/shared
    command:
      - sh
      - -c
      - |
        echo "const http = require('http'); const fs = require('fs'); http.createServer((req, res) => { try { const c = parseInt(fs.readFileSync('/shared/app2.txt', 'utf8').trim() || 0) + 1; fs.writeFileSync('/shared/app2.txt', String(c)); fs.writeFileSync('/shared/last_node.txt', 'Servidor ASR 2'); } catch(e){} res.writeHead(200, {'Content-Type': 'text/plain'}); res.end('OK'); }).listen(3000);" > server.js
        while true; do
          echo "yes" > /shared/app2.alive
          node server.js
          sleep 0.2
        done

  asr_node3:
    image: node:18-alpine
    container_name: asr_node3
    networks: [cluster_net]
    volumes:
      - ./shared-data:/shared
    command:
      - sh
      - -c
      - |
        echo "const http = require('http'); const fs = require('fs'); http.createServer((req, res) => { try { const c = parseInt(fs.readFileSync('/shared/app3.txt', 'utf8').trim() || 0) + 1; fs.writeFileSync('/shared/app3.txt', String(c)); fs.writeFileSync('/shared/last_node.txt', 'Servidor ASR 3'); } catch(e){} res.writeHead(200, {'Content-Type': 'text/plain'}); res.end('OK'); }).listen(3000);" > server.js
        while true; do
          echo "yes" > /shared/app3.alive
          node server.js
          sleep 0.2
        done

networks:
  cluster_net:
    driver: bridge
EOF
}

case "$1" in
    up)
        clear_cache
        generate_configs
        echo "[+] Inicializando topologia de balanceamento ASR no Docker..."
        sudo docker compose up -d --remove-orphans
        echo "[✅] Sucesso absoluto! Abra no seu navegador: http://localhost:8090"
        ;;
    down)
        clear_cache
        echo "[✅] Ambiente limpo com sucesso."
        ;;
    stop)
        if [ -z "$2" ]; then echo "❌ Defina o nó: asr_node1, asr_node2 ou asr_node3"; exit 1; fi
        sudo docker compose stop $2
        echo "[✅] Instância $2 pausada."
        ;;
    start)
        if [ -z "$2" ]; then echo "❌ Defina o nó: asr_node1, asr_node2 ou asr_node3"; exit 1; fi
        sudo docker compose start $2
        echo "[✅] Instância $2 reintroduzida."
        ;;
    *)
        echo "Use: ./gerenciar.sh [up | down | stop | start]"
        ;;
esac
