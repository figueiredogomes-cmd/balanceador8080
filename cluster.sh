#!/bin/bash

set -e

PROJECT_DIR="$HOME/balanceador8090"

echo "=========================================="
echo " NGINX LOAD BALANCER"
echo " Ubuntu 22.04+ / WSL"
echo " Porta 8090"
echo "=========================================="

echo
echo "[1/6] Verificando Docker..."

if ! command -v docker >/dev/null 2>&1; then

    sudo apt update

    sudo apt install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    sudo install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    sudo apt update

    sudo apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    sudo systemctl enable docker
    sudo systemctl start docker

fi

echo
echo "[2/6] Verificando Docker Compose..."

if ! sudo docker compose version >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y docker-compose-plugin
fi

echo
echo "[3/6] Limpando containers antigos..."

sudo docker rm -f nginx_lb 2>/dev/null || true
sudo docker rm -f app1 2>/dev/null || true
sudo docker rm -f app2 2>/dev/null || true
sudo docker rm -f app3 2>/dev/null || true

echo
echo "[4/6] Criando projeto..."

rm -rf "$PROJECT_DIR"

mkdir -p "$PROJECT_DIR/nginx"

cd "$PROJECT_DIR"

cat > nginx/nginx.conf <<'EOF'
events {}

http {

    upstream backend {

        server app1:80 max_fails=1 fail_timeout=5s;
        server app2:80 max_fails=1 fail_timeout=5s;
        server app3:80 max_fails=1 fail_timeout=5s;

    }

    server {

        listen 80;

        location / {

            proxy_pass http://backend;

            proxy_next_upstream error
                                timeout
                                http_500
                                http_502
                                http_503
                                http_504;

        }

    }

}
EOF

echo
echo "[5/6] Criando docker-compose..."

cat > docker-compose.yml <<'EOF'
services:

  app1:
    image: nginx:alpine
    container_name: app1
    restart: unless-stopped

  app2:
    image: nginx:alpine
    container_name: app2
    restart: unless-stopped

  app3:
    image: nginx:alpine
    container_name: app3
    restart: unless-stopped

  nginx:
    image: nginx:latest
    container_name: nginx_lb
    restart: unless-stopped

    ports:
      - "8090:80"

    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro

    depends_on:
      - app1
      - app2
      - app3
EOF

echo
echo "[6/6] Validando compose..."

sudo docker compose config >/dev/null

echo
echo "Subindo ambiente..."

sudo docker compose up -d --remove-orphans

echo
echo "=========================================="
echo " CLUSTER INICIADO"
echo "=========================================="
echo
echo "URL:"
echo "http://localhost:8090"
echo
echo "STATUS:"
echo "sudo docker ps"
echo
echo "PARAR APP1:"
echo "sudo docker stop app1"
echo
echo "INICIAR APP1:"
echo "sudo docker start app1"
echo
echo "PARAR APP2:"
echo "sudo docker stop app2"
echo
echo "INICIAR APP2:"
echo "sudo docker start app2"
echo
echo "PARAR APP3:"
echo "sudo docker stop app3"
echo
echo "INICIAR APP3:"
echo "sudo docker start app3"
echo
echo "PARAR CLUSTER:"
echo "cd $PROJECT_DIR && sudo docker compose stop"
echo
echo "INICIAR CLUSTER:"
echo "cd $PROJECT_DIR && sudo docker compose start"
echo
echo "DESTRUIR CLUSTER:"
echo "cd $PROJECT_DIR && sudo docker compose down -v"
echo
echo "=========================================="
