#!/bin/bash

set -e

PROJECT="balanceador8090"

install_docker() {

    if command -v docker >/dev/null 2>&1; then
        echo "Docker já instalado."
        return
    fi

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
}

create_project() {

    mkdir -p "$PROJECT/nginx"

    cd "$PROJECT"

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
}

case "${1:-up}" in

up)

    echo "=========================================="
    echo "INSTALANDO DOCKER E DOCKER COMPOSE"
    echo "=========================================="

    install_docker

    create_project

    cd "$PROJECT"

    sudo docker compose up -d

    echo
    echo "Cluster iniciado"
    echo
    echo "http://localhost:8090"
    ;;

stop)

    cd "$PROJECT"
    sudo docker compose stop
    ;;

start)

    cd "$PROJECT"
    sudo docker compose start
    ;;

down)

    cd "$PROJECT"
    sudo docker compose down -v
    ;;

status)

    sudo docker ps
    ;;

app1-stop)

    sudo docker stop app1
    ;;

app1-start)

    sudo docker start app1
    ;;

app2-stop)

    sudo docker stop app2
    ;;

app2-start)

    sudo docker start app2
    ;;

app3-stop)

    sudo docker stop app3
    ;;

app3-start)

    sudo docker start app3
    ;;

*)

    echo "Uso:"
    echo "bash cluster.sh up"
    echo "bash cluster.sh stop"
    echo "bash cluster.sh start"
    echo "bash cluster.sh down"
    echo "bash cluster.sh status"
    echo "bash cluster.sh app1-stop"
    echo "bash cluster.sh app1-start"
    echo "bash cluster.sh app2-stop"
    echo "bash cluster.sh app2-start"
    echo "bash cluster.sh app3-stop"
    echo "bash cluster.sh app3-start"
    ;;

esac
