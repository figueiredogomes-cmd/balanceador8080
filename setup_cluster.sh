#!/bin/bash

# Configurações do Projeto
PROJETO_DIR="$HOME/cluster-balanceado"

echo "=========================================================="
echo " INSTALADOR AUTOMÁTICO: CLUSTER NGINX + DOCKER (WSL/UBUNTU)"
echo "=========================================================="

# 1. Atualização e Instalação de Ferramentas Base
echo "[1/4] Instalando dependências (curl, git, etc)..."
sudo apt-get update && sudo apt-get install -y curl git gnupg lsb-release

# 2. Instalação do Docker (Caso não esteja presente)
if ! command -v docker &> /dev/null; then
    echo "[2/4] Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
fi

# 3. Instalação do Plugin Docker Compose
echo "[3/4] Instalando Docker Compose Plugin..."
sudo apt-get install -y docker-compose-plugin

# 4. Configuração do Projeto
echo "[4/4] Configurando estrutura do cluster..."
mkdir -p "$PROJETO_DIR"/{nginx/conf.d,frontend,srv1,srv2,srv3}
cd "$PROJETO_DIR" || exit

# Criar arquivos de status
echo '{"servidor":"Servidor 01","cor":"#22c55e"}' > srv1/status.json
echo '{"servidor":"Servidor 02","cor":"#3b82f6"}' > srv2/status.json
echo '{"servidor":"Servidor 03","cor":"#f59e0b"}' > srv3/status.json

# Criar Frontend (Dashboard)
cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>Cluster Dashboard</title>
<style>
body{background:#0f172a;color:#fff;font-family:sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;}
.card{padding:30px;background:#1e293b;border-radius:15px;text-align:center;}
</style>
</head>
<body>
<div class="card">
    <h1 id="status">Conectando...</h1>
    <p>Srv1: <span id="c1">0</span> | Srv2: <span id="c2">0</span> | Srv3: <span id="c3">0</span></p>
</div>
<script>
    let counts = {"Servidor 01": 0, "Servidor 02": 0, "Servidor 03": 0};
    async function update() {
        try {
            const r = await fetch('/api/status?t=' + Date.now());
            const d = await r.json();
            document.getElementById("status").innerText = d.servidor;
            document.getElementById("status").style.color = d.cor;
            counts[d.servidor]++;
            document.getElementById("c1").innerText = counts["Servidor 01"];
            document.getElementById("c2").innerText = counts["Servidor 02"];
            document.getElementById("c3").innerText = counts["Servidor 03"];
        } catch(e) { document.getElementById("status").innerText = "Offline"; }
    }
    setInterval(update, 800);
</script>
</body>
</html>
EOF

# Configuração Nginx (Upstream resiliente)
cat > nginx/conf.d/loadbalancer.conf <<EOF
upstream cluster {
    server srv1:80 max_fails=1 fail_timeout=1s;
    server srv2:80 max_fails=1 fail_timeout=1s;
    server srv3:80 max_fails=1 fail_timeout=1s;
}
server {
    listen 8080;
    location / { root /usr/share/nginx/html; }
    location /api/status { proxy_pass http://cluster/status.json; }
}
EOF

# Docker Compose
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

echo "=========================================================="
echo " INSTALAÇÃO FINALIZADA!"
echo " Rode: cd ~/cluster-balanceado && sudo docker compose up -d"
echo " Acesse: http://localhost:8080"
echo "=========================================================="
