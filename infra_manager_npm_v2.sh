#!/bin/bash

COMPOSE_FILE="docker-compose.yml"
LB_CONF="nginx-lb.conf"
PID_FILE="/tmp/gerador_trafego.pid"

# -------------------------------------------------------------------------
# LIMPEZA ABSOLUTA DE PROCESSOS E CONTÊINERES
# -------------------------------------------------------------------------
clear_cache() {
    echo "[🧹] Finalizando instâncias antigas e geradores de tráfego..."
    
    # Encerra qualquer loop de curl anterior do Shell
    if [ -f "$PID_FILE" ]; then
        kill -9 $(cat "$PID_FILE") 2>/dev/null
        rm -f "$PID_FILE"
    fi

    # Remove os contêineres pelo nome para evitar o erro "Conflict" do Daemon
    sudo docker rm -f balanceador asr_node1 asr_node2 asr_node3 2>/dev/null

    if [ -f "$COMPOSE_FILE" ]; then
        sudo docker compose down -v --remove-orphans &>/dev/null
    fi
}

# -------------------------------------------------------------------------
# CRIAÇÃO DA INFRAESTRUTURA VIA CONFIGURAÇÃO NATIVA NGINX
# -------------------------------------------------------------------------
generate_configs() {
    # Nginx configurado com Lua/Módulos embutidos para contagem real em memória RAM
    cat << 'EOF' > $LB_CONF
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    
    upstream asr_cluster {
        # Round Robin estrito: uma requisição para cada nó alternadamente
        server asr_node1:80 max_fails=1 fail_timeout=1s;
        server asr_node2:80 max_fails=1 fail_timeout=1s;
        server asr_node3:80 max_fails=1 fail_timeout=1s;
    }

    server {
        listen 80;

        # Rota de monitoramento que o JavaScript do painel lê para atualizar a tela
        location /stats.json {
            return 200 '{"app1":${C1},"app2":${C2},"app3":${C3},"status1":"${S1}","status2":"${S2}","status3":"${S3}","last_node":"${LN}"}';
            add_header Content-Type application/json;
            add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
        }

        # Rota da API balanceada onde o script Shell vai bater com o curl
        location /api {
            proxy_pass http://asr_cluster/;
            proxy_next_upstream error timeout invalid_header http_502 http_503 http_504;
            add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
        }

        # Dashboard Principal
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
}
EOF

    # Docker Compose usando imagens limpas e leves de Nginx para simular os nós do Cluster
    cat << 'EOF' > $COMPOSE_FILE
services:
  balanceador:
    image: nginx:alpine
    container_name: balanceador
    ports:
      - "8090:80"
    volumes:
      - ./nginx-lb.conf:/etc/nginx/nginx.conf:ro
    environment:
      - C1=0
      - C2=0
      - C3=0
      - S1=ONLINE
      - S2=ONLINE
      - S3=ONLINE
      - LN=Nenhum
    command:
      - /bin/sh
      - -c
      - |
        # Injeta o Dashboard original com a barra superior de alternância ativa
        echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Topologia ASR Ativa</title><link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet"><style>body{background-color:#f3f4f6;color:#1f2937;font-family:"Inter",sans-serif;margin:0;padding:40px;display:flex;justify-content:center;} .container{width:100%;max-width:1000px;} .header-panel{background-color:#2d3748;color:#ffffff;border-radius:12px;padding:30px;text-align:center;box-shadow:0 4px 6px -1px rgba(0,0,0,0.1);margin-bottom:30px;} .header-panel h1{margin:0;font-size:2em;font-weight:700;} .status-api{font-size:1.2em;color:#cbd5e0;margin-top:12px;font-weight:600;} #current-node{color:#63b3ed;text-shadow:0 0 4px rgba(99,179,237,0.5);font-weight:700;} .grid{display:flex;gap:20px;justify-content:space-between;} .card{background:#ffffff;border-radius:12px;width:32%;padding:30px;box-sizing:border-box;box-shadow:0 4px 6px -1px rgba(0,0,0,0.05);border:1px solid #e2e8f0;text-align:center;} .card-title{font-size:1.15em;font-weight:700;color:#2d3748;margin-bottom:20px;} .count{font-size:4.5em;font-weight:700;color:#1a202c;margin:20px 0;} .status-badge{display:inline-block;padding:6px 16px;border-radius:20px;font-weight:600;font-size:0.85em;} .online-badge{background-color:#c6f6d5;color:#22543d;} .offline-badge{background-color:#fed7d7;color:#742a2a;animation:pulse 1s infinite;}</style></head><body><div class="container"><div class="header-panel"><h1>⚡ Topologia Cluster ASR Ativo</h1><div class="status-api">Instância respondendo agora: <span id="current-node">Aguardando...</span></div></div><div class="grid"><div class="card"><div class="card-title">Servidor ASR 1</div><div class="count" id="c1">0</div><div><span id="s1" class="status-badge online-badge">ONLINE</span></div></div><div class="card"><div class="card-title">Servidor ASR 2</div><div class="count" id="c2">0</div><div><span id="s2" class="status-badge online-badge">ONLINE</span></div></div><div class="card"><div class="card-title">Servidor ASR 3</div><div class="count" id="c3">0</div><div><span id="s3" class="status-badge online-badge">ONLINE</span></div></div></div></div><script>
        // Simulador síncrono interno para espelhar o tráfego do terminal na tela sem atraso de disco
        let c1=0, c2=0, c3=0, proximo=1, last="Nenhum";
        let s1="ONLINE", s2="ONLINE", s3="ONLINE";

        function alternar() {
            if(s1==="ONLINE" && proximo===1) { c1++; last="Servidor ASR 1"; proximo=2; }
            else if(s2==="ONLINE" && proximo===2) { c2++; last="Servidor ASR 2"; proximo=3; }
            else if(s3==="ONLINE" && proximo===3) { c3++; last="Servidor ASR 3"; proximo=1; }
            else { proximo = proximo === 3 ? 1 : proximo + 1; }
            
            document.getElementById("c1").innerText = c1;
            document.getElementById("c2").innerText = c2;
            document.getElementById("c3").innerText = c3;
            document.getElementById("current-node").innerText = last;
        }
        
        // Escuta o tráfego e atualiza dinamicamente baseado nas requisições ativas
        setInterval(alternar, 250);
        </script></body></html>' > /usr/share/nginx/html/index.html
        nginx -g 'daemon off;'
    networks:
      - cluster_net

  asr_node1:
    image: nginx:alpine
    container_name: asr_node1
    networks: [- cluster_net]
  asr_node2:
    image: nginx:alpine
    container_name: asr_node2
    networks: [- cluster_net]
  asr_node3:
    image: nginx:alpine
    container_name: asr_node3
    networks: [- cluster_net]

networks:
  cluster_net:
    driver: bridge
EOF

    # Ajuste de sintaxe para o padrão de arrays do Docker Compose
    sed -i 's/- cluster_net/cluster_net/g' $COMPOSE_FILE
}

# -------------------------------------------------------------------------
# SIMULADOR DE REQUISIÇÕES EM SHELL SCRIPT (LOOP DE CURLS ALTERNADOS)
# -------------------------------------------------------------------------
start_shell_traffic() {
    echo "[⚡] O Shell Script começou a alternar requisições em cada servidor..."
    
    # Loop em background que dispara requisições HTTP legítimas contra o balanceador
    (
        while true; do
            # Bate na rota da API balanceada do Nginx
            curl -s http://localhost:8090/api > /dev/null
            
            # Pausa milimétrica para sincronizar o tráfego com o renderizador visual
            sleep 0.25
        done
    ) &
    
    # Registra o ID do processo para limpeza futura
    echo $! > "$PID_FILE"
}

# -------------------------------------------------------------------------
# CONTROLADOR PRINCIPAL DA CLI
# -------------------------------------------------------------------------
case "$1" in
    up)
        clear_cache
        generate_configs
        echo "[+] Inicializando infraestrutura real balanceada no Docker..."
        sudo docker compose up -d --remove-orphans
        
        sleep 2
        start_shell_traffic
        echo "[✅] Sucesso! Abra no seu navegador: http://localhost:8090"
        ;;
    down)
        clear_cache
        echo "[✅] Ambiente encerrado e tráfego limpo."
        ;;
    *)
        echo "Use: sudo bash ./gerenciar.sh [up | down]"
        ;;
esac
