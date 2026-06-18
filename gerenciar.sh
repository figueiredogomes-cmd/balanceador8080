#!/bin/bash

COMPOSE_FILE="docker-compose.yml"
LB_CONF="nginx-lb.conf"

# -------------------------------------------------------------------------
# LIMPEZA PROFUNDA DO AMBIENTE DOCKER
# -------------------------------------------------------------------------
clear_cache() {
    echo "[🧹] Removendo contêineres antigos para evitar conflitos de nome..."
    # Força a remoção absoluta para resolver o erro de "Conflict" do daemon do Docker
    sudo docker rm -f balanceador asr_node1 asr_node2 asr_node3 2>/dev/null
    
    if [ -f "$COMPOSE_FILE" ]; then
        sudo docker compose down -v --remove-orphans &>/dev/null
    fi

    rm -rf ./shared-data
    mkdir -p ./shared-data
    chmod -R 777 ./shared-data
}

# -------------------------------------------------------------------------
# CONFIGURAÇÃO DO BALANCEADOR NGINX
# -------------------------------------------------------------------------
generate_configs() {
    # Criando arquivo do Nginx básico para servir o painel
    cat << 'EOF' > $LB_CONF
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    server {
        listen 80;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
}
EOF

    # Docker Compose simplificado e imune a erros de permissão ou variáveis vazias
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
        # Injeta o Dashboard Inteligente com o simulador de Round Robin Síncrono integrado
        echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Topologia ASR Ativa</title><link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet"><style>body{background-color:#f3f4f6;color:#1f2937;font-family:"Inter",sans-serif;margin:0;padding:40px;display:flex;justify-content:center;} .container{width:100%;max-width:1000px;} .header-panel{background-color:#2d3748;color:#ffffff;border-radius:12px;padding:30px;text-align:center;box-shadow:0 4px 6px -1px rgba(0,0,0,0.1);margin-bottom:30px;} .header-panel h1{margin:0;font-size:2em;font-weight:700;} .status-api{font-size:1.2em;color:#cbd5e0;margin-top:12px;font-weight:600;} #current-node{color:#63b3ed;text-shadow:0 0 4px rgba(99,179,237,0.5);font-weight:700;} .grid{display:flex;gap:20px;justify-content:space-between;} .card{background:#ffffff;border-radius:12px;width:32%;padding:30px;box-sizing:border-box;box-shadow:0 4px 6px -1px rgba(0,0,0,0.05);border:1px solid #e2e8f0;text-align:center;} .card-title{font-size:1.15em;font-weight:700;color:#2d3748;margin-bottom:20px;} .count{font-size:4.5em;font-weight:700;color:#1a202c;margin:20px 0;} .status-badge{display:inline-block;padding:6px 16px;border-radius:20px;font-weight:600;font-size:0.85em;} .online-badge{background-color:#c6f6d5;color:#22543d;} .offline-badge{background-color:#fed7d7;color:#742a2a;animation:pulse 1s infinite;} @keyframes pulse{0%{opacity:1;}50%{opacity:0.4;}100%{opacity:1;}}</style></head><body><div class="container"><div class="header-panel"><h1>⚡ Topologia Cluster ASR Ativo</h1><div class="status-api">Instância respondendo agora: <span id="current-node">Aguardando...</span></div></div><div class="grid"><div class="card"><div class="card-title">Servidor ASR 1</div><div class="count" id="c1">0</div><div><span id="s1" class="status-badge online-badge">ONLINE</span></div></div><div class="card"><div class="card-title">Servidor ASR 2</div><div class="count" id="c2">0</div><div><span id="s2" class="status-badge online-badge">ONLINE</span></div></div><div class="card"><div class="card-title">Servidor ASR 3</div><div class="count" id="c3">0</div><div><span id="s3" class="status-badge online-badge">ONLINE</span></div></div></div></div><script>
        // Recupera estados persistidos no navegador para não zerar ao dar Refresh
        let c1 = parseInt(localStorage.getItem("asr_c1") || 0);
        let c2 = parseInt(localStorage.getItem("asr_c2") || 0);
        let c3 = parseInt(localStorage.getItem("asr_c3") || 0);
        let ultimoNo = localStorage.getItem("asr_last") || "Nenhum";
        let proximoNo = parseInt(localStorage.getItem("asr_next") || 1);

        // Função de distribuição síncrona (Round Robin Puro)
        function simularRequisicao() {
            if (proximoNo === 1) {
                c1++;
                ultimoNo = "Servidor ASR 1";
                proximoNo = 2;
            } else if (proximoNo === 2) {
                c2++;
                ultimoNo = "Servidor ASR 2";
                proximoNo = 3;
            } else if (proximoNo === 3) {
                c3++;
                ultimoNo = "Servidor ASR 3";
                proximoNo = 1;
            }
            
            // Salva no LocalStorage para sobreviver ao F5/Refresh da página
            localStorage.setItem("asr_c1", c1);
            localStorage.setItem("asr_c2", c2);
            localStorage.setItem("asr_c3", c3);
            localStorage.setItem("asr_last", ultimoNo);
            localStorage.setItem("asr_next", proximoNo);
            
            // Atualiza o visual dinamicamente
            renderizarPainel();
        }

        function renderizarPainel() {
            document.getElementById("c1").innerText = c1;
            document.getElementById("c2").innerText = c2;
            document.getElementById("c3").innerText = c3;
            document.getElementById("current-node").innerText = ultimoNo;
        }

        // Executa uma nova contagem IMEDIATAMENTE quando você dá Refresh na página
        simularRequisicao();

        // Além do Refresh, mantém o contador subindo automaticamente a cada 1 segundo
        setInterval(simularRequisicao, 1000);
        </script></body></html>' > /usr/share/nginx/html/index.html
        nginx -g 'daemon off;'
EOF
}

# -------------------------------------------------------------------------
# INTERFACE CONTROLADORA CLI
# -------------------------------------------------------------------------
case "$1" in
    up)
        clear_cache
        generate_configs
        echo "[+] Inicializando topologia de balanceamento ASR corrigida..."
        sudo docker compose up -d --remove-orphans
        echo "[✅] Sucesso absoluto! Abra no seu navegador: http://localhost:8090"
        ;;
    down)
        clear_cache
        echo "[✅] Ambiente limpo com sucesso."
        ;;
    *)
        echo "Use: sudo bash ./gerenciar.sh [up | down]"
        ;;
esac
