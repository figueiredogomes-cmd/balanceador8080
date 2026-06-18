#!/bin/bash

COMPOSE_FILE="docker-compose.yml"
LB_CONF="nginx-lb.conf"

# -------------------------------------------------------------------------
# FUNÇÃO PARA LIMPAR CACHE E FORMATAR AMBIENTE
# -------------------------------------------------------------------------
clear_cache() {
    echo "[🧹] Iniciando limpeza profunda de cache e resíduos..."
    
    # 1. Parar possíveis containers órfãos da execução anterior
    if [ -f "$COMPOSE_FILE" ]; then
        docker compose down -v --remove-orphans &>/dev/null
    fi

    # 2. Limpar arquivos compartilhados de contagem de requisições anteriores
    rm -rf ./shared-data
    mkdir -p ./shared-data
    chmod 777 ./shared-data

    # 3. Limpar cache de memória do sistema operacional (se executado como root)
    if [ "$EUID" -eq 0 ]; then
        sync && echo 3 > /proc/sys/vm/drop_caches
        echo "[✅] Cache de memória do Sistema Operacional limpo."
    fi

    echo "[✅] Ambiente limpo com sucesso! Pronto para execução."
}

# -------------------------------------------------------------------------
# INSTALAÇÃO AUTOMÁTICA DE DEPENDÊNCIAS
# -------------------------------------------------------------------------
install_dependencies() {
    if command -v docker &>/dev/null && docker compose version &>/dev/null; then
        echo "[✅] Docker e Docker Compose já estão prontos."
        return 0
    fi

    echo "[ℹ️] Docker Compose não encontrado. Iniciando instalação..."

    if [ "$EUID" -ne 0 ]; then
        echo "❌ Erro: Execute este script com sudo para instalar as dependências: sudo $0 up"
        exit 1
    fi

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "❌ Erro: Não foi possível detectar a distribuição Linux."
        exit 1
    fi

    echo "[+] Sistema Operacional Detectado: $OS"
    case "$OS" in
        ubuntu|debian)
            echo "[+] Atualizando repositórios apt..."
            apt-get update -y
            echo "[+] Instalando Docker Compose Plugin..."
            apt-get install -y docker-compose-v2
            ;;
        *)
            echo "❌ Erro: Este script foi otimizado para Ubuntu/Debian. Instale as dependências manualmente."
            exit 1
            ;;
    esac

    echo "[✅] Dependências instaladas com sucesso!"
}

# -------------------------------------------------------------------------
# GERAÇÃO DINÂMICA DE CONFIGURAÇÕES (DASHBOARD REATIVO + LOGICA FAILOVER)
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
            proxy_pass http://backend_cluster;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

            # FAILOVER ULTRA-RÁPIDO
            proxy_connect_timeout 200ms;
            proxy_read_timeout 200ms;
            proxy_send_timeout 200ms;
            proxy_next_upstream error timeout invalid_header http_502 http_503 http_504;

            # DESTRUIÇÃO DE CACHE HTTP DO NAVEGADOR
            add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }
    }
}
EOF

    echo "[+] Gerando topologia com API de monitoramento em tempo real ($COMPOSE_FILE)..."
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
    depends_on:
      - app1
      - app2
      - app3
    networks:
      - infra_network

  app1:
    image: nginx:alpine
    container_name: app1
    networks:
      - infra_network
    volumes:
      - ./shared-data:/shared
    command:
      - /bin/sh
      - -c
      - |
        rm -f /var/log/nginx/access.log && touch /var/log/nginx/access.log
        nginx
        sleep 1
        [ ! -f /shared/app1.txt ] && echo "0" > /shared/app1.txt
        [ ! -f /shared/app2.txt ] && echo "0" > /shared/app2.txt
        [ ! -f /shared/app3.txt ] && echo "0" > /shared/app3.txt
        
        # 1. TEMPLATE DASHBOARD ATIVO
        echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Dashboard Ativo</title><style>body{font-family:sans-serif;text-align:center;padding-top:30px;background:#f4f6f7;margin:0;} .container{max-width:850px;margin:0 auto;} .header{background:#2c3e50;color:white;padding:20px;border-radius:8px;margin-bottom:20px;} .card{background:white;padding:20px;margin:10px;display:inline-block;width:210px;border-radius:8px;box-shadow:0 4px 6px rgba(0,0,0,0.05);transition:all 0.3s;} .online{border-top:5px solid #2ecc71;} .offline{border-top:5px solid #e74c3c;opacity:0.6;background:#fce4e4;} .badge{display:inline-block;padding:4px 8px;border-radius:12px;font-size:0.8em;font-weight:bold;color:white;} .bg-online{background:#2ecc71;} .bg-offline{background:#e74c3c;} .counter{font-size:2.5em;color:#2c3e50;margin:10px 0; font-weight:bold;}</style></head><body><div class="container"><div class="header"><h1>⚡ Painel de Infraestrutura Ativo</h1><p>Nó respondendo à API agora: <span id="live-responder" style="color:#f1c40f;font-weight:bold;">...</span></p></div><div><div id="card-app1" class="card"><h3>Servidor APP 1</h3><span id="badge-app1" class="badge">...</span><div id="count-app1" class="counter">0</div></div><div id="card-app2" class="card"><h3>Servidor APP 2</h3><span id="badge-app2" class="badge">...</span><div id="count-app2" class="counter">0</div></div><div id="card-app3" class="card"><h3>Servidor APP 3</h3><span id="badge-app3" class="badge">...</span><div id="count-app3" class="counter">0</div></div></div></div><script>function updateData(){fetch("/stats.json",{cache:"no-store"}).then(r=>r.json()).then(data=>{document.getElementById("live-responder").innerText=data.responder;["app1","app2","app3"].forEach(id=>{const card=document.getElementById("card-"+id);const badge=document.getElementById("badge-"+id);document.getElementById("count-"+id).innerText=data[id].count;if(data[id].status==="online"){card.className="card online";badge.className="badge bg-online";badge.innerText="ONLINE";}else{card.className="card offline";badge.className="badge bg-offline";badge.innerText="CONGELADO";}});}).catch(e=>console.log("Erro API"));}setInterval(updateData,1000);updateData();</script></body></html>' > /usr/share/nginx/html/index.html

        # 2. LOOP DE HEARTBEAT E GESTÃO DE REQUISIÇÕES PERDIDAS (FAILOVER)
        while true; do
          date +%s > /shared/app1.heartbeat
          now=$(date +%s)
          
          h1=$(cat /shared/app1.heartbeat 2>/dev/null || echo $now)
          h2=$(cat /shared/app2.heartbeat 2>/dev/null || echo 0)
          h3=$(cat /shared/app3.heartbeat 2>/dev/null || echo 0)
          
          s1="online"
          s2="online"; [ $((now - h2)) -gt 4 ] && s2="offline"
          s3="online"; [ $((now - h3)) -gt 4 ] && s3="offline"

          # Se o APP2 caiu, o APP1 resgata as requisições pendentes dele se existirem
          if [ "$s2" = "offline" ] && [ -f /shared/app2.txt ]; then
             v2=$(cat /shared/app2.txt)
             if [ "$v2" -gt 0 ]; then
                my_c=$(cat /shared/app1.txt)
                echo "$((my_c + v2))" > /shared/app1.txt
                echo "0" > /shared/app2.txt # Zera o arquivo para não somar em loop
             fi
          fi

          # Se o APP3 caiu, o APP1 também herda as requisições dele
          if [ "$s3" = "offline" ] && [ -f /shared/app3.txt ]; then
             v3=$(cat /shared/app3.txt)
             if [ "$v3" -gt 0 ]; then
                my_c=$(cat /shared/app1.txt)
                echo "$((my_c + v3))" > /shared/app1.txt
                echo "0" > /shared/app3.txt
             fi
          fi

          c1=$(cat /shared/app1.txt 2>/dev/null || echo 0)
          c2=$(cat /shared/app2.txt 2>/dev/null || echo 0)
          c3=$(cat /shared/app3.txt 2>/dev/null || echo 0)

          # Se o contador real foi zerado por herança, manter fixo no painel simulando congelado
          [ "$s2" = "offline" ] && c2=$(cat /shared/app2.frozen 2>/dev/null || echo 0)
          [ "$s3" = "offline" ] && c3=$(cat /shared/app3.frozen 2>/dev/null || echo 0)
          
          echo "{\"app1\":{\"count\":$c1,\"status\":\"$s1\"},\"app2\":{\"count\":$c2,\"status\":\"$s2\"},\"app3\":{\"count\":$c3,\"status\":\"$s3\"},\"responder\":\"Servidor APP 1\"}" > /usr/share/nginx/html/stats.json
          sleep 1
        done &

        # 3. CONTADOR DE REQUISIÇÕES REAL LOCAL
        tail -f /var/log/nginx/access.log | while read -r line; do
          if echo "$line" | grep -q '"GET / HTTP/'; then
            count=$(cat /shared/app1.txt)
            count=$((count+1))
            echo "$count" > /shared/app1.txt
            echo "$count" > /shared/app1.frozen
          fi
        done

  app2:
    image: nginx:alpine
    container_name: app2
    networks:
      - infra_network
    volumes:
      - ./shared-data:/shared
    command:
      - /bin/sh
      - -c
      - |
        rm -f /var/log/nginx/access.log && touch /var/log/nginx/access.log
        nginx
        sleep 1
        
        echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Dashboard Ativo</title><style>body{font-family:sans-serif;text-align:center;padding-top:30px;background:#f4f6f7;margin:0;} .container{max-width:850px;margin:0 auto;} .header{background:#2c3e50;color:white;padding:20px;border-radius:8px;margin-bottom:20px;} .card{background:white;padding:20px;margin:10px;display:inline-block;width:210px;border-radius:8px;box-shadow:0 4px 6px rgba(0,0,0,0.05);transition:all 0.3s;} .online{border-top:5px solid #2ecc71;} .offline{border-top:5px solid #e74c3c;opacity:0.6;background:#fce4e4;} .badge{display:inline-block;padding:4px 8px;border-radius:12px;font-size:0.8em;font-weight:bold;color:white;} .bg-online{background:#2ecc71;} .bg-offline{background:#e74c3c;} .counter{font-size:2.5em;color:#2c3e50;margin:10px 0; font-weight:bold;}</style></head><body><div class="container"><div class="header"><h1>⚡ Painel de Infraestrutura Ativo</h1><p>Nó respondendo à API agora: <span id="live-responder" style="color:#f1c40f;font-weight:bold;">...</span></p></div><div><div id="card-app1" class="card"><h3>Servidor APP 1</h3><span id="badge-app1" class="badge">...</span><div id="count-app1" class="counter">0</div></div><div id="card-app2" class="card"><h3>Servidor APP 2</h3><span id="badge-app2" class="badge">...</span><div id="count-app2" class="counter">0</div></div><div id="card-app3" class="card"><h3>Servidor APP 3</h3><span id="badge-app3" class="badge">...</span><div id="count-app3" class="counter">0</div></div></div></div><script>function updateData(){fetch("/stats.json",{cache:"no-store"}).then(r=>r.json()).then(data=>{document.getElementById("live-responder").innerText=data.responder;["app1","app2","app3"].forEach(id=>{const card=document.getElementById("card-"+id);const badge=document.getElementById("badge-"+id);document.getElementById("count-"+id).innerText=data[id].count;if(data[id].status==="online"){card.className="card online";badge.className="badge bg-online";badge.innerText="ONLINE";}else{card.className="card offline";badge.className="badge bg-offline";badge.innerText="CONGELADO";}});}).catch(e=>console.log("Erro API"));}setInterval(updateData,1000);updateData();</script></body></html>' > /usr/share/nginx/html/index.html

        while true; do
          date +%s > /shared/app2.heartbeat
          now=$(date +%s)
          
          h1=$(cat /shared/app1.heartbeat 2>/dev/null || echo 0)
          h2=$(cat /shared/app2.heartbeat 2>/dev/null || echo $now)
          h3=$(cat /shared/app3.heartbeat 2>/dev/null || echo 0)
          
          s1="online"; [ $((now - h1)) -gt 4 ] && s1="offline"
          s2="online"
          s3="online"; [ $((now - h3)) -gt 4 ] && s3="offline"

          # Failover assumido pelo APP2
          if [ "$s1" = "offline" ] && [ -f /shared/app1.txt ]; then
             v1=$(cat /shared/app1.txt)
             if [ "$v1" -gt 0 ]; then
                my_c=$(cat /shared/app2.txt)
                echo "$((my_c + v1))" > /shared/app2.txt
                echo "0" > /shared/app1.txt
             fi
          fi
          if [ "$s3" = "offline" ] && [ -f /shared/app3.txt ]; then
             v3=$(cat /shared/app3.txt)
             if [ "$v3" -gt 0 ]; then
                my_c=$(cat /shared/app2.txt)
                echo "$((my_c + v3))" > /shared/app2.txt
                echo "0" > /shared/app3.txt
             fi
          fi

          c1=$(cat /shared/app1.txt 2>/dev/null || echo 0)
          c2=$(cat /shared/app2.txt 2>/dev/null || echo 0)
          c3=$(cat /shared/app3.txt 2>/dev/null || echo 0)

          [ "$s1" = "offline" ] && c1=$(cat /shared/app1.frozen 2>/dev/null || echo 0)
          [ "$s3" = "offline" ] && c3=$(cat /shared/app3.frozen 2>/dev/null || echo 0)
          
          echo "{\"app1\":{\"count\":$c1,\"status\":\"$s1\"},\"app2\":{\"count\":$c2,\"status\":\"$s2\"},\"app3\":{\"count\":$c3,\"status\":\"$s3\"},\"responder\":\"Servidor APP 2\"}" > /usr/share/nginx/html/stats.json
          sleep 1
        done &

        tail -f /var/log/nginx/access.log | while read -r line; do
          if echo "$line" | grep -q '"GET / HTTP/'; then
            count=$(cat /shared/app2.txt)
            count=$((count+1))
            echo "$count" > /shared/app2.txt
            echo "$count" > /shared/app2.frozen
          fi
        done

  app3:
    image: nginx:alpine
    container_name: app3
    networks:
      - infra_network
    volumes:
      - ./shared-data:/shared
    command:
      - /bin/sh
      - -c
      - |
        rm -f /var/log/nginx/access.log && touch /var/log/nginx/access.log
        nginx
        sleep 1
        
        echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Dashboard Ativo</title><style>body{font-family:sans-serif;text-align:center;padding-top:30px;background:#f4f6f7;margin:0;} .container{max-width:850px;margin:0 auto;} .header{background:#2c3e50;color:white;padding:20px;border-radius:8px;margin-bottom:20px;} .card{background:white;padding:20px;margin:10px;display:inline-block;width:210px;border-radius:8px;box-shadow:0 4px 6px rgba(0,0,0,0.05);transition:all 0.3s;} .online{border-top:5px solid #2ecc71;} .offline{border-top:5px solid #e74c3c;opacity:0.6;background:#fce4e4;} .badge{display:inline-block;padding:4px 8px;border-radius:12px;font-size:0.8em;font-weight:bold;color:white;} .bg-online{background:#2ecc71;} .bg-offline{background:#e74c3c;} .counter{font-size:2.5em;color:#2c3e50;margin:10px 0; font-weight:bold;}</style></head><body><div class="container"><div class="header"><h1>⚡ Painel de Infraestrutura Ativo</h1><p>Nó respondendo à API agora: <span id="live-responder" style="color:#f1c40f;font-weight:bold;">...</span></p></div><div><div id="card-app1" class="card"><h3>Servidor APP 1</h3><span id="badge-app1" class="badge">...</span><div id="count-app1" class="counter">0</div></div><div id="card-app2" class="card"><h3>Servidor APP 2</h3><span id="badge-app2" class="badge">...</span><div id="count-app2" class="counter">0</div></div><div id="card-app3" class="card"><h3>Servidor APP 3</h3><span id="badge-app3" class="badge">...</span><div id="count-app3" class="counter">0</div></div></div></div><script>function updateData(){fetch("/stats.json",{cache:"no-store"}).then(r=>r.json()).then(data=>{document.getElementById("live-responder").innerText=data.responder;["app1","app2","app3"].forEach(id=>{const card=document.getElementById("card-"+id);const badge=document.getElementById("badge-"+id);document.getElementById("count-"+id).innerText=data[id].count;if(data[id].status==="online"){card.className="card online";badge.className="badge bg-online";badge.innerText="ONLINE";}else{card.className="card offline";badge.className="badge bg-offline";badge.innerText="CONGELADO";}});}).catch(e=>console.log("Erro API"));}setInterval(updateData,1000);updateData();</script></body></html>' > /usr/share/nginx/html/index.html

        while true; do
          date +%s > /shared/app3.heartbeat
          now=$(date +%s)
          
          h1=$(cat /shared/app1.heartbeat 2>/dev/null || echo 0)
          h2=$(cat /shared/app2.heartbeat 2>/dev/null || echo 0)
          h3=$(cat /shared/app3.heartbeat 2>/dev/null || echo $now)
          
          s1="online"; [ $((now - h1)) -gt 4 ] && s1="offline"
          s2="online"; [ $((now - h2)) -gt 4 ] && s2="offline"
          s3="online"

          # Failover assumido pelo APP3
          if [ "$s1" = "offline" ] && [ -f /shared/app1.txt ]; then
             v1=$(cat /shared/app1.txt)
             if [ "$v1" -gt 0 ]; then
                my_c=$(cat /shared/app3.txt)
                echo "$((my_c + v1))" > /shared/app3.txt
                echo "0" > /shared/app1.txt
             fi
          fi
          if [ "$s2" = "offline" ] && [ -f /shared/app2.txt ]; then
             v2=$(cat /shared/app2.txt)
             if [ "$v2" -gt 0 ]; then
                my_c=$(cat /shared/app3.txt)
                echo "$((my_c + v2))" > /shared/app3.txt
                echo "0" > /shared/app2.txt
             fi
          fi

          c1=$(cat /shared/app1.txt 2>/dev/null || echo 0)
          c2=$(cat /shared/app2.txt 2>/dev/null || echo 0)
          c3=$(cat /shared/app3.txt 2>/dev/null || echo 0)

          [ "$s1" = "offline" ] && c1=$(cat /shared/app1.frozen 2>/dev/null || echo 0)
          [ "$s2" = "offline" ] && c2=$(cat /shared/app2.frozen 2>/dev/null || echo 0)
          
          echo "{\"app1\":{\"count\":$c1,\"status\":\"$s1\"},\"app2\":{\"count\":$c2,\"status\":\"$s2\"},\"app3\":{\"count\":$c3,\"status\":\"$s3\"},\"responder\":\"Servidor APP 3\"}" > /usr/share/nginx/html/stats.json
          sleep 1
        done &

        tail -f /var/log/nginx/access.log | while read -r line; do
          if echo "$line" | grep -q '"GET / HTTP/'; then
            count=$(cat /shared/app3.txt)
            count=$((count+1))
            echo "$count" > /shared/app3.txt
            echo "$count" > /shared/app3.frozen
          fi
        done

networks:
  infra_network:
    driver: bridge
EOF
}

# -------------------------------------------------------------------------
# INTERFACES DE CONTROLE CLI
# -------------------------------------------------------------------------
show_help() {
    echo "====================================================================="
    echo "                 GERENCIADOR DE INFRAESTRUTURA - CLI                 "
    echo "====================================================================="
    echo "Uso: sudo $0 [comando] [argumentos]"
    echo ""
    echo "Comandos Disponíveis:"
    echo "  up             - Limpa cache, instala dependências e inicia o cluster"
    echo "  down           - Remove completamente os contêineres e redes"
    echo "  stop [nó]      - Derruba um servidor específico (Ex: sudo $0 stop app2)"
    echo "  start [nó]     - Reativa um servidor específico (Ex: sudo $0 start app2)"
    echo "  status         - Exibe a tabela de estado dos servidores"
    echo "====================================================================="
}

case "$1" in
    up)
        clear_cache
        install_dependencies
        generate_configs
        echo "[+] Subindo a infraestrutura com Docker Compose..."
        docker compose up -d --remove-orphans
        echo "[✅] Sucesso total! Acesse no navegador: http://localhost:8090"
        ;;
    down)
        echo "[+] Removendo todos os contêineres e limpando ambiente..."
        docker compose down -v
        rm -rf ./shared-data
        ;;
    stop)
        if [ -z "$2" ]; then 
            echo "❌ Erro: Especifique qual nó deseja derrubar (app1, app2 ou app3)."
            exit 1
        fi
        echo "[+] Parando o contêiner $2 com Docker Compose Stop..."
        docker compose stop $2
        ;;
    start)
        if [ -z "$2" ]; then 
            echo "❌ Erro: Especifique qual nó deseja iniciar (app1, app2 ou app3)."
            exit 1
        fi
        echo "[+] Reativando o contêiner $2..."
        docker compose start $2
        ;;
    status)
        docker compose ps
        ;;
    *)
        show_help
        exit 1
        ;;
esac
