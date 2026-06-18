#!/bin/bash

COMPOSE_FILE="docker-compose.yml"
LB_CONF="nginx-lb.conf"

# -------------------------------------------------------------------------
# FERRAMENTA DE INSTALAÇÃO AUTOMÁTICA DE DEPENDÊNCIAS
# -------------------------------------------------------------------------
install_dependencies() {
    if command -v docker &>/dev/null && docker compose version &>/dev/null; then
        echo "[✅] Docker and Docker Compose are already installed."
        return 0
    fi

    echo "[ℹ️] Docker or Docker Compose not found. Starting automatic installation..."
    
    # Verifica se o script está rodando como Root/Sudo (necessário para instalar pacotes)
    if [ "$EUID" -ne 0 ]; then
        echo "❌ Error: Please run this script with sudo to install dependencies: sudo $0 up"
        exit 1
    fi

    # Detecta a distribuição Linux
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "❌ Error: Cannot detect Linux distribution. Install Docker manually."
        exit 1
    fi

    echo "[+] Detecting OS: $OS"
    case "$OS" in
        ubuntu|debian)
            echo "[+] Updating apt repositories..."
            apt-get update -y
            echo "[+] Installing Docker & Docker Compose..."
            apt-get install -y docker.io docker-compose-v2
            systemctl enable --now docker
            ;;
        centos|rhel|fedora)
            echo "[+] Installing Docker & Docker Compose via DNF/YUM..."
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            systemctl enable --now docker
            ;;
        *)
            echo "❌ Error: Unsupported Linux distribution ($OS). Please install Docker manually."
            exit 1
            ;;
    esac

    echo "[✅] Installation completed successfully!"
}

show_help() {
    echo "====================================================================="
    echo "  INFRASTRUCTURE MANAGER - AUTO-INSTALL & LOAD BALANCER CLI  "
    echo "====================================================================="
    echo "Usage: sudo $0 [command] [arguments]"
    echo ""
    echo "Available Commands:"
    echo "  up             - Install dependencies (if missing) and start cluster"
    echo "  down           - Stop and completely remove the full cluster infrastructure"
    echo "  start [node]   - Start a specific backend server (e.g., $0 start app1)"
    echo "  stop [node]    - Stop a specific backend server (e.g., $0 stop app1)"
    echo "  remove [node]  - Remove a specific server container (e.g., $0 remove app1)"
    echo "  status         - Display the current state of all containers"
    echo "====================================================================="
}

generate_configs() {
    echo "[+] Generating Load Balancer configuration ($LB_CONF)..."
    cat << 'EOF' > $LB_CONF
events { worker_connections 1024; }
http {
    upstream backend_cluster {
        server app1:80 max_fails=1 fail_timeout=3s;
        server app2:80 max_fails=1 fail_timeout=3s;
        server app3:80 max_fails=1 fail_timeout=3s;
    }
    server {
        listen 80;
        location / {
            proxy_pass http://backend_cluster;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
        }
    }
}
EOF

    echo "[+] Generating multi-container topology ($COMPOSE_FILE)..."
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
        echo '<h1>Server APP 1</h1><p>Requests Processed: 0</p>' > /usr/share/nginx/html/index.html
        tail -F /var/log/nginx/access.log | while read -r line; do
          if echo "$$line" | grep -q 'GET / '; then
            count=$$((count+1))
            echo "<h1>Server APP 1</h1><p>Requests Processed: $$count</p>" > /usr/share/nginx/html/index.html
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
        echo '<h1>Server APP 2</h1><p>Requests Processed: 0</p>' > /usr/share/nginx/html/index.html
        tail -F /var/log/nginx/access.log | while read -r line; do
          if echo "$$line" | grep -q 'GET / '; then
            count=$$((count+1))
            echo "<h1>Server APP 2</h1><p>Requests Processed: $$count</p>" > /usr/share/nginx/html/index.html
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
        echo '<h1>Server APP 3</h1><p>Requests Processed: 0</p>' > /usr/share/nginx/html/index.html
        tail -F /var/log/nginx/access.log | while read -r line; do
          if echo "$$line" | grep -q 'GET / '; then
            count=$$((count+1))
            echo "<h1>Server APP 3</h1><p>Requests Processed: $$count</p>" > /usr/share/nginx/html/index.html
          fi
        done

networks:
  infra_network:
    driver: bridge
EOF
}

case "$1" in
    up)
        install_dependencies
        generate_configs
        echo "[+] Launching full infrastructure with Docker Compose..."
        docker compose up -d --remove-orphans
        echo "[!] Success! Open http://localhost:8090 in your browser."
        ;;
        
    down)
        echo "[+] Stopping and removing all containers and networks..."
        docker compose down
        ;;
        
    start)
        if [ -z "$2" ]; then echo "❌ Error: Specify node (app1, app2, or app3)."; exit 1; fi
        docker compose start $2
        ;;
        
    stop)
        if [ -z "$2" ]; then echo "❌ Error: Specify node (app1, app2, or app3)."; exit 1; fi
        docker compose stop $2
        ;;
        
    remove)
        if [ -z "$2" ]; then echo "❌ Error: Specify node (app1, app2, or app3)."; exit 1; fi
        docker compose rm -f -s $2
        ;;
        
    status)
        docker compose ps
        ;;
        
    *)
        show_help
        exit 1
        ;;
esac
