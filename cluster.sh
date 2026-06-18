#!/bin/bash

set -e

echo "=========================================="
echo " NGINX LOAD BALANCER"
echo " Ubuntu 22.04+ / WSL"
echo " Porta 8090"
echo "=========================================="

if ! command -v docker >/dev/null 2>&1; then

    echo "Instalando Docker..."

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

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    sudo apt update

    sudo apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
fi

if ! docker compose version >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y docker-compose-plugin
fi

mkdir -p balanceador8090/nginx

cd balanceador8090

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

cat > docker-compose.yml <<'EOF'
services:

  app1:
    image: nginx:alpine
    container_name: app1

  app2:
    image: nginx:alpine
    container_name: app2

  app3:
    image: nginx:alpine
    container_name: app3

  nginx:
    image: nginx:latest
    container_name: nginx_lb

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
echo "Validando docker-compose..."
docker compose config >/dev/null

echo
echo "Subindo ambiente..."
sudo docker compose up -d

echo
echo "=========================================="
echo "CLUSTER INICIADO"
echo "=========================================="
echo
echo "Acesse:"
echo "http://localhost:8090"
echo
echo "Containers:"
echo "sudo docker ps"
echo
echo "Parar APP1:"
echo "sudo docker stop app1"
echo
echo "Iniciar APP1:"
echo "sudo docker start app1"
echo
echo "Parar APP2:"
echo "sudo docker stop app2"
echo
echo "Iniciar APP2:"
echo "sudo docker start app2"
echo
echo "Parar APP3:"
echo "sudo docker stop app3"
echo
echo "Iniciar APP3:"
echo "sudo docker start app3"
echo
echo "Parar cluster:"
echo "sudo docker compose stop"
echo
echo "Iniciar cluster:"
echo "sudo docker compose start"
echo
echo "Destruir cluster:"
echo "sudo docker compose down -v"
