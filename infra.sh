#!/bin/bash

COMPOSE_FILE="docker-compose.yml"
LB_CONF="nginx-lb.conf"

# -------------------------------------------------------------------------
# INSTAÇÃO AUTOMÁTICA DE DEPENDÊNCIAS (APENAS DOCKER COMPOSE PLUGIN)
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
# GERAÇÃO DINÂMICA DE CONFIGURAÇÕES (SEM ESPAÇOS INVÁLIDOS)
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
            proxy_connect_timeout 500ms;
            proxy_read_timeout 500ms;
            proxy_send_timeout 500ms;
            proxy_next_upstream error timeout invalid_header http_502 http_503 http_504;

            # DESTRUIÇÃO DE CACHE
            add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }
    }
}
EOF

    echo "[+] Gerando topologia multi-contêiner com Volume Compartilhado ($COMPOSE_FILE)..."
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
      - shared-counters:/shared
    command:
      - /bin/sh
      - -c
      - |
        mkdir -p /var/log/nginx && touch /var/log/nginx/access.log
        nginx
        sleep 1
        [ ! -f /shared/app1.txt ] && echo "0" > /shared/app1.txt
        [ ! -f /shared/app2.txt ] && echo "0" > /shared/app2.txt
        [ ! -f /shared/app3.txt ] && echo "0" > /shared/app3.txt
        
        count=$(cat /shared/app1.txt)
        
        render_page() {
          c1=$(cat /shared/app1.txt 2>/dev/null || echo 0)
          c2=$(cat /shared/app2.txt 2>/dev/null || echo 0)
          c3=$(cat /shared/app3.txt 2>/dev/null || echo 0)
          echo "<html><head><meta http-equiv='cache-control' content='no-cache'><style>body{font-family:sans-serif;text-align:center;padding-top:30px;background:#f4f6f7;} .container{max-width:800px;margin:0 auto;} .card{background:white;padding:15px;margin:10px;display:inline-block;width:200px;border-radius:8px;box-shadow:0 4px 6px rgba(0,0,0,0.05);} .current{border:3px solid #3498db;background:#e8f4fd;}</style></head><body><div class='container'><h1>Painel Central de Requisições</h1><p style='font-size:1.2em;'>Quem respondeu agora: <span style='color:#3498db;font-weight:bold;'>Servidor APP 1</span></p><hr><div class='card current'><h3>Servidor APP 1</h3><p style='font-size:2em;color:#2c3e50;'>$c1</p></div><div class='card'><h3>Servidor APP 2</h3><p style='font-size:2em;color:#2c3e50;'>$c2</p></div><div class='card'><h3>Servidor APP 3</h3><p style='font-size:2em;color:#2c3e50;'>$c3</p></div></div></body></html>" > /usr/share/nginx/html/index.html
        }
        
        render_page
        tail -f /var/log/nginx/access.log | while read -r line; do
          if echo "$line" | grep -q 'GET / '; then
            count=$((count+1))
            echo "$count" > /shared/app1.txt
            render_page
          fi
        done

  app2:
    image: nginx:alpine
    container_name: app2
    networks:
      - infra_network
    volumes:
      - shared-counters:/shared
    command:
      - /bin/sh
      - -c
      - |
        mkdir -p /var/log/nginx && touch /var/log/nginx/access.log
        nginx
        sleep 1
        [ ! -f /shared/app1.txt ] && echo "0" > /shared/app1.txt
        [ ! -f /shared/app2.txt ] && echo "0" > /shared/app2.txt
        [ ! -f /shared/app3.txt ] && echo "0" > /shared/app3.txt
        
        count=$(cat /shared/app2.txt)
        
        render_page() {
          c1=$(cat /shared/app1.txt 2>/dev/null || echo 0)
          c2=$(cat /shared/app2.txt 2>/dev/null || echo 0)
          c3=$(cat /shared/app3.txt 2>/dev/null || echo 0)
          echo "<html><head><meta http-equiv='cache-control' content='no-cache'><style>body{font-family:sans-serif;text-align:center;padding-top:30px;background:#f4f6f7;} .container{max-width:800px;margin:0 auto;} .card{background:white;padding:15px;margin:10px;display:inline-block;width:200px;border-radius:8px;box-shadow:0 4px 6px rgba(0,0,0,0.05);} .current{border:3px solid #2ecc71;background:#eafaf1;}</style></head><body><div class='container'><h1>Painel Central de Requisições</h1><p style='font-size:1.2em;'>Quem respondeu agora: <span style='color:#2ecc71;font-weight:bold;'>Servidor APP 2</span></p><hr><div class='card'><h3>Servidor APP 1</h3><p style='font-size:2em;color:#2c3e50;'>$c1</p></div><div class='card current'><h3>Servidor APP 2</h3><p style='font-size:2em;color:#2c3e50;'>$c2</p></div><div class='card'><h3>Servidor APP 3</h3><p style='font-size:2em;color:#2c3e50;'>$c3</p></div></div></body></html>" > /usr/share/nginx/html/index.html
        }
        
        render_page
        tail -f /var/log/nginx/access.log | while read -r line; do
          if echo "$line" | grep -q 'GET / '; then
            count=$((count+1))
            echo "$count" > /shared/app2.txt
            render_page
          fi
        done

  app3:
    image: nginx:alpine
    container_name: app3
    networks:
      - infra_network
    volumes:
      - shared-counters:/shared
    command:
      - /bin/sh
      - -c
      - |
        mkdir -p /var/log/nginx && touch /var/log/nginx/access.log
        nginx
        sleep 1
        [ ! -f /shared/app1.txt ] && echo "0" > /shared/app1.txt
        [ ! -f /shared/app2.txt ] && echo "0" > /shared/app2.txt
        [ ! -f /shared/app3.txt ] && echo "0" > /shared/app3.txt
        
        count=$(cat /shared/app3.txt)
        
        render_page() {
          c1=$(cat /shared/app1.txt 2>/dev/null || echo 0)
          c2=$(cat /shared/app2.txt 2>/dev/null || echo 0)
          c3=$(cat /shared/app3.txt 2>/dev/null || echo 0)
          echo "<html><head><meta http-equiv='cache-control' content='no-cache'><style>body{font-family:sans-serif;text-align:center;padding-top:30px;background:#f4f6f7;} .container{max-width:800px;margin:0 auto;} .card{background:white;padding:15px;margin:10px;display:inline-block;width:200px;border-radius:8px;box-shadow:0 4px 6px rgba(0,0,0,0.05);} .current{border:3px solid #9b59b6;background:#f5eef8;}</style></head><body><div class='container'><h1>Painel Central de Requisições</h1><p style='font-size:1.2em;'>Quem respondeu agora: <span style='color:#9b59b6;font-weight:bold;'>Servidor APP 3</span></p><hr><div class='card'><h3>Servidor APP 1</h3><p style='font-size:2em;color:#2c3e50;'>$c1</p></div><div class='card'><h3>Servidor APP 2</h3><p style='font-size:2em;color:#2c3e50;'>$c2</p></div><div class='card current'><h3>Servidor APP 3</h3><p style='font-size:2em;color:#2c3e50;'>$c3</p></div></div></body></html>" > /usr/share/nginx/html/index.html
        }
        
        render_page
        tail -f /var/log/nginx/access.log | while read -r line; do
          if echo "$line" | grep -q 'GET / '; then
            count=$((count+1))
            echo "$count" > /shared/app3.txt
            render_page
          fi
        done

networks:
  infra_network:
    driver: bridge

volumes:
  shared-counters:
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
    echo "  up             - Instala dependências, gera arquivos e sobe o cluster"
    echo "  down           - Remove completamente os contêineres e redes"
    echo "  stop [nó]      - Derruba um servidor específico (Ex: sudo $0 stop app2)"
    echo "  start [nó]     - Reativa um servidor específico (Ex: sudo $0 start app2)"
    echo "  status         - Exibe a tabela de estado dos servidores"
    echo "====================================================================="
}

case "$1" in
    up)
        install_dependencies
        generate_configs
        echo "[+] Subindo a infraestrutura com Docker Compose..."
        docker compose up -d --remove-orphans
        echo "[✅] Sucesso total! Acesse no navegador: http://localhost:8090"
        ;;
    down)
        echo "[+] Removendo todos os contêineres e limpando ambiente..."
        docker compose down -v
        ;;
    stop)
        if [ -z "$2" ]; then 
            echo "❌ Erro: Especifique qual nó deseja derrubar (app1, app2 ou app3)."
            exit 1
        fi
        echo "[+] Parando o contêiner $2..."
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
