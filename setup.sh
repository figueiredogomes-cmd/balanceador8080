#!/bin/bash

# Define o local do projeto
PROJETO_DIR="$HOME/cluster-balanceado"

echo "================================================="
echo "   SISTEMA DE BALANCEAMENTO DE CARGA NATIVO      "
echo "================================================="

# 1. Função para verificar se o Docker está rodando
wait_for_docker() {
    echo "[*] Aguardando Docker iniciar..."
    for i in {1..10}; do
        if docker info >/dev/null 2>&1; then
            echo "[+] Docker está rodando!"
            return 0
        fi
        sudo service docker start
        sleep 2
    done
    echo "[!] Erro: Docker não iniciou após 20 segundos."
    exit 1
}

# 2. Instalação e Verificação do Docker Compose
echo "[1/6] Verificando Docker e Compose..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
fi
# O docker compose moderno vem instalado com o docker no Ubuntu/WSL
# Se não estiver, instalamos o plugin
sudo apt-get install -y docker-compose-plugin

wait_for_docker

# 3. Preparação das Pastas
echo "[2/6] Preparando estrutura..."
mkdir -p "$PROJETO_DIR"/{nginx/conf.d,frontend,srv1,srv2,srv3}
cd "$PROJETO_DIR" || exit

# 4. Criando Arquivos
echo '[{"servidor":"Servidor Web 01","cor":"#22c55e"}]' > srv1/status.json
echo '[{"servidor":"Servidor Web 02","cor":"#3b82f6"}]' > srv2/status.json
echo '[{"servidor":"Servidor Web 03","cor":"#f59e0b"}]' > srv3/status.json

# (O frontend permanece conforme seu código...)
# ... [Cole aqui o seu código do frontend index.html] ...

# 5. Configuração Nginx (O Segredo: max_fails + fail_timeout)
cat > nginx/conf.d/loadbalancer.conf <<EOF
upstream cluster_aplicacao {
    server srv1:80 max_fails=1 fail_timeout=1s;
    server srv2:80 max_fails=1 fail_timeout=1s;
    server srv3:80 max_fails=1 fail_timeout=1s;
}
server {
    listen 8080;
    location / { root /usr/share/nginx/html; index index.html; }
    location /api/status { 
        proxy_pass http://cluster_aplicacao/status.json; 
        proxy_connect_timeout 0.5s;
    }
}
EOF

# 6. Docker Compose (Com nomes fixos e rede única)
cat > docker-compose.yml <<EOF
services:
  srv1: { image: nginx:alpine, container_name: srv1, volumes: ["./srv1:/usr/share/nginx/html"] }
  srv2: { image: nginx:alpine, container_name: srv2, volumes: ["./srv2:/usr/share/nginx/html"] }
  srv3: { image: nginx:alpine, container_name: srv3, volumes: ["./srv3:/usr/share/nginx/html"] }
  balanceador:
    image: nginx:alpine
    container_name: balanceador
    ports: ["8080:8080"]
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./frontend:/usr/share/nginx/html
EOF

# 7. Subida com Autocorreção
echo "[+] Iniciando cluster..."
sudo docker compose down --remove-orphans
sudo docker compose up -d
