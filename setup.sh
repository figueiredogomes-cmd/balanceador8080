#!/bin/bash

PROJETO="$HOME/cluster-balanceado"

echo "======================================"
echo " CLUSTER NGINX LOAD BALANCER"
echo "======================================"

#
# Docker
#

if command -v docker >/dev/null 2>&1; then

    echo "[OK] Docker já instalado"

else

    echo "[INFO] Instalando Docker..."

    curl -fsSL https://get.docker.com -o get-docker.sh

    sudo sh get-docker.sh

    rm -f get-docker.sh

fi

#
# Docker Compose clássico
#

if command -v docker-compose >/dev/null 2>&1; then

    echo "[OK] Docker Compose já instalado"

else

    echo "[INFO] Instalando Docker Compose..."

    sudo apt update

    sudo apt install -y docker-compose

fi

#
# Docker Service
#

sudo service docker start >/dev/null 2>&1 || true

#
# Limpeza
#

echo "[INFO] Limpando ambiente anterior..."

sudo docker rm -f \
balanceador \
srv1 \
srv2 \
srv3 \
2>/dev/null || true

sudo docker network prune -f >/dev/null 2>&1 || true

#
# Estrutura
#

mkdir -p "$PROJETO"

cd "$PROJETO" || exit 1

mkdir -p nginx/conf.d
mkdir -p srv1
mkdir -p srv2
mkdir -p srv3

#
# Servidores
#

cat > srv1/index.html <<EOF
<!DOCTYPE html>
<html>
<body style="font-family:Arial;text-align:center">
<h1>Servidor 1</h1>
</body>
</html>
EOF

cat > srv2/index.html <<EOF
<!DOCTYPE html>
<html>
<body style="font-family:Arial;text-align:center">
<h1>Servidor 2</h1>
</body>
</html>
EOF

cat > srv3/index.html <<EOF
<!DOCTYPE html>
<html>
<body style="font-family:Arial;text-align:center">
<h1>Servidor 3</h1>
</body>
</html>
EOF

#
# Nginx LB
#

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

#
# Compose
#

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

#
# Sobe ambiente
#

echo "[INFO] Subindo cluster..."

sudo docker-compose down >/dev/null 2>&1 || true

sudo docker-compose up -d

echo ""
echo "======================================"
echo " CLUSTER INICIADO COM SUCESSO"
echo "======================================"
echo ""
echo "Acesse:"
echo ""
echo "http://localhost:8090"
echo ""

sudo docker ps
