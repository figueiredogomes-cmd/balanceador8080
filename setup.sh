#!/bin/bash

PROJETO="$HOME/cluster-balanceado"

echo "Instalando Docker Compose clássico..."

sudo apt update

sudo apt install -y docker.io docker-compose curl

sudo systemctl enable docker 2>/dev/null || true
sudo service docker start

echo "Limpando ambiente anterior..."

sudo docker rm -f balanceador srv1 srv2 srv3 2>/dev/null || true

mkdir -p $PROJETO

cd $PROJETO || exit

mkdir -p nginx/conf.d
mkdir -p srv1
mkdir -p srv2
mkdir -p srv3

cat > srv1/index.html <<EOF
<h1>Servidor 1</h1>
EOF

cat > srv2/index.html <<EOF
<h1>Servidor 2</h1>
EOF

cat > srv3/index.html <<EOF
<h1>Servidor 3</h1>
EOF

cat > nginx/conf.d/default.conf <<EOF
upstream backend {

    server srv1:80 max_fails=1 fail_timeout=2s;
    server srv2:80 max_fails=1 fail_timeout=2s;
    server srv3:80 max_fails=1 fail_timeout=2s;

}

server {

    listen 80;

    location / {

        proxy_pass http://backend;

        proxy_next_upstream error
                            timeout
                            http_502
                            http_503
                            http_504;

    }

}
EOF

cat > docker-compose.yml <<EOF
version: '3.8'

services:

  srv1:
    image: nginx:alpine
    container_name: srv1
    restart: unless-stopped
    volumes:
      - ./srv1:/usr/share/nginx/html

  srv2:
    image: nginx:alpine
    container_name: srv2
    restart: unless-stopped
    volumes:
      - ./srv2:/usr/share/nginx/html

  srv3:
    image: nginx:alpine
    container_name: srv3
    restart: unless-stopped
    volumes:
      - ./srv3:/usr/share/nginx/html

  balanceador:
    image: nginx:alpine
    container_name: balanceador
    restart: unless-stopped
    ports:
      - "8090:80"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
    depends_on:
      - srv1
      - srv2
      - srv3
EOF

echo "Subindo cluster..."

sudo docker-compose down

sudo docker-compose up -d

echo ""
echo "Cluster iniciado"
echo ""
echo "Acesse:"
echo "http://localhost:8090"
echo ""

sudo docker ps
