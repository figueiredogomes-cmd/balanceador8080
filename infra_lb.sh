#!/bin/bash

COMPOSE_FILE="docker-compose.yml"
LB_CONF="nginx-lb.conf"

# -------------------------------------------------------------------------
# INSTALAÇÃO AUTOMÁTICA DE DEPENDÊNCIAS (OTIMIZADO PARA UBUNTU)
# -------------------------------------------------------------------------
install_dependencies() {
    if command -v docker &>/dev/null && docker compose version &>/dev/null; then
        echo "[✅] Docker e Docker Compose já estão instalados."
        return 0
    fi

    echo "[ℹ️] Docker ou Docker Compose não encontrados. Iniciando instalação automatizada..."
    
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
            echo "[+] Instalando Docker e Docker Compose Plugin..."
            apt-get install -y docker.io docker-compose-v2
            systemctl enable --now docker
            ;;
        *)
            echo "❌ Erro: Este script foi otimizado para Ubuntu/Debian. Instale o Docker manualmente."
            exit 1
            ;;
    esac

    echo "[✅] Dependências instaladas com sucesso!"
}

# -------------------------------------------------------------------------
# GERAÇÃO DINÂMICA DE CONFIGURAÇÕES (ANTI-CACHE E FAILOVER ULTRA-RÁPIDO)
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
            
            # FAILOVER ULTRA-RÁPIDO (Se o nó caiu, desvia em 500ms sem travar a tela)
            proxy_connect_timeout 500ms;
            proxy_read_timeout 500ms;
            proxy_send_timeout 500ms;
            proxy_next_upstream error timeout invalid_header http_502 http_503 http_504;

            # DESTRUIÇÃO DE CACHE COMPLETA PARA ATUALIZAÇÃO EM TEMPO REAL
            add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }
    }
}
EOF

    echo "[+] Gerando topologia multi-contêiner ($COMPOSE_FILE)..."
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
    command:
      - /bin/sh
      - -c
      - |
        rm -f /var/log/nginx/access.log
        touch /var/log/nginx/access.log
        chmod 666 /var/log/nginx/access.log
        nginx
        count=0
        echo "<html><head><meta http-equiv='cache-control' content='no-cache'></head><body style='font-family:sans-serif; text-align:center; padding-top:50px;'><h1>Servidor APP 1</h1><hr><p style='font-size:2em; color:#2c3e50;'>Requisições Processadas: 0</p></body></html>" > /usr/share/nginx/html/index.html
        
        tail -f /var/log/nginx/access.log | while read -r line; do
          if echo "$$line" | grep -q 'GET / '; then
            count=$$((count+1))
            echo "<html><head><meta http-equiv='cache-control' content='no-cache'></head><body style='font-family:sans-serif; text-align:center; padding-top:50px;'><h1>Servidor APP 1</h1><hr><p style='font-size:2em; color:#2c3e50;'>Requisições Processadas: $$count</p></body></html>" > /usr/share/nginx/html/index.html
          fi
        done

  app2:
    image: nginx:alpine
    container_name: app2
    networks:
      - infra_network
    command:
      - /bin/sh
      - -c
      - |
        rm -f /var/log/nginx/access.log
        touch /var/log/nginx/access.log
        chmod 666 /var/log/nginx/access.log
        nginx
        count=0
        echo "<html><head><meta http-equiv='cache-control' content='no-cache'></head><body style='font-family:sans-serif; text-align:center; padding-top:50px;'><h1>Servidor APP 2</h1><hr><p style='font-size:2em; color:#2c3e50;'>Requisições Processadas: 0</p></body></html>" > /usr/share/nginx/html/index.html
        
        tail -f /var/log/nginx/access.log | while read -r line; do
          if echo "$$line" | grep -q 'GET / '; then
            count=$$((count+1))
            echo "<html><head><meta http-equiv='cache-control' content='no-cache'></head><body style='font-family:sans-serif; text-align:center; padding-top:50px;'><h1>Servidor APP 2</h1><hr><p style='font-size:2em; color:#2c3e50;'>Requisições Processadas: $$count</p></body></html>" > /usr/share/nginx/html/index.html
          fi
        done

  app3:
    image: nginx:alpine
    container_name: app3
    networks:
      - infra_network
    command:
      - /bin/sh
      - -c
      - |
        rm -f /var/log/nginx/access.log
        touch /var/log/nginx/access.log
        chmod 666 /var/log/nginx/access.log
        nginx
        count=0
        echo "<html><head><meta http-equiv='cache-control' content='no-cache'></head><body style='font-family:sans-serif; text-align:center; padding-top:50px;'><h1>Servidor APP 3</h1><hr><p style='font-size:2em; color:#2c3e50;'>Requisições Processadas: 0</p></body></html>" > /usr/share/nginx/html/index.html
        
        tail -f /var/log/nginx/access.log | while read -r line; do
          if echo "$$line" | grep -q 'GET / '; then
            count=$$((count+1))
            echo "<html><head><meta http-equiv='cache-control' content='no-cache'></head><body style='font-family:sans-serif; text-align:center; padding-top:50px;'><h1>Servidor APP 3</h1><hr><p style='font-size:2em; color:#2c3e50;'>Requisições Processadas: $$count</p></body></html>" > /usr/share/nginx/html/index.html
          fi
        done

networks:
  infra_network:
    driver: bridge
EOF
}

# -------------------------------------------------------------------------
# INTERFACES DE CONTROLE CLI (UP / DOWN / STOP / START / STATUS)
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
        docker compose down
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
