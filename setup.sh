#!/bin/bash

# Define o local do projeto
PROJETO_DIR="$HOME/cluster-balanceado"

echo "================================================="
echo "   SISTEMA DE BALANCEAMENTO DE CARGA NATIVO      "
echo "================================================="

# 1. Checagem de ambiente e Docker
echo "[1/6] Verificando conexão com o Docker..."

if ! docker info >/dev/null 2>&1; then
    echo "[!] Docker não está rodando."
    echo "[!] DICA: Se você usa Docker Desktop no Windows, abra-o antes de rodar este script."
    echo "[!] Se usa Docker nativo no Linux, tente: sudo service docker start"
    exit 1
fi
echo "[+] Docker está rodando e acessível!"

# 2. Instalação do Docker Compose (Plugin oficial)
echo "[2/6] Verificando Docker Compose..."
if ! docker compose version >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
fi

# 3. Preparação das Pastas
echo "[3/6] Preparando estrutura..."
mkdir -p "$PROJETO_DIR"/{nginx/conf.d,frontend,srv1,srv2,srv3}
cd "$PROJETO_DIR" || exit

# 4. Criando Arquivos de Status
echo '{"servidor":"Servidor Web 01","cor":"#22c55e"}' > srv1/status.json
echo '{"servidor":"Servidor Web 02","cor":"#3b82f6"}' > srv2/status.json
echo '{"servidor":"Servidor Web 03","cor":"#f59e0b"}' > srv3/status.json

# 5. Criando o Dashboard (Frontend)
cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head><meta charset="UTF-8"><title>Dashboard</title>
<style>
body{background:#0f172a;color:#fff;display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;}
.card{padding:40px;text-align:center;background:#1e293b;border-radius:20px;}
</style>
</head>
<body>
<div class="card">
    <h1 id="srv_nome">Carregando...</h1>
    <div id="status">Aguardando balanceador...</div>
</div>
<script>
async function atualizar(){
    try {
        const r = await fetch('/api/status?cache=' + Date.now());
        const d = await r.json();
        document.getElementById("srv_nome").innerText = d.servidor;
        document.getElementById("srv_nome").style.color = d.cor;
    } catch(e) {
        document.getElementById("status").innerText = "Cluster indisponível";
    }
}
setInterval(atualizar, 1000);
atualizar();
</script>
</body>
</html>
EOF

# 6. Configuração Nginx (Upstream)
cat > nginx/conf.d/loadbalancer.conf <<EOF
upstream cluster_aplicacao {
    server srv1:80;
    server srv2:80;
    server srv3:80;
}
server {
    listen 8080;
    location / { root /usr/share/nginx/html; index index.html; }
    location /api/status { 
        proxy_pass http://cluster_aplicacao/status.json; 
    }
}
EOF

# 7. Docker Compose
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

# 8. Execução
echo "[+] Iniciando containers..."
sudo docker compose down --remove-orphans
sudo docker compose up -d

echo "================================================="
echo " SUcesso! Acesse: http://localhost:8080"
echo "================================================="
