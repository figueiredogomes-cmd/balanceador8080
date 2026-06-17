#!/bin/bash

PROJETO="$HOME/cluster-balanceado"

echo "Instalando Docker e Docker Compose..."
sudo apt update
sudo apt install -y docker.io docker-compose curl
sudo systemctl enable docker 2>/dev/null || true
sudo systemctl start docker

echo "Limpando ambiente anterior..."
sudo docker rm -f balanceador srv1 srv2 srv3 2>/dev/null || true

echo "Criando estrutura de diretórios do projeto..."
mkdir -p $PROJETO
cd $PROJETO || exit
mkdir -p nginx/conf.d
mkdir -p srv1
mkdir -p srv2
mkdir -p srv3

echo "Criando conteúdo HTML para os servidores..."
cat > srv1/index.html <<EOF
<h1>Servidor 1 Ativo</h1>
EOF
![Image](https://image.pollinations.ai/prompt/A%20webpage%20displaying%20'Servidor%201%20Ativo',%20clean%20design,%20tech%20vibe,%20minimalist,%20digital%20art,%20web%20design,%20concept%20art)

cat > srv2/index.html <<EOF
<h1>Servidor 2 Ativo</h1>
EOF
![Image](https://image.pollinations.ai/prompt/A%20webpage%20displaying%20'Servidor%202%20Ativo',%20clean%20design,%20tech%20vibe,%20minimalist,%20digital%20art,%20web%20design,%20concept%20art)

cat > srv3/index.html <<EOF
<h1>Servidor 3 Ativo</h1>
EOF
![Image](https://image.pollinations.ai/prompt/A%20webpage%20displaying%20'Servidor%203%20Ativo',%20clean%20design,%20tech%20vibe,%20minimalist,%20digital%20art,%20web%20design,%20concept%20art)

echo "Configurando o Nginx para balanceamento de carga..."
cat > nginx/conf.d/default.conf <<EOF
upstream backend {
    server srv1:80 max_fails=3 fail_timeout=10s;
    server srv2:80 max_fails=3 fail_timeout=10s;
    server srv3:80 max_fails=3 fail_timeout=10s;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend;
        proxy_next_upstream error timeout http_502 http_503 http_504;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
![Image](https://image.pollinations.ai/prompt/Nginx%20configuration%20file%20for%20load%20balancing,%20code%20snippet,%20technical%20diagram,%20modern%20ui,%20vector%20illustration,%20system%20architecture,%20schematic)

echo "Definindo o arquivo docker-compose.yml..."
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  srv1:
    image: nginx:alpine
    container_name: srv1
    restart: unless-stopped
    volumes:
      - ./srv1:/usr/share/nginx/html
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  srv2:
    image: nginx:alpine
    container_name: srv2
    restart: unless-stopped
    volumes:
      - ./srv2:/usr/share/nginx/html
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  srv3:
    image: nginx:alpine
    container_name: srv3
    restart: unless-stopped
    volumes:
      - ./srv3:/usr/share/nginx/html
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  balanceador:
    image: nginx:alpine
    container_name: balanceador
    restart: unless-stopped
    ports:
      - "8090:80"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
    depends_on:
      srv1:
        condition: service_healthy
      srv2:
        condition: service_healthy
      srv3:
        condition: service_healthy
EOF
![Image](https://image.pollinations.ai/prompt/Docker%20Compose%20file%20for%20load%20balancing,%20code%20snippet,%20technical%20diagram,%20modern%20ui,%20vector%20illustration,%20system%20architecture,%20schematic)

echo "Subindo o cluster balanceado..."
sudo docker-compose down
sudo docker-compose up -d

echo ""
echo "Cluster iniciado com sucesso!"
echo ""
echo "Acesse o balanceador em:"
echo "http://localhost:8090"
echo ""
echo "Status dos contêineres:"
sudo docker ps
